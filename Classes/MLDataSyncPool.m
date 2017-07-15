//
//  MLDataSyncPool.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "MLDataSyncPool.h"

typedef NS_ENUM(BOOL, MLDataSyncPullState) {
    MLDataSyncPullStateWait = 0, //等待状态，未开始
    MLDataSyncPullStatePulling, //拉取中
};

@interface MLDataSyncPoolTask : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) MLDataSyncWay syncWay;
@property (nonatomic, assign) MLDataSyncPullState pullState;

//失败次数
@property (nonatomic, assign) NSInteger failCount;

@end

@implementation MLDataSyncPoolTask
@end

@interface MLDataSyncPool()

@property (nonatomic, assign) NSInteger maxFailCount;
@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, assign) NSInteger maxPullCountOnce;
@property (nonatomic, copy) void(^pullBlock)(NSSet *keys,MLDataSyncPoolPullCallBackBlock callback);
@property (nonatomic, copy) void(^newDataBlock)(NSDictionary *datas);

//所有任务
@property (nonatomic, strong) NSMutableDictionary *tasks;

@end

@implementation MLDataSyncPool {
    NSDate *_lastRequestSyncTime; //最后的请求同步的时间
    BOOL _delayLoopRunning; //delay循环是否在运行中
}

- (instancetype)initWithDelay:(NSTimeInterval)delay maxPullCountOnce:(NSInteger)maxPullCountOnce maxFailCount:(NSInteger)maxFailCount pullBlock:(void (^)(NSSet *keys, MLDataSyncPoolPullCallBackBlock callback))pullBlock newDataBlock:(void (^)(NSDictionary * datas))newDataBlock {
    self = [super init];
    if (self) {
        self.tasks = [NSMutableDictionary dictionary];
        self.maxFailCount = maxFailCount;
        self.delay = delay;
        self.maxPullCountOnce = maxPullCountOnce;
        self.pullBlock = pullBlock;
        self.newDataBlock = newDataBlock;
    }
    return self;
}

#pragma mark - setter
- (void)setMaxFailCount:(NSInteger)maxFailCount {
    NSAssert(maxFailCount>0, @"maxFailCount must >0");
    _maxFailCount = maxFailCount;
}

- (void)setDelay:(NSTimeInterval)delay {
    NSAssert(delay>10, @"delay must >10");
    _delay = delay;
}

- (void)setMaxPullCountOnce:(NSInteger)maxPullCountOnce {
    NSAssert(maxPullCountOnce>0, @"maxPullCountOnce must >0");
    _maxPullCountOnce = maxPullCountOnce;
}

#pragma mark - helper
- (BOOL)addOrUpdateTaskWithKey:(NSString*)key syncWay:(MLDataSyncWay)syncWay {
    BOOL hasChange = NO;
    
    MLDataSyncPoolTask *task = _tasks[key];
    if (!task) {
        task = [MLDataSyncPoolTask new];
        task.key = key;
        task.pullState = MLDataSyncPullStateWait;
        task.syncWay = syncWay;
        
        _tasks[key] = task; //记录下来
        
        hasChange = YES;
    }
    //即使已有对应任务在请求中，也可以更新其syncWay，因为有可能拉取失败，失败后要以新的syncWay为准
    //但是呢，不能从rightNow方式更改为delay方式，标记过rightNow的key就是要尽量得到同步
    else if (task.syncWay!=syncWay&&syncWay!=MLDataSyncWayDelay) {
        task.syncWay = syncWay;
        
        hasChange = YES;
    }
    
    return hasChange;
}

- (NSSet*)allValidWaitTasks {
    NSMutableSet *result = [NSMutableSet set];
    [_tasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        if (t.failCount<_maxFailCount&&t.pullState==MLDataSyncPullStateWait) {
            [result addObject:t];
        }
    }];
    return result;
}

