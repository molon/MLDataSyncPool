//
//  ExampleUserDefaults.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <MLKit/MLKit.h>
#import "User.h"

FOUNDATION_EXPORT NSString * const UserDetailsDidChangeNotificationName;
FOUNDATION_EXPORT NSString * const UserDetailsDidChangeNotificationUserInfoKey;

#warning 这个只是demo罢了，简单搞一搞，实际情况请使用sqlite
@interface ExampleUserDefaults : MLUserDefaults

- (void)setup;

//获取User信息
- (User*)userWithUserID:(NSString*)userID;

//标记使用了某UserID
- (void)signUseForUserID:(NSString*)userID;

//可以强制要求立即同步某些Users信息
- (void)syncUsersWithUserIDs:(NSArray*)userIDs;

@end
