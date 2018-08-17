//
//  ListController.m
//  STFTPNetworkDemo
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "ListController.h"
#import "ListCell.h"
#import "STFTPNetwork.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface ListController ()

@end

@implementation ListController {
    NSMutableArray *_list;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_urlString) {
        self.title = _urlString.lastPathComponent;
    }
    if (!_list) {
        _list = [NSMutableArray array];
    }
    self.tableView.estimatedRowHeight = 44;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.tableView reloadData];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf refresh:nil];
    });
}

- (NSString *)currentPath {
    return [_urlString hasSuffix:@"/"] ? _urlString : [NSString stringWithFormat:@"%@/", _urlString];
}

#pragma mark - Event

- (IBAction)refresh:(UIRefreshControl *)sender {
    NSDate *startRefreshTime = [NSDate date];
    NSTimeInterval minDuration = 1;
    __block BOOL loadFinish = NO;
    __weak typeof(self) weakSelf = self;
    [STFTPNetwork query:_urlString successHandler:^(NSArray *results) {
        loadFinish = YES;
        _list = [NSMutableArray arrayWithArray:results];
        [weakSelf.tableView reloadData];
        if (sender.isRefreshing && [[NSDate date] timeIntervalSinceDate:startRefreshTime] >= minDuration) {
            [sender endRefreshing];
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        SFLog(@"查询文件失败：%ld", errorCode);
        loadFinish = YES;
        [_list removeAllObjects];
        [weakSelf.tableView reloadData];
        if (sender.isRefreshing && [[NSDate date] timeIntervalSinceDate:startRefreshTime] >= minDuration) {
            [sender endRefreshing];
        }
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(minDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (loadFinish && sender.isRefreshing) {
            [sender endRefreshing];
        }
    });
}

- (IBAction)btnAddClicked:(UIBarButtonItem *)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请选择" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *createFolderAction = [UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createFolder];
    }];
    UIAlertAction *uploadFileAction = [UIAlertAction actionWithTitle:@"上传文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self uploadFile];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:createFolderAction];
    [alertController addAction:uploadFileAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createFolder {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"新建文件夹" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入文件夹名称";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"新建" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *folderName = [alertController.textFields firstObject].text;
        if (folderName.length > 0) {
            NSString *folderPath = [NSString stringWithFormat:@"%@%@", [self currentPath], folderName];
            [STFTPNetwork create:folderPath successHandler:^{
                [weakSelf refresh:nil];
            } failHandler:^(STFTPErrorCode errorCode) {
                SFLog(@"新建文件夹失败：%ld", errorCode);
            }];
        }
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:createAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)uploadFile {
    
    NSDate *testDate = [NSDate date];
    NSString *testString = [NSString stringWithFormat:@"%f", [testDate timeIntervalSince1970]];
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *testFilename = [NSString stringWithFormat:@"test_%@", [dateFormatter stringFromDate:testDate]];
    NSString *testPath = [NSTemporaryDirectory() stringByAppendingPathComponent:testFilename];
    BOOL testWriteFlag = [testData writeToFile:testPath atomically:YES];
    if (!testWriteFlag) {
        SFLog(@"测试上传文件写入硬盘失败");
        return;
    }
    void (^removeTestFile)(NSString *path) = ^ (NSString *path) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:testPath error:&error];
        if (error) {
            SFLog(@"删除测试文件失败");
        }
    };
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", [self currentPath], testFilename];
    [SVProgressHUD showProgress:0 status:@"正在上传..."];
    [STFTPNetwork upload:testPath urlString:urlString progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
        float progress = bytesTotal > 0 ? bytesCompleted * 1.0 / bytesTotal : 0;
        [SVProgressHUD showProgress:progress status:@"正在上传..."];
    } successHandler:^{
        [SVProgressHUD showSuccessWithStatus:@"上传成功"];
        [self refresh:nil];
        removeTestFile(testPath);
    } failHandler:^(STFTPErrorCode errorCode) {
        [SVProgressHUD showErrorWithStatus:@"上传失败"];
        SFLog(@"上传失败：%ld", errorCode);
        removeTestFile(testPath);
    }];
    
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSDictionary *dictionary = _list[indexPath.row];
    NSString *name = dictionary[(__bridge id)kCFFTPResourceName];
    NSInteger type = [dictionary[(__bridge id)kCFFTPResourceType] integerValue];
    if (type == DT_DIR) {
        ListController *listController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:NSStringFromClass([ListController class])];
        listController.urlString = [NSString stringWithFormat:@"%@%@/", [self currentPath], name];
        [self.navigationController pushViewController:listController animated:YES];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:[NSString stringWithFormat:@"是否开始下载 %@ ?", name] preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *downloadAction = [UIAlertAction actionWithTitle:@"下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [SVProgressHUD showProgress:0 status:@"正在下载..."];
            NSString *path = [NSString stringWithFormat:@"%@%@", [self currentPath], name];
            [STFTPNetwork download:path progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
                float progress = bytesTotal > 0 ? bytesCompleted * 1.0 / bytesTotal : 0;
                [SVProgressHUD showProgress:progress status:@"正在下载..."];
            } successHandler:^(NSData *data) {
                [SVProgressHUD showSuccessWithStatus:@"下载成功"];
                SFLog(@"下载数据长度：%lu", data.length);
            } failHandler:^(STFTPErrorCode errorCode) {
                [SVProgressHUD showErrorWithStatus:@"下载失败"];
                SFLog(@"下载失败：%ld", errorCode);
            }];
        }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:downloadAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dictionary = _list[indexPath.row];
    NSString *name = dictionary[(__bridge id)kCFFTPResourceName];
    __weak typeof(self) weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:[NSString stringWithFormat:@"您是否真的要删除 %@ ?", name] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *removeAction = [UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *path = [NSString stringWithFormat:@"%@%@", [self currentPath], name];
        NSInteger type = [dictionary[(__bridge id)kCFFTPResourceType] integerValue];
        if (type == DT_DIR) {
            path = [NSString stringWithFormat:@"%@/", path];
        }
        [STFTPNetwork remove:path successHandler:^{
            [_list removeObjectAtIndex:indexPath.row];
            [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } failHandler:^(STFTPErrorCode errorCode) {
            [SVProgressHUD showErrorWithStatus:@"删除文件(夹)失败"];
            SFLog(@"删除文件失败：%ld", errorCode);
        }];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:removeAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dictionary = _list[indexPath.row];
    NSString *name = dictionary[(__bridge id)kCFFTPResourceName];
    NSInteger type = [dictionary[(__bridge id)kCFFTPResourceType] integerValue];
    ListCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([ListCell class])];
    cell.lblMain.text = name;
    cell.accessoryType = type == DT_DIR ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

@end
