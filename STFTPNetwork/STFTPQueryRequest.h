//
//  STFTPQueryRequest.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"

@interface STFTPQueryRequest : NSObject

+ (instancetype)query:(NSString *)urlString successHandler:(STFTPQuerySuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;

@end
