//
//  JDBFileDownloadManager.m
//  JDBClient
//
//  Created by Bengang on 2016/12/23.
//  Copyright © 2016年 JDB. All rights reserved.
//

#import "BGFileDownloadManager.h"
#import "NSString+MD5.h"

@interface BGFileDownloadManager () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSURLSessionConfiguration *configuration;
@property (nonatomic, strong) NSOperationQueue *downloadOperationQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, BGFileDownloadOperation *> *downloadingOperations;
@end

@implementation BGFileDownloadManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _urlSession = [NSURLSession sessionWithConfiguration:_configuration delegate:self delegateQueue:nil];
        _downloadOperationQueue = [[NSOperationQueue alloc] init];
        _downloadOperationQueue.maxConcurrentOperationCount = 6;
        _downloadingOperations = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isDownloading
{
    return !self.downloadOperationQueue.isSuspended && self.downloadOperationQueue.operationCount > 0;
}

- (BGFileDownloadOperation *)downloadWithURLString:(NSString *)downloadURLString
                                        destination:(BGFileDownloadDestinationBlock)destinationBlock
                                      progressBlock:(BGFileDownloadProgressBlock)progressBlock
                                          successed:(BGFileDownloadSuccedBlock)successedBlock
                                             failed:(BGFileDownloadFailedBlock)failedBlock
{
    NSParameterAssert(downloadURLString);
    NSString *fileIdentifier = [NSString bg_md5StringForString:downloadURLString];
    
    BGFileDownloadOperation *downloadOperation = self.downloadingOperations[downloadURLString];
    if (!downloadOperation) {
        downloadOperation = [[BGFileDownloadOperation alloc] initWithSession:self.urlSession downloadURLString:downloadURLString fileIdentifier:fileIdentifier];
        [self.downloadingOperations setObject:downloadOperation forKey:downloadURLString];
    }
    [downloadOperation setDestinationBlock:destinationBlock];
    [self updateCallbacksWithURLString:downloadURLString progressBlock:progressBlock successed:successedBlock failed:failedBlock];
    [self.downloadOperationQueue addOperation:downloadOperation];
    return downloadOperation;
}

- (void)updateCallbacksWithURLString:(NSString *)downloadURLString
                       progressBlock:(BGFileDownloadProgressBlock)progressBlock
                           successed:(BGFileDownloadSuccedBlock)successedBlock
                              failed:(BGFileDownloadFailedBlock)failedBlock;

{
    BGFileDownloadOperation *downloadOperation = self.downloadingOperations[downloadURLString];
    [downloadOperation setFileDownloadProgressBlock:progressBlock];
    [downloadOperation setFileDownloadSuccedBlock:^(BGFileDownloadOperation *downloadOperation, NSURL *targetPath) {
        [self.downloadingOperations removeObjectForKey:downloadURLString];
        if (successedBlock) {
            successedBlock(downloadOperation, targetPath);
        }
    } fileDownloadFaileBlock:^(BGFileDownloadOperation *downloadOperation, NSError *error) {
        [self.downloadingOperations removeObjectForKey:downloadURLString];
        if (failedBlock) {
            failedBlock(downloadOperation, error);
        }
    }];
}

- (BGFileDownloadOperation *)operationWithTask:(NSURLSessionTask *)task
{
    BGFileDownloadOperation *returnOperation = nil;
    for (BGFileDownloadOperation *operation in self.downloadOperationQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    BGFileDownloadOperation *operation = [self operationWithTask:dataTask];
    [operation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    BGFileDownloadOperation *operation = [self operationWithTask:dataTask];
    [operation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error
{
    BGFileDownloadOperation *operation = [self operationWithTask:task];
    [operation URLSession:session task:task didCompleteWithError:error];
}

- (NSArray<NSString *> *)downloadingTasks
{
    NSMutableArray *downloadURLStrings = [NSMutableArray arrayWithCapacity:self.downloadOperationQueue.operations.count];
    for (BGFileDownloadOperation *fileOperation in self.downloadingOperations.allValues) {
        [downloadURLStrings addObject:fileOperation.downloadURLString];
    }
    return downloadURLStrings;
}

@end
