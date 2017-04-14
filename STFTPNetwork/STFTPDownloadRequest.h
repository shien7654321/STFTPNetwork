//
//  STFTPDownloadRequest.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"

@interface STFTPDownloadRequest : NSObject

+ (instancetype)download:(NSString *)urlString progressHandler:(STFTPProgressHandler)progressHandler successHandler:(STFTPDownloadSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;

@end
