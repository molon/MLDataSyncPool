//
//  ExampleUserDefaults.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ExampleUserDefaults.h"
#import <MLDataSyncPool.h>
#import "ExampleAPIHelper.h"
#import <MLKit.h>

NSString * const UserDetailsDidChangeNotificationName = @"com.molon.UserDetailsDidChangeNotificationName";
NSString * const UserDetailsDidChangeNotificationUserInfoKey = @"userIDs";

NSString * const AllUserDetailsDidDirtyNotificationName = @"com.molon.AllUserDetailsDidDirtyNotificationName";

@interface ExampleUserDefaults()

@property (nonatomic, strong) NSDictionary<NSString*,User *><User> *users;

@property (nonatomic, strong) MLDataSyncPool *dataSyncPool;

@end

@implementation ExampleUserDefaults

#pragma mark - other 这俩是MLUserDefault里的内部机制，无需太作关心
//设置默认值
+ (NSDictionary *)modelCustomPropertyDefaultValueMapper {
    NSMutableDictionary *dict = [[super modelCustomPropertyDefaultValueMapper]mutableCopy];
    [dict addEntriesFromDictionary:@{
                                     @"users":[NSDictionary<NSString*,User *><User> new],
                                     }];
    return dict;
}

//设置忽略MLUserDefaults的自动存储和取出特性的key
- (NSArray *)configureIgnoreKeys {
    return @[@"dataSyncPool"];
}

#pragma mark - lifecycle
- (instancetype)init {
    self = [super init];
    if (self) {
        WEAK_SELF
        //设置为800也OK啦，更新罢了，不需要太及时，减少请求更重要
        _dataSyncPool = [[MLDataSyncPool alloc]initWithDelay:800 maxPullCountOnce:50 maxFailCount:2 pullBlock:^(NSSet * _Nonnull keys, MLDataSyncPoolPullCallBackBlock  _Nonnull callback) {
            DDLogDebug(@"Pull: %@",[[keys allObjects]componentsJoinedByString:@","]);
            //做拉取请求, 这个是MLKit里的请求封装罢了，请自行替换自己的实现。
            ExampleAPIHelper *helper = [ExampleAPIHelper new];
            helper.p_userIDs = [[keys allObjects]componentsJoinedByString:@","];
            [helper requestWithBefore:nil complete:^(MLAPIHelper * _Nonnull apiHelper) {
                DDLogDebug(@"Pull Complete: %@",[[keys allObjects]componentsJoinedByString:@","]);
                
                NSMutableDictionary *result = nil;
                if (helper.r_rows.count>0) {
                    result = [NSMutableDictionary dictionaryWithCapacity:helper.r_rows.count];
                    //整理出字典
                    for (User *user in helper.r_rows) {
#warning 因为有假接口的存在，这里客户端去做下过滤，关于假接口去看ExampleAPIHelper.m
                        if (![keys containsObject:user.ID]) {
                            continue;
                        }
                        result[user.ID] = user;
                    }
                }
                callback(result);
            } success:nil failureOrError:nil];
        } newDataBlock:^(NSDictionary * _Nonnull datas) { //实际上这个datas就是上文整理出来的结果
            STRONG_SELF
            [self syncUsers:[datas allValues]];
        }];
        
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

#pragma mark - event
#warning 每次active都尝试去刷新要使用的User信息，这个只是为了测试方便，实际使用的话推荐以进入到前台为准
- (void)applicationDidBecomeActive {
    //dirty所有user
    for (User *u in [self.users allValues]) {
        u.dirty = YES;
    }
    self.users = self.users; //MLUserDefaults自动持久化只能通过setter方法
    
    //投递消息出去，谁在显示中自己去signUse，这样是有好处的，否则用户来回的小幅度滚动列表可能会引发多请求，这个还只能他们自己做，这里不知道哪些正在显示中的
    [[NSNotificationCenter defaultCenter]postNotificationOnMainThreadWithName:AllUserDetailsDidDirtyNotificationName object:nil];
    
    //清空同步池的failCount
    [_dataSyncPool resetAllFailCount];
    
    //找到所有的无详情用户，直接性的立即重试他们
    NSArray *userIDs = [self noDetailUserIDs];
    if (userIDs.count>0) {
        [_dataSyncPool syncDataWithKeys:userIDs way:MLDataSyncWayRightNow];
    }
}

#pragma mark - helper
//同步一些最新用户信息到本地，实际项目肯定不能这样存，这是demo
- (void)syncUsers:(NSArray<User*>*)users {
    NSMutableDictionary<NSString*,User *><User> *result = [self.users mutableCopy];
    
    NSMutableArray *notificationUserIDs = [NSMutableArray array];
    
    NSTimeInterval timestamp = [[NSDate date]timeIntervalSince1970];
    for (User *user in users) {
        //若内容没变这个用户就无需通知啦
        if (![user isDetailEqualToUser:result[user.ID]]) {
            [notificationUserIDs addObject:user.ID];
        }
        //替换或者增加
        result[user.ID] = user;
        //更新其更新策略属性
        [user freshWithSyncTimestamp:timestamp];
    }
    
    //整理完重新存储
    self.users = result;
    
    //投递更新的userIDs出去
    if (notificationUserIDs.count>0) {
        dispatch_force_async_on_main_queue(^{
            [[NSNotificationCenter defaultCenter]postNotificationOnMainThreadWithName:UserDetailsDidChangeNotificationName object:nil userInfo:@{UserDetailsDidChangeNotificationUserInfoKey:notificationUserIDs}];
        });
    }
}


//找到无详情的用户
- (NSArray*)noDetailUserIDs {
    NSMutableArray *result = [NSMutableArray array];
    for (User *user in [self.users allValues]) {
        if ([user isNoDetail]) {
            [result addObject:user.ID];
        }
    }
    return (result.count>0)?result:nil;
}

#pragma mark - outcall
- (void)setup {}

- (User*)userWithUserID:(NSString*)userID {
#warning 这里如果实际做的话，由于是sqlite存储，每次都去查一次很耗性能，最好得在这里做内存缓存，根据一些方式控制内存缓存大小，例如双链表LRU
    return self.users[userID];
}

//标记使用了一次
- (void)signUseForUserID:(NSString*)userID {
    NSAssert(userID, @"%@:userID must be not nil",NSStringFromSelector(_cmd));
    User *u = [self userWithUserID:userID];
    if (!u) {
        u = [User new];
        u.ID = userID;
        u.dirty = YES;
        [self syncUsers:@[u]];
    }
    
    if ([u needUpdate]) {
        [_dataSyncPool syncDataWithKeys:@[userID] way:MLDataSyncWayDelay];
    }
}

- (void)syncUsersWithUserIDs:(NSArray*)userIDs {
    //这里建立下新记录，否则的话只有在使用的时候和拉取成功后会建立，这样的话就有可能在极端情况下丢失部分存储
    [userIDs enumerateObjectsUsingBlock:^(NSString *userID, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![self userWithUserID:userID]) {
            User *u = [User new];
            u.ID = userID;
            u.dirty = YES;
            [self syncUsers:@[u]];
        }
    }];
    [_dataSyncPool syncDataWithKeys:userIDs way:MLDataSyncWayRightNow];
}


@end
