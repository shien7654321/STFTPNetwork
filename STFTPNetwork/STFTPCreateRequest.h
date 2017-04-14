//
//  STFTPCreateRequest.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"

@interface STFTPCreateRequest : NSObject

+ (instancetype)create:(NSString *)urlString successHandler:(STFTPCreateSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;

@end
