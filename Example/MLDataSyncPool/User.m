//
//  User.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "User.h"
#import <MLKit.h>

@implementation User

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
    return @{
             @"ID":@"id",
             };
}

- (BOOL)isNoDetail {
    return (![self.name isNotBlank]||!self.avatar);
}

- (BOOL)isDetailEqualToUser:(User*)user {
    return [self.name isEqualToString:user.name]&&
    [[self.avatar absoluteString] isEqualToString:[user.avatar absoluteString]];
}

- (void)freshWithSyncTimestamp:(NSTimeInterval)syncTimestamp {
    self.dirty = NO;
    self.syncTimestamp = syncTimestamp;
}

- (BOOL)needUpdate {
    //空详情的必须需要更新
    //有脏标记并且距离上次同步时间大于5分钟才需要更新
    //例如，每次app active都标记所有User为脏，但是又怕用户短时间内频繁的active造成太多无用刷新所以加上时间限制
#warning 由于5分钟太长，不好测试出效果，这里暂时改下，实际情况肯定要设置大些的
    return (self.dirty&&[[NSDate date]timeIntervalSince1970]-self.syncTimestamp>1/*60*5*/)||[self isNoDetail];
}

@end
