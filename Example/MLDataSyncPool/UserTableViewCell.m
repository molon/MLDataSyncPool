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
        //如果发现有dirty全局，就判断是否在显示中，是的话就得标记使用
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(signDisplay) name:AllUserDetailsDidDirtyNotificationName object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

#pragma mark - event
- (void)reload:(NSNotification*)notification {
    NSMutableArray *userIDs = notification.userInfo[UserDetailsDidChangeNotificationUserInfoKey];
    if ([userIDs containsObject:_userID]) {
        //更新UI
        self.user = [[ExampleUserDefaults defaults] userWithUserID:_userID];
    }
}

- (void)signDisplay {
    //标记此User被使用一次(这里以显示为准)，但是一定要注意必须保证当前在显示中，否则有可能会出现在tableView reload的时候会把列表内所有都标记使用这样的非预期行为(其实默认是不会影响的，但若用了一个protypeCell仅做高度计算这样的行为就会，总归有隐患，所以要判断)。
    if (self.window&&_userID) {
        //让在加入到window后又有标记更新的可能
        [[ExampleUserDefaults defaults]signUseForUserID:_userID];
    }
}

#pragma mark - other
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self signDisplay];
}

#pragma mark - setter
- (void)setUserID:(NSString *)userID {
    _userID = [userID copy];
    
    //更新UI
    self.user = [[ExampleUserDefaults defaults] userWithUserID:userID];
    [self signDisplay];
}

- (void)setUser:(User *)user {
    _user = user;

    self.textLabel.text = user.name;
}

@end
