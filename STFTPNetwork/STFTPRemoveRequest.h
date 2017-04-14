//
//  STFTPRemoveRequest.h
//  STFTPNetwork
//
//  Created by Suta on 2017/4/14.
//  Copyright © 2017年 Suta. All rights reserved.
//

#import "STFTPNetwork.h"

@interface STFTPRemoveRequest : NSObject

+ (instancetype)remove:(NSString *)urlString successHandler:(STFTPRemoveSuccessHandler)successHandler failHandler:(STFTPFailHandler)failHandler;

@end
