//
//  JDBFileDownloadOperation.m
//
//  Created by Bengang on 2016/12/25.
//  Copyright © 2016年 Bengang. All rights reserved.
//

#import "BGFileDownloadOperation.h"
#import "NSString+MD5.h"

@interface BGFileDownloadOperation ()

@property (readonly, getter=isExecuting) BOOL executing;
@property (readonly, getter=isFinished) BOOL finished;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy, readwrite) NSString *downloadURLString;
@property (nonatomic, strong, readwrite) NSURLSessionDataTask *dataTask;
@property (nonatomic, copy) NSString *tempFilePath;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, copy) NSURL *destinationPath;

@property (nonatomic, assign) unsigned long long totalContentLength;
@property (nonatomic, assign) unsigned long long offsetContentLength;
@property (nonatomic, assign) unsigned long long totalBytesReceived;            // 开始下载之后到现在一共收到的数据 不包括之前收到的数据

@end

@implementation BGFileDownloadOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)dealloc
{
    if (_outputStream) {
        [_outputStream close];
        _outputStream = nil;
    }
}

- (instancetype)initWithSession:(NSURLSession *)session
              downloadURLString:(NSString *)downloadURLString
                 fileIdentifier:(NSString *)fileIdentifier
{
    NSParameterAssert(session);
    NSParameterAssert(downloadURLString.length);
    self = [super init];
    if (self) {
        _session = session;
        _downloadURLString = downloadURLString;
        _fileIdentifier = fileIdentifier;
        _fileManager = [[NSFileManager alloc] init];
        _lock = [[NSRecursiveLock alloc] init];
        _timeoutInterval = 30;
    }
    return self;
}

