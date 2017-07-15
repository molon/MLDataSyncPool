//
//  MLDataSyncPool.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MLDataSyncWay) {
    MLDataSyncWayRightNow = 0, //立即同步方式
    MLDataSyncWayDelay, //延迟同步方式，实际使用中总是要同步的但是延迟多久不固定
};

typedef void (^MLDataSyncPoolPullCallBackBlock)(NSDictionary *_Nullable result);

@interface MLDataSyncPool : NSObject

/**
 最大的失败次数，某key失败了这个次数的话就会被忽略，不会再进行对其同步
 */
@property (nonatomic, assign, readonly) NSInteger maxFailCount;

/**
 延时时间，毫秒级，如果在有任务存在的前提下delay时间内没有新任务进来就开始拉取行为
 */
@property (nonatomic, assign, readonly) NSTimeInterval delay;

/*!
 一次最大的pull数，如果未达到delay，却达到了maxPullCountOnce的话也会立即开始拉取行为
 */
@property (nonatomic, assign, readonly) NSInteger maxPullCountOnce;

/**
 唯一的初始化方法
 
 @param delay        延时时间，毫秒级，必须大于10，如果在有任务存在的前提下delay时间内没有新任务进来就开始拉取行为
 @param maxPullCountOnce 一次最大的pull数，如果未达到delay，却达到了maxPullCountOnce的话也会立即开始拉取行为
 @param maxFailCount 最大的失败次数，必须大于0，某key失败了这个次数的话就会被忽略，不会进行对其同步
 @param pullBlock    拉取回调
 @param newDataBlock 获取到的新数据回调
 
 @return instance
 */
- (instancetype)initWithDelay:(NSTimeInterval)delay maxPullCountOnce:(NSInteger)maxPullCountOnce maxFailCount:(NSInteger)maxFailCount pullBlock:(void (^)(NSSet *keys, MLDataSyncPoolPullCallBackBlock callback))pullBlock newDataBlock:(void (^)(NSDictionary *_Nullable datas))newDataBlock;

- (instancetype)init NS_UNAVAILABLE;

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

NS_ASSUME_NONNULL_END
