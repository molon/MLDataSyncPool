//
//  ExampleUserDefaults.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <MLKit/MLKit.h>

@class User;
@interface ExampleUserDefaults : MLUserDefaults

@property (nonatomic, strong) NSArray<User *> *users;

@end
