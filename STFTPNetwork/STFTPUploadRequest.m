//
//  STFTPUploadRequest.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPUploadRequest.h"

@implementation STFTPUploadRequest {
    NSString *_urlString, *_filePath;
    STFTPProgressHandler _progerssHandler;
    STFTPUploadSuccessHandler _successHandler;
    STFTPFailHandler _failHandler;
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
    BOOL _writeStreamScheduled;
    UInt64 _bytesTotal, _bytesCompleted;
}

void uploadClientCB(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    STFTPUploadRequest *request = (__bridge STFTPUploadRequest *)clientCallBackInfo;
    switch (type) {
        case NSStreamEventHasSpaceAvailable: {
            UInt8 receiveBuffer[kBufferSize];
            CFIndex bytesRead = CFReadStreamRead(request->_readStream, receiveBuffer, kBufferSize);
//            SFLog(@"Upload target file read: %ld", bytesRead);
            if (bytesRead > 0) {
                NSInteger bytesOffset = 0;
                do {
                    CFIndex bytesWritten = CFWriteStreamWrite(stream, &receiveBuffer[bytesOffset], bytesRead - bytesOffset);
                    if (bytesWritten > 0) {
                        bytesOffset += bytesWritten;
                        request->_bytesCompleted += bytesWritten;
                        if (request->_progerssHandler) {
                            request->_progerssHandler(request->_bytesCompleted, request->_bytesTotal);
                        }
                    } else if (bytesWritten == 0) {
                        break;
                    } else {
                        SFLog(@"Upload writeStream write error");
                        if (request->_failHandler) {
                            request->_failHandler(STFTPErrorUploadWriteStreamWriteError);
                        }
                        return;
                    }
                } while (bytesRead - bytesOffset > 0);
            } else if (bytesRead == 0) {
                if (request->_successHandler) {
                    request->_successHandler();
                }
                [request stop];
            } else {
                SFLog(@"Upload writeStream write error");
                if (request->_failHandler) {
                    request->_failHandler(STFTPErrorUploadWriteStreamWriteError);
                }
            }
            break;
        }
        case kCFStreamEventErrorOccurred: {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
            CFStreamError error = CFWriteStreamGetError(stream);
            SFLog(@"Upload writeStream error:%d", error.error);
#pragma clang diagnostic pop
            [request stop];
            if (request->_failHandler) {
                request->_failHandler(STFTPErrorUploadWriteStreamError);
            }
            break;
        }
        case kCFStreamEventEndEncountered: {
            if (request->_successHandler) {
                request->_successHandler();
            }
            [request stop];
            break;
        }
        default: break;
    }
}

+ (instancetype)upload:(NSString *)filePath urlString:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPUploadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (!filePath || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    if (!urlString || ![urlString hasPrefix:@"ftp://"]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    STFTPUploadRequest *request = [[STFTPUploadRequest alloc] init];
    request->_filePath = filePath;
    request->_urlString = urlString;
    request->_progerssHandler = progressHandler;
    request->_successHandler = successHandler;
    request->_failHandler = failHandler;
    [request start];
    return request;
}

- (void)start {
    
    NSError *error = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:&error];
    if (error) {
        SFLog(@"Get the upload target file attributes failed: %@", error.localizedDescription);
    } else {
        _bytesTotal = [fileAttributes fileSize];
    }
    if (!_bytesTotal) {
        SFLog(@"Upload target file size unknown");
    }
    
    NSURL *readURL = [NSURL fileURLWithPath:_filePath];
    _readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)readURL);
    
    if (!_readStream) {
        SFLog(@"Upload readStream initialization failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadReadStreamCreate);
        }
        return;
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"Upload readStream open failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteStreamOpen);
        }
    }
    
    CFStringRef writeURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef writeURL = CFURLCreateWithString(kCFAllocatorDefault, writeURLString, NULL);
    _writeStream = CFWriteStreamCreateWithFTPURL(kCFAllocatorDefault, writeURL);
    CFRelease(writeURL);
    
    if (!_writeStream) {
        SFLog(@"Upload writeStream initialization failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteStreamCreate);
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
    
    if (CFWriteStreamSetClient(_writeStream, streamEvents, uploadClientCB, &clientContext)) {
        _writeStreamScheduled = YES;
        CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    } else {
        SFLog(@"Set upload writeStream callback failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteStreamSetClient);
        }
    }
    
    if (!CFWriteStreamOpen(_writeStream)) {
        SFLog(@"Upload writeStream open failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteStreamOpen);
        }
    }
    
}

- (void)stop {
    if (_readStream) {
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
        _readStream = nil;
    }
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
