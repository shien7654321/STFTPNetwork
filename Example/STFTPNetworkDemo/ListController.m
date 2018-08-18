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
        self->_list = [NSMutableArray arrayWithArray:results];
        [weakSelf.tableView reloadData];
        if (sender.isRefreshing && [[NSDate date] timeIntervalSinceDate:startRefreshTime] >= minDuration) {
            [sender endRefreshing];
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        SFLog(@"Query files failed: %ld", (long)errorCode);
        loadFinish = YES;
        [self->_list removeAllObjects];
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
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Please choose" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *createFolderAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create a new folder", ) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createFolder];
    }];
    UIAlertAction *uploadFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Upload file", ) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self uploadFile];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ) style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:createFolderAction];
    [alertController addAction:uploadFileAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createFolder {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"New folder" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Please enter a folder name", );
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create", ) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *folderName = [alertController.textFields firstObject].text;
        if (folderName.length > 0) {
            NSString *folderPath = [NSString stringWithFormat:@"%@%@", [self currentPath], folderName];
            [STFTPNetwork create:folderPath successHandler:^{
                [weakSelf refresh:nil];
            } failHandler:^(STFTPErrorCode errorCode) {
                SFLog(@"New folder failed: %ld", (long)errorCode);
            }];
        }
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ) style:UIAlertActionStyleCancel handler:nil];
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
        SFLog(@"Test upload file failed to write to hard disk");
        return;
    }
    void (^removeTestFile)(NSString *path) = ^ (NSString *path) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:testPath error:&error];
        if (error) {
            SFLog(@"Failed to remove test file");
        }
    };
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", [self currentPath], testFilename];
    [SVProgressHUD showProgress:0 status:@"Uploading..."];
    [STFTPNetwork upload:testPath urlString:urlString progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
        float progress = bytesTotal > 0 ? bytesCompleted * 1.0 / bytesTotal : 0;
        [SVProgressHUD showProgress:progress status:@"Uploading..."];
    } successHandler:^{
        [SVProgressHUD showSuccessWithStatus:@"Upload success"];
        [self refresh:nil];
        removeTestFile(testPath);
    } failHandler:^(STFTPErrorCode errorCode) {
        [SVProgressHUD showErrorWithStatus:@"Upload failed"];
        SFLog(@"Upload failed: %ld", (long)errorCode);
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
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Tips" message:[NSString stringWithFormat:@"Do you want to download %@ ?", name] preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *downloadAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Download", ) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [SVProgressHUD showProgress:0 status:@"Downloading..."];
            NSString *path = [NSString stringWithFormat:@"%@%@", [self currentPath], name];
            [STFTPNetwork download:path progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
                float progress = bytesTotal > 0 ? bytesCompleted * 1.0 / bytesTotal : 0;
                [SVProgressHUD showProgress:progress status:@"Downloading..."];
            } successHandler:^(NSData *data) {
                [SVProgressHUD showSuccessWithStatus:@"Download success"];
                SFLog(@"Downloaded data length: %lu", data.length);
            } failHandler:^(STFTPErrorCode errorCode) {
                [SVProgressHUD showErrorWithStatus:@"Download failed"];
                SFLog(@"Download failed: %ld", errorCode);
            }];
        }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ) style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:downloadAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dictionary = _list[indexPath.row];
    NSString *name = dictionary[(__bridge id)kCFFTPResourceName];
    __weak typeof(self) weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Warning" message:[NSString stringWithFormat:@"Do you really want to delete %@ ?", name] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *removeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", ) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *path = [NSString stringWithFormat:@"%@%@", [self currentPath], name];
        NSInteger type = [dictionary[(__bridge id)kCFFTPResourceType] integerValue];
        if (type == DT_DIR) {
            path = [NSString stringWithFormat:@"%@/", path];
        }
        [STFTPNetwork remove:path successHandler:^{
            [self->_list removeObjectAtIndex:indexPath.row];
            [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } failHandler:^(STFTPErrorCode errorCode) {
            [SVProgressHUD showErrorWithStatus:@"Delete file (folder) failed"];
            SFLog(@"Delete file failed: %ld", (long)errorCode);
        }];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ) style:UIAlertActionStyleCancel handler:nil];
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
