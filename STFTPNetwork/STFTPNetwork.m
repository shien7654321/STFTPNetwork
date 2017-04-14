//
//  STFTPNetwork.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"
#import "STFTPQueryRequest.h"
#import "STFTPCreateRequest.h"
#import "STFTPRemoveRequest.h"
#import "STFTPDownloadRequest.h"
#import "STFTPUploadRequest.h"

const CFIndex kBufferSize = 32768;

@implementation STFTPNetwork {
    CFReadStreamRef _readStream;
    STFTPConnectHandler _connectHandler;
    BOOL _connected, _readStreamScheduled;
}

void connectClientCB(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    STFTPNetwork *network = (__bridge STFTPNetwork *)clientCallBackInfo;
    switch (type) {
        case kCFStreamEventOpenCompleted: {
            network->_connected = YES;
            [network connectHandlerSuccess:YES];
            [network stopConnect];
            break;
        }
        default: {
            [network connectHandlerSuccess:NO];
            [network stopConnect];
            [network reset];
            break;
        }
    }
}

+ (instancetype)sharedNetwork {
    static dispatch_once_t onceToken;
    static STFTPNetwork *network = nil;
    dispatch_once(&onceToken, ^{
        network = [[STFTPNetwork alloc] init];
    });
    return network;
}

+ (void)connect:(NSString *)urlString handler:(STFTPConnectHandler)handler {
    [self connect:urlString username:nil password:nil handler:^(BOOL success) {
        if (handler) {
            handler(success);
        }
    }];
}

+ (void)connect:(NSString *)urlString username:(NSString *)username password:(NSString *)password handler:(STFTPConnectHandler)handler {
    [[self sharedNetwork] connect:urlString username:username password:password handler:^(BOOL success) {
        if (handler) {
            handler(success);
        }
    }];
}

+ (void)disconnect {
    [[self sharedNetwork] stopConnect];
    [[self sharedNetwork] reset];
}

+ (BOOL)query:(NSString *)urlString successHandler:(STFTPQuerySuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (![STFTPNetwork sharedNetwork]->_connected) {
        return NO;
    }
    [STFTPQueryRequest query:urlString successHandler:^(NSArray *results) {
        if (successHandler) {
            successHandler(results);
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        if (failHandler) {
            failHandler(errorCode);
        }
    }];
    return YES;
}

+ (BOOL)create:(NSString *)urlString successHandler:(STFTPCreateSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (![STFTPNetwork sharedNetwork]->_connected) {
        return NO;
    }
    [STFTPCreateRequest create:urlString successHandler:^{
        if (successHandler) {
            successHandler();
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        if (failHandler) {
            failHandler(errorCode);
        }
    }];
    return YES;
}

+ (BOOL)remove:(NSString *)urlString successHandler:(STFTPRemoveSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (![STFTPNetwork sharedNetwork]->_connected) {
        return NO;
    }
    [STFTPRemoveRequest remove:urlString successHandler:^{
        if (successHandler) {
            successHandler();
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        if (failHandler) {
            failHandler(errorCode);
        }
    }];
    return YES;
}

+ (BOOL)download:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPDownloadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (![STFTPNetwork sharedNetwork]->_connected) {
        return NO;
    }
    [STFTPDownloadRequest download:urlString progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
        if (progressHandler) {
            progressHandler(bytesCompleted, bytesTotal);
        }
    } successHandler:^(NSData *data) {
        if (successHandler) {
            successHandler(data);
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        if (failHandler) {
            failHandler(errorCode);
        }
    }];
    return YES;
}

+ (BOOL)upload:(NSString *)filePath urlString:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPUploadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (![STFTPNetwork sharedNetwork]->_connected) {
        return NO;
    }
    [STFTPUploadRequest upload:filePath urlString:urlString progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
        if (progressHandler) {
            progressHandler(bytesCompleted, bytesTotal);
        }
    } successHandler:^{
        if (successHandler) {
            successHandler();
        }
    } failHandler:^(STFTPErrorCode errorCode) {
        if (failHandler) {
            failHandler(errorCode);
        }
    }];
    return YES;
}

