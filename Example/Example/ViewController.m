//
//  ViewController.m
//  Example
//
//  Created by Bengang on 2017/3/21.
//  Copyright © 2017年 Bengang. All rights reserved.
//

#import "ViewController.h"
#import <BGFileDownloadManager.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (strong, nonatomic) BGFileDownloadManager *downloadManager;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.downloadManager = [[BGFileDownloadManager alloc] init];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)startButtonClick:(id)sender
{
    NSString *qqDownloadURLString = @"http://dldir1.qq.com/qqfile/QQforMac/QQ_V5.4.1.dmg";
    __weak __typeof(self) weakSelf = self;
    [self.downloadManager downloadWithURLString:qqDownloadURLString destination:^NSURL *(NSURLSessionDataTask *dataTask, NSURL *targetPath, NSURLResponse *response) {
        NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        return [NSURL fileURLWithPath:[documentPath stringByAppendingPathComponent:response.suggestedFilename]];
    } progressBlock:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        if (totalBytesExpectedToWrite > 0) {
            [weakSelf.progressView setProgress:totalBytesWritten / (float)totalBytesExpectedToWrite animated:YES];
        }
    } successed:^(BGFileDownloadOperation *downloadOperation, NSURL *targetPath) {
        [weakSelf.startButton setTitle:@"done" forState:UIControlStateNormal];
    } failed:^(BGFileDownloadOperation *downloadOperation, NSError *error) {
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
