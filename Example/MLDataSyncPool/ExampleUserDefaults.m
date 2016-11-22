//
//  ExampleUserDefaults.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ExampleUserDefaults.h"

NSString * const UserDetailsDidChangeNotificationName = @"com.molon.UserDetailsDidChangeNotificationName";
NSString * const UserDetailsDidChangeNotificationUserInfoKey = @"userIDs";

@interface ExampleUserDefaults()

@property (nonatomic, strong) NSDictionary<NSString*,User *><User> *users;

@end

@implementation ExampleUserDefaults

+ (NSDictionary *)modelCustomPropertyDefaultValueMapper {
    NSMutableDictionary *dict = [[super modelCustomPropertyDefaultValueMapper]mutableCopy];
    [dict addEntriesFromDictionary:@{
                                    @"users":[NSDictionary<NSString*,User *> new],
                                     }];
    return dict;
}

- (User*)userWithUserID:(NSString*)userID {
    return self.users[userID];
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
    [[NSNotificationCenter defaultCenter]postNotificationOnMainThreadWithName:UserDetailsDidChangeNotificationUserInfoKey object:nil userInfo:@{UserDetailsDidChangeNotificationUserInfoKey:notificationUserIDs}];
}


//标记使用了一次
- (void)useUserID:(NSString*)userID {
    User *u = [self userWithUserID:userID];
    if (!u) {
        u = [User new];
        u.dirty = YES;
        [self syncUsers:@[u]];
    }
    
    if ([u needUpdate]) {
        //向MLDataSyncPool里投递同步任务
#warning not add
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
