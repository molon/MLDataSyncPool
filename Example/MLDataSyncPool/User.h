//
//  User.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol User
@end
@interface User : NSObject

@property (nonatomic, copy) NSString *ID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSURL *avatar;

- (BOOL)isNoDetail;

- (BOOL)isDetailEqualToUser:(User*)user;

//下面俩是更新策略用到的
@property (nonatomic, assign) BOOL dirty; //是否脏的，例如
@property (nonatomic, assign) NSTimeInterval syncTimestamp; //同步时间

- (void)freshWithSyncTimestamp:(NSTimeInterval)syncTimestamp;

- (BOOL)needUpdate;

@end
