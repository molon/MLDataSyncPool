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

NSString * const UserDetailsDidChangeNotificationName = @"com.molon.UserDetailsDidChangeNotificationName";
NSString * const UserDetailsDidChangeNotificationUserInfoKey = @"userIDs";

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
        self.dataSyncPool = [[MLDataSyncPool alloc]initWithDelay:300 maxFailCount:3 pullBlock:^(NSSet * _Nonnull keys, MLDataSyncPoolPullCallBackBlock  _Nonnull callback) {
            //做拉取请求
            ExampleAPIHelper *helper = [ExampleAPIHelper new];
            helper.p_userIDs = [[keys allObjects]componentsJoinedByString:@","];
            [helper requestWithBefore:nil complete:^(MLAPIHelper * _Nonnull apiHelper) {
                NSMutableDictionary *result = nil;
                if (helper.r_rows.count>0) {
                    result = [NSMutableDictionary dictionaryWithCapacity:helper.r_rows.count];
                    //整理出字典
                    for (User *user in helper.r_rows) {
                        result[user.ID] = user;
                    }
                }
                callback(result);
            } success:nil failureOrError:nil];
        } newDataBlock:^(NSDictionary * _Nonnull datas) { //实际上这个datas就是上文整理出来的结果
            STRONG_SELF
            [self syncUsers:[datas allValues]];
        }];
        
#warning test 
        self.users = [NSDictionary<NSString*,User *><User> new];
    }
    return self;
}

#pragma mark - helper
- (User*)userWithUserID:(NSString*)userID {
#warning 这里如果实际做的话，由于是sqlite存储，每次都去查一次很耗性能，最好得在这里做内存缓存，根据一些方式控制内存缓存大小，例如双链表LRU
    User *u = self.users[userID];
    if (!u) {
        u = [User new];
        u.ID = userID;
        u.dirty = YES;
        [self syncUsers:@[u]];
    }
    return u;
}

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
    [[NSNotificationCenter defaultCenter]postNotificationOnMainThreadWithName:UserDetailsDidChangeNotificationName object:nil userInfo:@{UserDetailsDidChangeNotificationUserInfoKey:notificationUserIDs}];
}


//标记使用了一次
- (void)useUserID:(NSString*)userID {
    User *u = [self userWithUserID:userID];
    //向MLDataSyncPool里投递同步任务，新存储要以立即更新模式
    if ([u isNoDetail]) {
        [self.dataSyncPool syncDataWithKeys:@[userID] way:MLDataSyncWayRightNow];
    }else if ([u needUpdate]) {
        [self.dataSyncPool syncDataWithKeys:@[userID] way:MLDataSyncWayDelay];
    }
}

//找到无详情的用户
- (NSArray<User*>*)noDetailUsers {
    NSMutableArray<User*> *result = [NSMutableArray<User*> array];
    for (User *user in [self.users allValues]) {
        if ([user isNoDetail]) {
            [result addObject:user];
        }
    }
    return (result.count>0)?result:nil;
}


@end
