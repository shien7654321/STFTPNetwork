//
//  STFTPNetwork.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/dirent.h>

#ifdef DEBUG
#define SFLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define SFLog(...)
#endif

UIKIT_EXTERN const CFIndex kBufferSize;

typedef NS_ENUM(NSInteger, STFTPErrorCode) {
    STFTPErrorURL = 1,//FTP server address error
    STFTPErrorReadStreamSetClient,//set readStream callback failed
    STFTPErrorReadStreamCreate,//readStream creation failed
    STFTPErrorReadStreamOpen,//readStream open failed
    STFTPErrorReadByte,//read byte failed
    STFTPErrorReadError,//read stream error
    STFTPErrorReadParse,//read parsing failed
    STFTPErrorWriteStreamSetClient,//set writeStream callback failed
    STFTPErrorWriteStreamCreate,//writeStream creation failed
    STFTPErrorWriteStreamOpen,//writeStream open failed
    STFTPErrorWriteError,//write stream error
    STFTPRemoveError,//remove failed
    STFTPErrorDownloadWriteStreamCreate,//download writeStream creation failed
    STFTPErrorDownloadWriteStreamOpen,//download writeStream open failed
    STFTPErrorDownloadReadStreamCreate,//download readStream creation failed
    STFTPErrorDownloadReadSteamSetClient,//set download readStream callback failed
    STFTPErrorDownloadReadStreamOpen,//download readStream open failed
    STFTPErrorDownloadReadStreamWriteError,//download readStream write error
    STFTPErrorDownloadReadStreamError,//download readStream error
    STFTPErrorUploadReadStreamCreate,//upload readStream creation failed
    STFTPErrorUploadReadStreamOpen,//upload readStream open failed
    STFTPErrorUploadWriteStreamCreate,//upload writeStream creation failed
    STFTPErrorUploadWriteStreamSetClient,//set upload writeStream callback failed
    STFTPErrorUploadWriteStreamOpen,//upload writeStream open failed
    STFTPErrorUploadWriteStreamWriteError,//upload writeStream write error
    STFTPErrorUploadWriteStreamError//upload writeStream error
};

typedef void(^STFTPConnectHandler)(BOOL success);
typedef void(^STFTPQuerySuccessHandler)(NSArray *results);
typedef void(^STFTPFailHandler)(STFTPErrorCode errorCode);
typedef void(^STFTPCreateSuccessHandler)(void);
typedef STFTPCreateSuccessHandler STFTPRemoveSuccessHandler;
typedef void(^STFTPProgressHandler)(unsigned long long bytesCompleted, unsigned long long bytesTotal);
typedef void(^STFTPDownloadSuccessHandler)(NSData *data);
typedef STFTPCreateSuccessHandler STFTPUploadSuccessHandler;

@interface STFTPNetwork : NSObject

@property (nonatomic, strong, readonly) NSString *urlString;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *password;

#pragma mark -

+ (instancetype)sharedNetwork;
+ (void)connect:(NSString *)urlString handler:(STFTPConnectHandler)handler;
+ (void)connect:(NSString *)urlString username:(NSString *)username password:(NSString *)password handler:(STFTPConnectHandler)handler;
+ (void)disconnect;
+ (NSString *)totalFTPURLString:(NSString *)urlString;
+ (BOOL)query:(NSString *)urlString successHandler:(STFTPQuerySuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;
+ (BOOL)create:(NSString *)urlString successHandler:(STFTPCreateSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;
+ (BOOL)remove:(NSString *)urlString successHandler:(STFTPRemoveSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;
+ (BOOL)download:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPDownloadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;
+ (BOOL)upload:(NSString *)filePath urlString:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPUploadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;
+ (NSString *)cacheFolderPath;
+ (void)clearCache;
+ (CFStringRef)cfString:(NSString *)string;

@end
