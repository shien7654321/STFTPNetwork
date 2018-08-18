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
//                    SFLog(@"Download target file size: %llu", size);
                    request->_bytesTotal = size;
                }
                CFRelease(cfSize);
            } else {
                SFLog(@"Download target file size unknown");
            }
            break;
        }
        case kCFStreamEventHasBytesAvailable: {
            UInt8 receiveBuffer[kBufferSize];
            CFIndex bytesRead = CFReadStreamRead(stream, receiveBuffer, kBufferSize);
//            SFLog(@"Download target file read: %ld", bytesRead);
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
                        SFLog(@"Download readStream write error");
                        if (request->_failHandler) {
                            request->_failHandler(STFTPErrorDownloadReadStreamWriteError);
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
            SFLog(@"Download readStream error:%d", error.error);
#pragma clang diagnostic pop
            [request stop];
            if (request->_failHandler) {
                request->_failHandler(STFTPErrorDownloadReadStreamError);
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
//    SFLog(@"Download target file path: %@", _filePath);
    NSURL *writeURL = [NSURL fileURLWithPath:_filePath];
    _writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)writeURL);
    
    if (!_writeStream) {
        SFLog(@"Download writeStream initialization failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadWriteStreamCreate);
        }
        return;
    }
    
    if (!CFWriteStreamOpen(_writeStream)) {
        SFLog(@"Download writeStream open failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorWriteStreamOpen);
        }
        return;
    }
    
    CFStringRef readURLString = [STFTPNetwork cfString:_urlString];
    CFURLRef readURL = CFURLCreateWithString(kCFAllocatorDefault, readURLString, NULL);
    _readStream = CFReadStreamCreateWithFTPURL(kCFAllocatorDefault, readURL);
    CFRelease(readURL);
    
    if (!_readStream) {
        SFLog(@"Download readStream initialization failed");
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
    
    //It must be set this way. CFFTPStream will send the STAT command to the FTP server to get the file information, including the total size. Otherwise, you will not be able to get the download target file size at the beginning of download.
    CFReadStreamSetProperty(_readStream, kCFStreamPropertyFTPFetchResourceInfo, kCFBooleanTrue);
    
    //transmission resuming at break-points
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
        SFLog(@"Set download readStream callback failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadReadSteamSetClient);
        }
    }
    
    if (!CFReadStreamOpen(_readStream)) {
        SFLog(@"Download readStream open failed");
        [self stop];
        if (_failHandler) {
            _failHandler(STFTPErrorDownloadReadStreamOpen);
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