+ (NSString *)totalFTPURLString:(NSString *)urlString {
    STFTPNetwork *network = [STFTPNetwork sharedNetwork];
    if (!urlString || !network.username || !network.password) {
        return urlString;
    }
    if (network.username && network.password) {
        NSRange range = [urlString rangeOfString:@"ftp://"];
        range = range.location == NSNotFound ? [urlString rangeOfString:@"FTP://"] : range;
        if (range.location != NSNotFound) {
            NSString *leftURLString = [urlString substringToIndex:range.location + range.length];
            NSString *rightURLString = [urlString substringFromIndex:range.location + range.length];
            NSString *centerURLString = [NSString stringWithFormat:@"%@:%@@", network.username, network.password];
            range = [rightURLString rangeOfString:centerURLString];
            if (range.location == NSNotFound) {
                urlString = [NSString stringWithFormat:@"%@%@%@", leftURLString, centerURLString, rightURLString];
            }
        }
    }
    return urlString;
}

+ (NSString *)cacheFolderPath {
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *cacheFolderPath = [cachesPath stringByAppendingPathComponent:@"STFTPNetworkCache"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:cacheFolderPath]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:cacheFolderPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            SFLog(@"新建Cache文件夹失败：%@", error.localizedDescription);
        }
    }
    return cacheFolderPath;
}

+ (void)clearCache {
    NSString *cacheFolderPath = [STFTPNetwork cacheFolderPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cacheFolderPath]) {
        NSError *error = nil;
        if (![fileManager removeItemAtPath:cacheFolderPath error:&error]) {
            SFLog(@"删除Cache文件夹失败：%@", error.localizedDescription);
        }
    }
}

+ (CFStringRef)cfString:(NSString *)string {
    CFStringRef cfString = (__bridge CFStringRef)string;
    cfString = CFAutorelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, cfString, CFSTR(""), kCFStringEncodingUTF8));
    cfString = CFAutorelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, cfString, NULL, NULL, kCFStringEncodingUTF8));
    return cfString;
}

#pragma mark - Private

- (void)connect:(NSString *)urlString username:(NSString *)username password:(NSString *)password handler:(STFTPConnectHandler)handler {
    if (_connected) {
        if (handler) {
            handler(YES);
        }
        return;
    }
    if (_readStream) {
        if (handler) {
            handler(NO);
        }
        return;
    }
    if (!urlString || ![urlString.lowercaseString hasPrefix:@"ftp://"]) {
        if (handler) {
            handler(NO);
        }
        return;
    }
    if (![urlString hasSuffix:@"/"]) {
        urlString = [NSString stringWithFormat:@"%@/", urlString];
    }
    _urlString = [urlString copy];
    _username = username.length > 0 ? username : nil;
    _password = password.length > 0 ? password : nil;
    _connectHandler = handler;
    [self connect];
}

- (void)connect {
    
    CFStringRef ftpURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef ftpURL = CFURLCreateWithString(kCFAllocatorDefault, ftpURLString, NULL);
    _readStream = CFReadStreamCreateWithFTPURL(kCFAllocatorDefault, ftpURL);
    CFRelease(ftpURL);
    if (!_readStream) {
        SFLog(@"读取流初始化失败");
        [self stopConnect];
        [self reset];
        [self connectHandlerSuccess:NO];
        return;
    }
    if (_username) {
        CFStringRef ftpUsername = [STFTPNetwork cfString:_username];
        CFReadStreamSetProperty(_readStream, kCFStreamPropertyFTPUserName, ftpUsername);
    }
    if (_password) {
        CFStringRef ftpPassword = [STFTPNetwork cfString:_password];
        CFReadStreamSetProperty(_readStream, kCFStreamPropertyFTPPassword, ftpPassword);
    }
    
    CFStreamClientContext clientContext = {
        0,
        (__bridge void *)self,
        (void *(*)(void *info))CFRetain,
        (void (*)(void *info))CFRelease,
        (CFStringRef (*)(void *info))CFCopyDescription
    };
    CFOptionFlags streamEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
    
    if (CFReadStreamSetClient(_readStream, streamEvents, connectClientCB, &clientContext)) {
        _readStreamScheduled = YES;
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    } else {
        SFLog(@"设定读取回调失败");
        [self stopConnect];
        [self reset];
        [self connectHandlerSuccess:NO];
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"读取流打开失败");
        [self stopConnect];;
        [self reset];
        [self connectHandlerSuccess:NO];
    }
    
}

- (void)connectHandlerSuccess:(BOOL)success {
    if (_connectHandler) {
        _connectHandler(success);
    }
    _connectHandler = nil;
}

- (void)stopConnect {
    if (_readStream) {
        if (_readStreamScheduled) {
            _readStreamScheduled = NO;
            CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        }
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
        _readStream = nil;
    }
}

- (void)reset {
    _connected = NO;
    _urlString = nil;
    _username = nil;
    _password = nil;
}

@end
