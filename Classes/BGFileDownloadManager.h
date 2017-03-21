//
//  JDBFileDownloadManager.h
//  JDBClient
//
//  Created by Bengang on 2016/12/23.
//  Copyright © 2016年 JDB. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "BGFileDownloadOperation.h"

@interface BGFileDownloadManager : NSObject

- (BGFileDownloadOperation *)downloadWithURLString:(NSString *)downloadURLString
                                        destination:(BGFileDownloadDestinationBlock)destinationBlock
                                      progressBlock:(BGFileDownloadProgressBlock)progressBlock
                                          successed:(BGFileDownloadSuccedBlock)successedBlock
                                             failed:(BGFileDownloadFailedBlock)failedBlock;

- (void)updateCallbacksWithURLString:(NSString *)downloadURLString
                       progressBlock:(BGFileDownloadProgressBlock)progressBlock
                           successed:(BGFileDownloadSuccedBlock)successedBlock
                              failed:(BGFileDownloadFailedBlock)failedBlock;


- (BOOL)isDownloading;

- (NSArray<NSString *> *)downloadingTasks;

@end
