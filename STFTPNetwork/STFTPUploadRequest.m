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
//            SFLog(@"上传目标文件读取：%ld", bytesRead);
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
                        SFLog(@"上传写入流写入错误");
                        if (request->_failHandler) {
                            request->_failHandler(STFTPErrorUploadWriteWriteError);
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
                SFLog(@"上传写入流写入错误");
                if (request->_failHandler) {
                    request->_failHandler(STFTPErrorUploadWriteWriteError);
                }
            }
            break;
        }
        case kCFStreamEventErrorOccurred: {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
            CFStreamError error = CFWriteStreamGetError(stream);
            SFLog(@"上传写入流错误：%d", error.error);
#pragma clang diagnostic pop
            [request stop];
            if (request->_failHandler) {
                request->_failHandler(STFTPErrorUploadWriteError);
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
        SFLog(@"获取上传目标文件属性失败：%@", error.localizedDescription);
    } else {
        _bytesTotal = [fileAttributes fileSize];
    }
    if (!_bytesTotal) {
        SFLog(@"上传目标文件大小未知");
    }
    
    NSURL *readURL = [NSURL fileURLWithPath:_filePath];
    _readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)readURL);
    
    if (!_readStream) {
        SFLog(@"上传读取流初始化失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadReadStreamCreate);
        }
        return;
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"上传读取流打开失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteOpen);
        }
    }
    
    CFStringRef writeURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef writeURL = CFURLCreateWithString(kCFAllocatorDefault, writeURLString, NULL);
    _writeStream = CFWriteStreamCreateWithFTPURL(kCFAllocatorDefault, writeURL);
    CFRelease(writeURL);
    
    if (!_writeStream) {
        SFLog(@"上传写入流初始化失败");
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
        SFLog(@"设定上传写入回调失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteSetClient);
        }
    }
    
    if (!CFWriteStreamOpen(_writeStream)) {
        SFLog(@"上传写入流打开失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorUploadWriteOpen);
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
