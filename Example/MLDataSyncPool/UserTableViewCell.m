//
//  UserTableViewCell.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "UserTableViewCell.h"
#import "ExampleUserDefaults.h"
#import <UIImageView+WebCache.h>

@interface UserTableViewCell()

@property (nonatomic, strong) User *user;

@end

@implementation UserTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(reload:) name:UserDetailsDidChangeNotificationName object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

#pragma mark - event
- (void)reload:(NSNotification*)notification {
    NSMutableArray *userIDs = notification.userInfo[UserDetailsDidChangeNotificationUserInfoKey];
    if ([userIDs containsObject:self.userID]) {
        //更新UI
        self.user = [[ExampleUserDefaults defaults] userWithUserID:self.userID];
    }
}

#pragma mark - setter
- (void)setUserID:(NSString *)userID {
    _userID = [userID copy];
    
    //更新UI，并且对useriD标记使用
    self.user = [[ExampleUserDefaults defaults] userWithUserID:userID];
    [[ExampleUserDefaults defaults]useUserID:userID];
}

- (void)setUser:(User *)user {
    _user = user;

#warning image这样搞没啥屌用
    [self.imageView sd_setImageWithURL:user.avatar];
    self.textLabel.text = user.name;
}

@end
