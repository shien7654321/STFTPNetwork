//
//  STFTPDownloadRequest.m
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPDownloadRequest.h"

@implementation STFTPDownloadRequest {
    NSString *_urlString, *_filePath;
    STFTPProgressHandler _progerssHandler;
    STFTPDownloadSuccessHandler _successHandler;
    STFTPFailHandler _failHandler;
    CFWriteStreamRef _writeStream;
    CFReadStreamRef _readStream;
    BOOL _readStreamScheduled;
    UInt64 _bytesTotal, _bytesCompleted;
}

void downloadClientCB(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    STFTPDownloadRequest *request = (__bridge STFTPDownloadRequest *)clientCallBackInfo;
    CFNumberRef cfSize;
    UInt64 size;
    switch (type) {
        case kCFStreamEventOpenCompleted: {
            cfSize = CFReadStreamCopyProperty(stream, kCFStreamPropertyFTPResourceSize);
            if (cfSize) {
                if (CFNumberGetValue(cfSize, kCFNumberLongLongType, &size)) {
//                    SFLog(@"下载目标文件大小：%llu", size);
                    request->_bytesTotal = size;
                }
                CFRelease(cfSize);
            } else {
                SFLog(@"下载目标文件大小未知");
            }
            break;
        }
        case kCFStreamEventHasBytesAvailable: {
            UInt8 receiveBuffer[kBufferSize];
            CFIndex bytesRead = CFReadStreamRead(stream, receiveBuffer, kBufferSize);
//            SFLog(@"下载目标文件读取：%ld", bytesRead);
            if (bytesRead > 0) {
                NSInteger bytesOffset = 0;
                do {
                    CFIndex bytesWritten = CFWriteStreamWrite(request->_writeStream, &receiveBuffer[bytesOffset], bytesRead - bytesOffset);
                    if (bytesWritten > 0) {
                        bytesOffset += bytesWritten;
                        request->_bytesCompleted += bytesWritten;
                        request->_progerssHandler(request->_bytesCompleted, request->_bytesTotal);
                    } else if (bytesWritten == 0) {
                        break;
                    } else {
                        SFLog(@"下载读取流写入错误");
                        if (request->_failHandler) {
                            request->_failHandler(STFTPErrorDownloadReadWriteError);
                        }
                    }
                } while (bytesRead - bytesOffset > 0);
            }
            break;
        }
        case kCFStreamEventErrorOccurred: {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
            CFStreamError error = CFReadStreamGetError(stream);
            SFLog(@"下载读取流错误：%d", error.error);
#pragma clang diagnostic pop
            [request stop];
            if (request->_failHandler) {
                request->_failHandler(STFTPErrorDownloadReadError);
            }
            break;
        }
        case kCFStreamEventEndEncountered: {
            if (request->_successHandler) {
                NSData *data = [NSData dataWithContentsOfFile:request->_filePath];
                request->_successHandler(data);
            }
            [request stop];
            break;
        }
        default: break;
    }
}

+ (instancetype)download:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPDownloadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler {
    if (!urlString || ![urlString hasPrefix:@"ftp://"]) {
        if (failHandler) {
            failHandler(STFTPErrorURL);
        }
        return nil;
    }
    STFTPDownloadRequest *request = [[STFTPDownloadRequest alloc] init];
    request->_urlString = urlString;
    request->_progerssHandler = progressHandler;
    request->_successHandler = successHandler;
    request->_failHandler = failHandler;
    [request start];
    return request;
}

- (void)start {
    
    NSString *cacheFolderPath = [STFTPNetwork cacheFolderPath];
    NSString *uuidString = [NSUUID UUID].UUIDString;
    _filePath = [cacheFolderPath stringByAppendingPathComponent:uuidString];
//    SFLog(@"下载目标文件路径：%@", _filePath);
    NSURL *writeURL = [NSURL fileURLWithPath:_filePath];
    _writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)writeURL);
    
    if (!_writeStream) {
        SFLog(@"下载写入流初始化失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadWriteStreamCreate);
        }
        return;
    }
    
    if (!CFWriteStreamOpen(_writeStream)) {
        SFLog(@"下载写入流打开失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorWriteOpen);
        }
        return;
    }
    
    CFStringRef readURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef readURL = CFURLCreateWithString(kCFAllocatorDefault, readURLString, NULL);
    _readStream = CFReadStreamCreateWithFTPURL(kCFAllocatorDefault, readURL);
    CFRelease(readURL);
    
    if (!_readStream) {
        SFLog(@"下载读取流初始化失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadReadStreamCreate);
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
    
    CFReadStreamSetProperty(_readStream, kCFStreamPropertyFTPFetchResourceInfo, kCFBooleanTrue);//必须如此设置，CFFTPStream将发送STAT命令到FTP服务器获取文件信息，包括总规模。否则将无法在下载开始时获取下载目标文件大小
    
    //断点续传
//    kCFStreamPropertyFTPFileTransferOffset
//    kCFStreamPropertyAppendToFile : kCFBooleanTrue
    
    CFStreamClientContext clientContext = {
        0,
        (__bridge void *)self,
        (void *(*)(void *info))CFRetain,
        (void (*)(void *info))CFRelease,
        (CFStringRef (*)(void *info))CFCopyDescription
    };
    CFOptionFlags streamEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
    
    if (CFReadStreamSetClient(_readStream, streamEvents, downloadClientCB, &clientContext)) {
        _readStreamScheduled = YES;
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    } else {
        SFLog(@"设定下载读取回调失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadReadSetClient);
        }
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"下载读取流打开失败");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadReadOpen);
        }
    }
    
    
}

- (void)stop {
    if (_writeStream) {
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
        _writeStream = nil;
    }
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

@end