//completeBlock只表示一次拉取的结束，完事之后自动启动的后续拉取就不算数了
- (void)doPullWithValidWaitTasks:(NSSet*)waitTasks completeBlock:(void(^)())completeBlock {
    NSAssert(self.pullBlock, @"pullBlock must not be nil");
    NSAssert(self.newDataBlock, @"newDataBlock must not be nil");
    if (waitTasks.count<=0) {
        if (completeBlock) {
            completeBlock();
        }
        return;
    }
    
    NSMutableSet *keys = [NSMutableSet setWithCapacity:waitTasks.count];
    
    //挨个标记拉取状态
    [waitTasks enumerateObjectsUsingBlock:^(MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        if (keys.count>=_maxPullCountOnce) { //一次最大拉取数目
            *stop = YES;
            return;
        }
        t.pullState = MLDataSyncPullStatePulling;
        [keys addObject:t.key];
    }];
    
    //执行拉取方法
    __weak __typeof__(self) weak_self = self;
    MLDataSyncPoolPullCallBackBlock callback = ^(NSDictionary * _Nullable result) {
        __typeof__(self) self = weak_self;
        
        //检查结果，哪些task已经获取结果的就把对应任务给剔除掉，否则重置其pullState
        for (NSString *key in keys) {
            if (result[key]) {
                [self.tasks removeObjectForKey:key];
            }else{
                MLDataSyncPoolTask *t = self.tasks[key];
                t.pullState = MLDataSyncPullStateWait;
                t.failCount++;
            }
        }
        
        self.newDataBlock(result);
        
        if (completeBlock) {
            completeBlock();
        }
        
        [self checkAndDoPull];
    };
    
    if (keys.count<=0) {
        callback(nil);
        return;
    }
    
    self.pullBlock(keys,callback);
}

- (void)checkAndDoPull {
    //检查现在是否有有效等待的立即任务，如果有立即开启下一次拉取，否则就跑去delay逻辑里
    NSSet *waitTasks = [self allValidWaitTasks];
    if (waitTasks.count<=0) {
        return; //下面的一堆无用行为不做了
    }
    
    __block BOOL nextPullRightNow = NO;
    [waitTasks enumerateObjectsUsingBlock:^(MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        if (t.syncWay==MLDataSyncWayRightNow) {
            nextPullRightNow = YES;
            *stop = YES;
        }
    }];
    
    if (nextPullRightNow||waitTasks.count>=_maxPullCountOnce) {
        //发现有立即任务直接执行一次拉取，如果到达一次最大拉取数目的话，也立即执行拉取
        [self doPullWithValidWaitTasks:waitTasks completeBlock:nil];
    }else{
        //直接启动delay拉取loop
        [self doDelayPull];
    }
}

//delay loop 递归
- (void)doDelayPullWithoutCheckRunning {
    //判断上次请求sync时间到现在是否超过了delay
    NSTimeInterval since = [[NSDate date] timeIntervalSinceDate:_lastRequestSyncTime]*1000;
    NSTimeInterval offset = fmin(_delay-since, _delay);
    NSSet *tasks = [self allValidWaitTasks];
    if (offset<=0||tasks.count>=_maxPullCountOnce) {
        __weak __typeof__(self) weak_self = self;
        [self doPullWithValidWaitTasks:tasks completeBlock:^{
            __typeof__(self) self = weak_self;
            self->_delayLoopRunning = NO; //结束delay loop
        }];
    }else{
        //否则等待offset后再尝试一次，中间如果又有更改那就继续delay了
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(offset * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [self doDelayPullWithoutCheckRunning];
        });
    }
}

- (void)doDelayPull {
    //得保证delayLoop同时只有一个在执行
    if (_delayLoopRunning) {
        return;
    }
    _delayLoopRunning = YES;
    
    [self doDelayPullWithoutCheckRunning];
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
    [self checkAndDoPull];
}

- (void)resetAllFailCount {
    [_tasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, MLDataSyncPoolTask *t, BOOL * _Nonnull stop) {
        t.failCount = 0;
    }];
    
    //检查并且去判断应该执行什么操作
    [self checkAndDoPull];
}

@end
