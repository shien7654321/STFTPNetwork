//
//  STFTPRemoveRequest.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPRemoveRequest.h"
#import <CFNetwork/CFNetwork.h>

#pragma mark -

@implementation STFTPRemoveRequest {
    NSString *_urlString;
    STFTPRemoveSuccessHandler _successHandler;
    STFTPFailHandler _failHandler;
    
}

+ (instancetype)remove:(NSString *)urlString successHandler:(STFTPRemoveSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (!urlString || ![urlString hasPrefix:@"ftp://"]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    STFTPRemoveRequest *request = [[STFTPRemoveRequest alloc] init];
    request->_urlString = urlString;
    request->_successHandler = successHandler;
    request->_failHandler = failHandler;
    [request start];
    return request;
}

- (void)start {
    NSString *urlString = [STFTPNetwork totalFTPURLString:_urlString];
    CFStringRef ftpURLString = [STFTPNetwork cfString:urlString];
    CFURLRef ftpURL = CFURLCreateWithString(kCFAllocatorDefault, ftpURLString, NULL);
    SInt32 errorCode;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    Boolean removeFlag = CFURLDestroyResource(ftpURL, &errorCode);
#pragma clang diagnostic pop
    if (removeFlag) {
        if (_successHandler) {
            _successHandler();
        }
    } else {
        SFLog(@"删除文件(夹)失败：%d", errorCode);
        if (_failHandler) {
            _failHandler(STFTPRemoveError);
        }
    }
    CFRelease(ftpURL);
}

@end
