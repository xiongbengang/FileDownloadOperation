//
//  JDBFileDownloadOperation.h
//
//  Created by Bengang on 2016/12/25.
//  Copyright © 2016年 Bengang. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BGFileDownloadOperation;

#define kIncompleteDownloadFolderName @"com.filedownload.Incomplete"

typedef void(^BGFileDownloadProgressBlock)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void(^BGFileDownloadSuccedBlock)(BGFileDownloadOperation *downloadOperation, NSURL *targetPath);
typedef void(^BGFileDownloadFailedBlock)(BGFileDownloadOperation *downloadOperation, NSError *error);
typedef NSURL *(^BGFileDownloadDestinationBlock)(NSURLSessionDataTask *dataTask, NSURL *targetPath, NSURLResponse *response);

@interface BGFileDownloadOperation : NSOperation <NSURLSessionDataDelegate>

@property (nonatomic, copy, readonly) NSString *downloadURLString;
@property (nonatomic, copy, readwrite) NSString *fileIdentifier;
@property (nonatomic, strong, readonly) NSURLSessionDataTask *dataTask;
@property (nonatomic, assign, readwrite) NSTimeInterval timeoutInterval;

@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) BGFileDownloadProgressBlock fileDownloadProgressBlock;
@property (nonatomic, copy) BGFileDownloadDestinationBlock destinationBlock;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSession:(NSURLSession *)session
              downloadURLString:(NSString *)downloadURLString
                 fileIdentifier:(NSString *)fileIdentifier;

- (void)setFileDownloadSuccedBlock:(BGFileDownloadSuccedBlock)fileDownloadSuccedBlock fileDownloadFaileBlock:(BGFileDownloadFailedBlock)fileDownloadFailedBlock;

- (void)setFileDownloadProgressBlock:(BGFileDownloadProgressBlock)progressBlock;

- (void)setDestinationBlock:(BGFileDownloadDestinationBlock)destinationBlock;

@end