- (NSURLRequest *)generateRangeRequest
{
    unsigned long long downloadedBytes = [self fileSizeForPath:self.tempFilePath];
    if (downloadedBytes > 1) {
        downloadedBytes--;
        NSMutableURLRequest *mutableURLRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.downloadURLString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeoutInterval];
        NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
        [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
        return [mutableURLRequest copy];
    } else {
        return [NSURLRequest requestWithURL:[NSURL URLWithString:self.downloadURLString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeoutInterval];
    }
}

- (void)start
{
    [self.lock lock];
    if (self.isCancelled) {
        [self cancleDownload];
    } else if (!self.isFinished && self.isReady) {
        self.executing = YES;
        [self.outputStream open];
        NSURLRequest *rangeRequest = [self generateRangeRequest];
        self.dataTask = [self.session dataTaskWithRequest:rangeRequest];
        [self.dataTask resume];
    }
    [self.lock unlock];
}

- (NSString *)descriptionWithRequest:(NSURLRequest *)request
{
    NSString *range = [request.allHTTPHeaderFields objectForKey:@"Range"];
    return [NSString stringWithFormat:@"<downloadURLString:%@ 开始下载 Range:%@>",self.downloadURLString, range];
}

- (void)cancel
{
    [self.lock lock];
    if (![self isFinished] && ![self isCancelled]) {
        [super cancel];
        if ([self isExecuting]) {
            [self cancleDownload];
        }
    }
    [self.lock unlock];
}

- (void)cancleDownload
{
    if (!self.isFinished) {
        NSDictionary *userInfo = nil;
        if (self.downloadURLString) {
            userInfo = @{NSURLErrorFailingURLErrorKey: [NSURL URLWithString:self.downloadURLString]};
        }
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
        self.error = error;
        [self.dataTask cancel];
        [self markFinished];
    }
}

- (void)setExecuting:(BOOL)executing
{
    [self.lock lock];
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
    [self.lock unlock];
}

- (void)setFinished:(BOOL)finished
{
    [self.lock lock];
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
    [self.lock unlock];
}

- (void)markFinished
{
    self.executing = NO;
    self.finished = YES;
}

- (void)setFileDownloadSuccedBlock:(BGFileDownloadSuccedBlock)fileDownloadSuccedBlock fileDownloadFaileBlock:(BGFileDownloadFailedBlock)fileDownloadFailedBlock
{
    [self.lock lock];
    __weak __typeof(self) weakSelf = self;
    [self setCompletionBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.error) {
            if (fileDownloadFailedBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    fileDownloadFailedBlock(strongSelf, strongSelf.error);
                });
            }
        } else {
            if (fileDownloadSuccedBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    fileDownloadSuccedBlock(strongSelf, strongSelf.destinationPath);
                });
            }
        }
    }];
    [self.lock unlock];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        self.error = [NSError errorWithDomain:@"is not a httpResponse" code:-1 userInfo:nil];
        [self markFinished];
        if (completionHandler) {
            completionHandler(NSURLSessionResponseCancel);
        }
        return;
    }
    if (httpResponse.statusCode != 200 && httpResponse.statusCode != 206){
        self.error = [NSError errorWithDomain:NSURLErrorDomain code:httpResponse.statusCode userInfo:nil];
        [self markFinished];
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
        return;
    }
    self.totalBytesReceived = 0;
    long long totalContentLength = response.expectedContentLength;
    long long fileOffset = 0;
    if (httpResponse.statusCode == 206) {
        NSString *contentRange = [httpResponse.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {               // 正常响应示例： Content-Range: bytes 0-800/801 //801:文件总大小
                fileOffset = [bytes[1] longLongValue];
                totalContentLength = [bytes[3] longLongValue]; // if this is *, it's converted to 0
            }
        }
    }
    self.totalContentLength = totalContentLength;
    self.offsetContentLength = MAX(fileOffset, 0);
    if ([self fileSizeForPath:self.tempFilePath] != self.offsetContentLength) {
        [self.outputStream close];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:self.tempFilePath];
        [file truncateFileAtOffset:self.offsetContentLength];
        [file closeFile];
        self.outputStream = [NSOutputStream outputStreamToFileAtPath:self.tempFilePath append:YES];
        [self.outputStream open];
    }
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    NSUInteger length = [data length];
    while (YES) {
        NSInteger totalNumberOfBytesWritten = 0;
        if ([self.outputStream hasSpaceAvailable]) {
            const uint8_t *dataBuffer = (uint8_t *)[data bytes];
            NSInteger numberOfBytesWritten = 0;
            while (totalNumberOfBytesWritten < (NSInteger)length) {
                numberOfBytesWritten = [self.outputStream write:&dataBuffer[(NSUInteger)totalNumberOfBytesWritten] maxLength:(length - (NSUInteger)totalNumberOfBytesWritten)];
                if (numberOfBytesWritten == -1) {
                    break;
                }
                totalNumberOfBytesWritten += numberOfBytesWritten;
            }
            break;
        } else {
            [self.dataTask cancel];
            if (self.outputStream.streamError) {
                [self URLSession:session task:dataTask didCompleteWithError:self.outputStream.streamError];
            }
            return;
        }
    }
    self.totalBytesReceived += [data length];
    if (self.fileDownloadProgressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.fileDownloadProgressBlock(self.totalBytesReceived + self.offsetContentLength, self.totalContentLength);
        });
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error
{
    [self.outputStream close];
    self.error = error;
    if (!error) {
        self.destinationPath = [NSURL fileURLWithPath:self.tempFilePath];
        if (self.destinationBlock) {
            NSURL *movePath = self.destinationBlock((NSURLSessionDataTask *)task, [NSURL fileURLWithPath:self.tempFilePath], task.response);
            if (movePath && [movePath isFileURL]) {
                self.destinationPath = movePath;
                NSError *fileHandleError = nil;
                if ([self.fileManager fileExistsAtPath:self.destinationPath.absoluteString ]) {
                    [self.fileManager removeItemAtURL:self.destinationPath error:&fileHandleError];
                }
                [self.fileManager moveItemAtURL:[NSURL fileURLWithPath:self.tempFilePath] toURL:self.destinationPath error:&fileHandleError];
                self.error = fileHandleError;
            }
        }
    }
    [self markFinished];
}

#pragma mark - private

- (unsigned long long)fileSizeForPath:(NSString *)path
{
    unsigned long long fileSize = 0;
    if ([self.fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [self.fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

- (NSString *)cacheFolderPath
{
    NSString *libraryCachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cacheFolderPath = [libraryCachePath stringByAppendingPathComponent:kIncompleteDownloadFolderName];
    if (![self.fileManager fileExistsAtPath:cacheFolderPath]) {
        NSError *error = nil;
        BOOL created = [self.fileManager createDirectoryAtPath:cacheFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!created) {
            NSLog(@"创建Incomplete 文件夹失败！");
        }
    }
    return cacheFolderPath;
}

#pragma mark - lazyload

- (NSOutputStream *)outputStream
{
    if (!_outputStream) {
        _outputStream = [NSOutputStream outputStreamToFileAtPath:self.tempFilePath append:YES];
    }
    return _outputStream;
}

- (NSString *)tempFilePath
{
    if (!_tempFilePath) {
        if (!self.fileIdentifier) {
            self.fileIdentifier = [NSString bg_md5StringForString:self.downloadURLString];
        }
        _tempFilePath = [[self cacheFolderPath] stringByAppendingPathComponent:self.fileIdentifier];
    }
    return _tempFilePath;
}

@end
