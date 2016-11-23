//
//  MLDataSyncPool.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MLDataSyncWay) {
    MLDataSyncWayRightNow = 0, //立即同步方式
    MLDataSyncWayDelay, //延迟同步方式，实际使用中总是要同步的但是延迟多久不固定
};

typedef void (^MLDataSyncPoolPullCallBackBlock)(NSDictionary *result);

@interface MLDataSyncPool : NSObject

/**
 最大的失败次数，默认为3，某key失败了这个次数的话就会被忽略，不会进行对其同步
 */
@property (nonatomic, assign) NSInteger maxFailCount;

/**
 延时时间，如果在有任务存在的前提下delay时间内没有新任务进来就开始拉取行为
 */
@property (nonatomic, assign) NSTimeInterval delay;

/**
 拉取block
 */
@property (nonatomic, copy) void(^pullBlock)(NSSet *keys,MLDataSyncPoolPullCallBackBlock callback);

/**
 同步数据
 
 @param keys 需要同步的keys
 @param way  这些key的同步方式
 */
- (void)syncDataWithKeys:(NSArray*)keys way:(MLDataSyncWay)way;

/**
 重置所有的失败次数，这样的话就可以重新尝试拉取那些key
 */
- (void)resetAllFailCount;

@end
