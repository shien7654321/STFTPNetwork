//
//  STFTPQueryRequest.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPQueryRequest.h"

@interface STFTPQueryRequest ()

@end

@implementation STFTPQueryRequest {
    NSString *_urlString;
    STFTPQuerySuccessHandler _successHandler;
    STFTPFailHandler _failHandler;
    NSMutableData *_listData;
    CFReadStreamRef _readStream;
    BOOL _readStreamScheduled;
}

void queryClientCB(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    STFTPQueryRequest *request = (__bridge STFTPQueryRequest *)clientCallBackInfo;
    switch (type) {
        case kCFStreamEventHasBytesAvailable: {
            UInt8 receiveBuffer[kBufferSize];
            CFIndex bytesRead = CFReadStreamRead(stream, receiveBuffer, kBufferSize);
            if (bytesRead > 0) {
                [request->_listData appendBytes:receiveBuffer length:bytesRead];
            } else if (bytesRead == 0) {
                [request parseListData];
                [request stop];
            } else {
                if (request->_failHandler) {
                    request->_failHandler(STFTPErrorReadByte);
                }
            }
            break;
        }
        case kCFStreamEventErrorOccurred: {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
            CFStreamError error = CFReadStreamGetError(stream);
            SFLog(@"读取流错误：%d", error.error);
#pragma clang diagnostic pop
            [request stop];
            if (request->_failHandler) {
                request->_failHandler(STFTPErrorReadError);
            }
            break;
        }
        case kCFStreamEventEndEncountered: {
            [request stop];
            break;
        }
        default: break;
    }
}

+ (instancetype)query:(NSString *)urlString successHandler:(STFTPQuerySuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (!urlString || ![urlString hasPrefix:@"ftp://"]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    if (![urlString hasSuffix:@"/"]) {
        urlString = [NSString stringWithFormat:@"%@/", urlString];
    }
    STFTPQueryRequest *request = [[STFTPQueryRequest alloc] init];
    request->_urlString = urlString;
    request->_successHandler = successHandler;
    request->_failHandler = failHandler;
    [request start];
    return request;
}

- (void)start {
    
    _listData = [[NSMutableData alloc] init];
    
    CFStringRef ftpURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef ftpURL = CFURLCreateWithString(kCFAllocatorDefault, ftpURLString, NULL);
    _readStream = CFReadStreamCreateWithFTPURL(kCFAllocatorDefault, ftpURL);
    CFRelease(ftpURL);
    
    if (!_readStream) {
        SFLog(@"读取流初始化失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorReadStreamCreate);
        }
        return;
    }
    
    if ([STFTPNetwork sharedNetwork].username.length > 0) {
        CFStringRef ftpUsername = [STFTPNetwork cfString:[STFTPNetwork sharedNetwork].username];
        CFReadStreamSetProperty(_readStream, kCFStreamPropertyFTPUserName, ftpUsername);
    }
    if ([STFTPNetwork sharedNetwork].password.length > 0) {
        CFStringRef ftpPassword = [STFTPNetwork cfString:[STFTPNetwork sharedNetwork].password];
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
    
    if (CFReadStreamSetClient(_readStream, streamEvents, queryClientCB, &clientContext)) {
        _readStreamScheduled = YES;
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    } else {
        SFLog(@"设定读取回调失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorReadSetClient);
        }
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"读取流打开失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorReadOpen);
        }
    }
}

- (void)stop {
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

- (void)parseListData {
    CFIndex bytesConsumed = 0, totalBytesConsumed = 0;
    CFDictionaryRef parsedDictionary;
    NSMutableArray *array = [[NSMutableArray alloc] init];
    do {
        @autoreleasepool {
            bytesConsumed = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *)_listData.bytes)[totalBytesConsumed], _listData.length - totalBytesConsumed, &parsedDictionary);
            if (bytesConsumed > 0) {
                if (parsedDictionary != NULL) {
                    //文件（夹）名称转码
                    NSString *name = ((__bridge NSDictionary *)parsedDictionary)[(__bridge id)kCFFTPResourceName];
                    name = [self convertEncoding:name];
                    NSMutableDictionary *mutableParsedDictionary = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)parsedDictionary];
                    CFRelease(parsedDictionary);
                    [mutableParsedDictionary setObject:name forKey:(__bridge id)kCFFTPResourceName];
                    [array addObject:[NSDictionary dictionaryWithDictionary:mutableParsedDictionary]];
                    
                    /*
                     //dictionary
                     {
                     kCFFTPResourceGroup = ftp;
                     kCFFTPResourceLink = "";
                     kCFFTPResourceModDate = "2013-12-24 16:00:00 +0000";
                     kCFFTPResourceMode = 511;
                     kCFFTPResourceName = "ABC";
                     kCFFTPResourceOwner = ftp;
                     kCFFTPResourceSize = 5250346;
                     kCFFTPResourceType = 4;
                     }
                     */
                    
                }
                totalBytesConsumed += bytesConsumed;
            } else if (bytesConsumed == 0) {
                break;
            } else if (bytesConsumed == -1) {
                SFLog(@"读取解析失败");
                if (_failHandler) {
                    _failHandler(STFTPErrorReadParse);
                }
                return;
            }
        }
    } while (1);
    if (_successHandler) {
        _successHandler([NSArray arrayWithArray:array]);
    }
}

- (NSString *)convertEncoding:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSMacOSRomanStringEncoding];
    if (data) {
        string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return string;
}

@end
