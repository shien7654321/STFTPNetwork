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
    STFTPErrorURL = 1,//FTP服务器地址错误
    STFTPErrorReadSetClient,//设定读取回调失败
    STFTPErrorReadStreamCreate,//读取流创建失败
    STFTPErrorReadOpen,//读取流打开失败
    STFTPErrorReadByte,//读取字节失败
    STFTPErrorReadError,//读取流错误
    STFTPErrorReadParse,//读取解析失败
    STFTPErrorWriteSetClient,//设定写入回调失败
    STFTPErrorWriteStreamCreate,//写入流创建失败
    STFTPErrorWriteOpen,//写入流打开失败
    STFTPErrorWriteError,//写入流错误
    STFTPRemoveError,//删除失败
    STFTPErrorDownloadWriteStreamCreate,//下载写入流创建失败
    STFTPErrorDownloadWriteOpen,//下载写入流打开失败
    STFTPErrorDownloadReadStreamCreate,//下载读取流创建失败
    STFTPErrorDownloadReadSetClient,//设定下载读取回调失败
    STFTPErrorDownloadReadOpen,//下载读取流打开失败
    STFTPErrorDownloadReadWriteError,//下载读取流写入错误
    STFTPErrorDownloadReadError,//下载读取流错误
    STFTPErrorUploadReadStreamCreate,//上传读取流创建失败
    STFTPErrorUploadReadOpen,//上传读取流打开失败
    STFTPErrorUploadWriteStreamCreate,//上传写入流创建失败
    STFTPErrorUploadWriteSetClient,//设定上传写入回调失败
    STFTPErrorUploadWriteOpen,//上传写入流打开失败
    STFTPErrorUploadWriteWriteError,//上传写入流写入错误
    STFTPErrorUploadWriteError//上传写入流错误
};

typedef void(^STFTPConnectHandler)(BOOL success);
typedef void(^STFTPQuerySuccessHandler)(NSArray *results);
typedef void(^STFTPFailHandler)(STFTPErrorCode errorCode);
typedef void(^STFTPCreateSuccessHandler)();
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
