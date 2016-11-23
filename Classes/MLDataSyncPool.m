//
//  MLDataSyncPool.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "MLDataSyncPool.h"

typedef NS_ENUM(BOOL, MLDataSyncPullStatus) {
    MLDataSyncPullStatusWait = 0, //等待状态，未开始
    MLDataSyncPullStatusPulling, //拉取中
};

#define kInvalidFailCount 3 //发现3次失败就认为这个key压根就是不靠谱了，直接忽略就行了
@interface MLDataSyncPoolTask : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) MLDataSyncWay syncWay;
@property (nonatomic, assign) MLDataSyncPullStatus status;

//失败次数
@property (nonatomic, assign) NSInteger failCount;

@end

@implementation MLDataSyncPoolTask
@end

@interface MLDataSyncPool()

//所有任务
@property (nonatomic, strong) NSMutableDictionary *tasks;

@end

@implementation MLDataSyncPool {
    NSDate *_lastRequestSyncTime; //最后的请求同步的时间
    BOOL _delayLoopRunning; //delay循环是否在运行中
}

#pragma mark - helper
- (BOOL)addOrUpdateTaskWithKey:(NSString*)key syncWay:(MLDataSyncWay)syncWay {
    BOOL hasChange = NO;
    
    MLDataSyncPoolTask *task = _tasks[key];
    if (!task) {
        task = [MLDataSyncPoolTask new];
        task.key = key;
        task.status = MLDataSyncPullStatusWait;
        _tasks[key] = task; //记录下来
        
        hasChange = YES;
    }
    //即使已有对应任务在请求中，也可以更新其syncWay，因为有可能对齐拉取失败，失败后要以新的syncWay为准
    if (task.syncWay!=syncWay) {
        task.syncWay = syncWay;
#warning 需要想想从delay变为right ok，但反过来是不是合适
        hasChange = YES;
    }
}

- (NSSet*)allValidWaitTasks {
    NSMutableSet *result = [NSMutableSet set];
    [[_tasks allValues]enumerateObjectsUsingBlock:^(MLDataSyncPoolTask *t, NSUInteger idx, BOOL * _Nonnull stop) {
        if (t.failCount<kInvalidFailCount&&t.status==MLDataSyncPullStatusWait) {
            [result addObject:t];
        }
    }];
    return result;
}

- (void)doPullWithValidWaitTasks:(NSSet*)waitTasks foundEmptyBlock:(void(^)())foundEmptyBlock {
    NSAssert(self.pullBlock, @"pullBlock must not be nil");
    if (waitTasks.count<=0) {
        if (foundEmptyBlock) foundEmptyBlock();
        return;
    }
    
    NSMutableSet *keys = [NSMutableSet setWithCapacity:waitTasks.count];
    
    //挨个标记拉取状态
    [waitTasks enumerateObjectsUsingBlock:^(MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        t.status = MLDataSyncPullStatusPulling;
        [keys addObject:t.key];
    }];
    
    //执行拉取方法
    __weak __typeof__(self) weak_self = self;
    MLDataSyncPoolPullCallBackBlock callback = ^(NSDictionary *result) {
        __typeof__(self) self = weak_self;
        
        //检查结果，哪些task已经获取结果的就把对应任务给剔除掉，否则重置其status
        for (NSString *key in keys) {
            if (result[key]) {
                [self.tasks removeObjectForKey:key];
            }else{
                MLDataSyncPoolTask *t = self.tasks[key];
                t.status = MLDataSyncPullStatusWait;
                t.failCount++;
            }
        }
        
        [self checkAndDoPullWithFoundEmptyBlock:foundEmptyBlock];
    };
    
    self.pullBlock(keys,callback);
}

- (void)checkAndDoPullWithFoundEmptyBlock:(void(^)())foundEmptyBlock {
    //检查现在是否有有效等待的立即任务，如果有立即开启下一次拉取，否则就跑去delay逻辑里
    NSSet *waitTasks = [self allValidWaitTasks];
    if (waitTasks.count<=0) {
        if (foundEmptyBlock) foundEmptyBlock();
        return; //下面的一堆无用行为不做了
    }
    
    __block BOOL nextPullRightNow = NO;
    [waitTasks enumerateObjectsUsingBlock:^(MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        if (t.syncWay==MLDataSyncWayRightNow) {
            nextPullRightNow = YES;
            *stop = YES;
        }
    }];
    
    if (nextPullRightNow) {
        //发现有立即任务直接插拉取
        [self doPullWithValidWaitTasks:waitTasks foundEmptyBlock:nil];
    }else{
        //直接启动delay拉取loop
        [self doDelayPull];
    }
}

- (void)doDelayPull {
    //得保证delayLoop同时只有一个在执行
    if (_delayLoopRunning) {
        return;
    }
    _delayLoopRunning = YES;
    
    //判断上次请求sync时间到现在是否超过了delay
    NSTimeInterval offset = _delay-[[NSDate date] timeIntervalSinceDate:_lastRequestSyncTime];
    if (offset<=0) {
        __weak __typeof__(self) weak_self = self;
        [self doPullWithValidWaitTasks:[self allValidWaitTasks] foundEmptyBlock:^{
            __typeof__(self) self = weak_self;
            
            self->_delayLoopRunning = NO; //结束delay loop
        }];
    }else{
        //否则等待offset后再尝试一次，中间如果又有更改那就继续delay了
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(offset * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self doDelayPull];
        });
    }
}

#pragma mark - outcall
- (void)syncDataWithKeys:(NSArray*)keys way:(MLDataSyncWay)way {
    NSInteger changeCount = 0;
    for (NSString *key in keys) {
        if ([self addOrUpdateTaskWithKey:key syncWay:way]) {
            changeCount++;
        }
    }
    
    //过滤无用请求
    if (changeCount<=0) {
        return;
    }
    
    _lastRequestSyncTime = [NSDate date];
    
    //检查并且去判断应该执行什么操作
    [self checkAndDoPullWithFoundEmptyBlock:nil];
}

- (void)resetAllFailCount {
    [_tasks enumerateKeysAndObjectsUsingBlock:^(MLDataSyncPoolTask *t, id  _Nonnull obj, BOOL * _Nonnull stop) {
        t.failCount = 0;
    }];
    
    //检查并且去判断应该执行什么操作
    [self checkAndDoPullWithFoundEmptyBlock:nil];
}

@end
