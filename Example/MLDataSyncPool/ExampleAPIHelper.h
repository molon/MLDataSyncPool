//
//  ExampleAPIHelper.h
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "BaseAPIHelpers.h"
#import "User.h"

@interface ExampleAPIHelper : BaseAPIHelper

@property (nonatomic, copy) NSString *p_userIds;

@property (nonatomic, strong) NSArray<User *><User> *r_rows;

@end
