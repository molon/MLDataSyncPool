//
//  ViewController.m
//  MLDataSyncPool
//
//  Created by molon on 2016/11/22.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ViewController.h"
#import "UserTableViewCell.h"
#import <MLKit.h>
#import "ExampleUserDefaults.h"

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray *userIDs;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [self.view addSubview:self.tableView];
    
#warning 其中222在假接口里是没有结果的，这个主要是为了模拟下一场userID场景
    self.userIDs = @[
                     @"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"111",@"222",@"9",@"10",@"11",@"12",@"13",@"14",@"15"
                     ];
    
#warning 如果确定是新出现的一堆userIDs的话，一般发现新群这类的，需要主动去执行的强制立即同步的方法syncUsersWithUserIDs:，而且要在对应User被使用以前，防止N多请求产生
    //这里因为不好模拟，我们这里比较丑陋的简单判断下是否已有第一个ID的存储来测试下效果，删除重新安装会触发判断成功
    if (![[ExampleUserDefaults defaults]userWithUserID:[self.userIDs firstObject]]) {
        [[ExampleUserDefaults defaults]syncUsersWithUserIDs:self.userIDs];
    }
    
    
    WEAK_SELF
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"ReloadTable" style:UIBarButtonItemStylePlain actionBlock:^(UIBarButtonItem * _Nonnull barButtonItem) {
        STRONG_SELF
        [self.tableView reloadData];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - layout
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    self.tableView.frame = self.view.bounds;
}

#pragma mark - getter
- (UITableView *)tableView {
    if (!_tableView) {
        UITableView *tableView = [[UITableView alloc]init];
        tableView.delegate = self;
        tableView.dataSource = self;
        [tableView registerClass:[UserTableViewCell class] forCellReuseIdentifier:[UserTableViewCell cellReuseIdentifier]];
        _tableView = tableView;
    }
    return _tableView;
}

#pragma mark - tableView
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.userIDs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UserTableViewCell class]) forIndexPath:indexPath];
    
    cell.userID = self.userIDs[indexPath.row];
    
    return cell;
}

@end
