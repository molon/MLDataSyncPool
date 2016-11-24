//
//  ExampleAPIHelper.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ExampleAPIHelper.h"

@implementation ExampleAPIHelper

#warning 这里只是一个静态文件罢了，假接口，无论传什么，返回的都是同样的内容，做demo测试足够了
- (NSURL *)configureBaseURL {
    return [NSURL URLWithString:@"http://77g7ef.com1.z0.glb.clouddn.com/"];
}

- (NSString *)configureAPIName {
    return @"users.json";
}


//- (NSString *)configureAPIName {
//    return @"users";
//}

@end
