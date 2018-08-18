//
//  STFTPCreateRequest.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPCreateRequest.h"

@implementation STFTPCreateRequest {
    NSString *_urlString;
    STFTPCreateSuccessHandler _successHandler;
    STFTPFailHandler _failHandler;
    CFWriteStreamRef _writeStream;
    BOOL _writeStreamScheduled;
}

void createClientCB(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    STFTPCreateRequest *request = (__bridge STFTPCreateRequest *)clientCallBackInfo;
    if (type == kCFStreamEventErrorOccurred) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
        CFStreamError error = CFWriteStreamGetError(stream);
        SFLog(@"Write stream error: %d", error.error);
#pragma clang diagnostic pop
        [request stop];
        if (request->_failHandler) {
            request->_failHandler(STFTPErrorWriteError);
        }
    } else if (type == kCFStreamEventEndEncountered) {
        [request stop];
        if (request->_successHandler) {
            request->_successHandler();
        }
    }
}

+ (instancetype)create:(NSString *)urlString successHandler:(STFTPCreateSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (!urlString || ![urlString hasPrefix:@"ftp://"]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    if (![urlString hasSuffix:@"/"]) {
        urlString = [NSString stringWithFormat:@"%@/", urlString];
    }
    STFTPCreateRequest *request = [[STFTPCreateRequest alloc] init];
    request->_urlString = urlString;
    request->_successHandler = successHandler;
    request->_failHandler = failHandler;
    [request start];
    return request;
}

- (void)start {
    
    CFStringRef ftpURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef ftpURL = CFURLCreateWithString(kCFAllocatorDefault, ftpURLString, NULL);
    _writeStream = CFWriteStreamCreateWithFTPURL(kCFAllocatorDefault, ftpURL);
    CFRelease(ftpURL);
    
    if (!_writeStream) {
        SFLog(@"WriteStream initialization failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorWriteStreamCreate);
        }
        return;
    }
    
    if ([STFTPNetwork sharedNetwork].username.length > 0) {
        CFStringRef ftpUsername = [STFTPNetwork cfString:[STFTPNetwork sharedNetwork].username];
        CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyFTPUserName, ftpUsername);
    }
    if ([STFTPNetwork sharedNetwork].password.length > 0) {
        CFStringRef ftpPassword = [STFTPNetwork cfString:[STFTPNetwork sharedNetwork].password];
        CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyFTPPassword, ftpPassword);
    }
    
    CFStreamClientContext clientContext = {
        0,
        (__bridge void *)self,
        (void *(*)(void *info))CFRetain,
        (void (*)(void *info))CFRelease,
        (CFStringRef (*)(void *info))CFCopyDescription
    };
    CFOptionFlags streamEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
    if (CFWriteStreamSetClient(_writeStream, streamEvents, createClientCB, &clientContext)) {
        _writeStreamScheduled = YES;
        CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    } else {
        SFLog(@"Setting writeStream callback failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorWriteStreamSetClient);
        }
    }
    
    if (!CFWriteStreamOpen(_writeStream)) {
        SFLog(@"Write stream open failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorWriteStreamOpen);
        }
    }
}

- (void)stop {
    if (_writeStream) {
        if (_writeStreamScheduled) {
            _writeStreamScheduled = NO;
            CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        }
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
        _writeStream = nil;
    }
}


@end
