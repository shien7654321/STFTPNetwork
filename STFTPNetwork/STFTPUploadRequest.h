//
//  STFTPUploadRequest.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"

@interface STFTPUploadRequest : NSObject

+ (instancetype)upload:(NSString *)filePath urlString:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPUploadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;

@end
