//
//  MainController.m
//  STFTPNetworkDemo
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "MainController.h"
#import "ListController.h"
#import "STFTPNetwork.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface MainController () <UITextFieldDelegate>

@end

@implementation MainController {
    __weak IBOutlet UITextField *_txtFTP;
    __weak IBOutlet UITextField *_txtUsername;
    __weak IBOutlet UITextField *_txtPassword;
    NSString *_ftpURLString, *_ftpUsername, *_ftpPassword;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    _ftpURLString = _txtFTP.text;
    _ftpUsername = _txtUsername.text;
    _ftpPassword= _txtPassword.text;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [STFTPNetwork disconnect];
}

#pragma mark - Event

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *identifier = segue.identifier;
    if ([identifier isEqualToString:@"MainToList"]) {
        ListController *listController = (ListController *)(segue.destinationViewController);
        listController.urlString = _ftpURLString;
    }
}

- (IBAction)btnConnectClicked:(UIButton *)sender {
    [self.view endEditing:YES];
    [SVProgressHUD showWithStatus:@"Connecting..."];
    [STFTPNetwork connect:_ftpURLString username:_ftpUsername password:_ftpPassword handler:^(BOOL success) {
        if (success) {
            [SVProgressHUD dismiss];
            [self performSegueWithIdentifier:@"MainToList" sender:nil];
        } else {
            [SVProgressHUD showErrorWithStatus:@"Failed to connect to FTP server"];
        }
    }];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if ([textField isEqual:_txtFTP]) {
        _ftpURLString = textField.text;
    } else if ([textField isEqual:_txtUsername]) {
        _ftpUsername = textField.text;
    } else if ([textField isEqual:_txtPassword]) {
        _ftpPassword = textField.text;
    }
}

@end
