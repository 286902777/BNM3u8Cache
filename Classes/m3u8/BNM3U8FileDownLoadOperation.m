//
//  BNM3U8FileDownLoadOperation.m
//  m3u8Demo
//
//  Created by liangzeng on 6/14/19.
//  Copyright © 2019 liangzeng. All rights reserved.
//

#import "BNM3U8FileDownLoadOperation.h"
#import "BNFileManager.h"

@interface BNM3U8FileDownLoadOperation ()
@property (nonatomic, strong) NSObject <BNM3U8FileDownloadProtocol> *fileInfo;
@property (nonatomic, strong) BNM3U8FileDownLoadOperationSpeedBlock speedBlock;
@property (nonatomic, strong) BNM3U8FileDownLoadOperationResultBlock resultBlock;
@property (nonatomic, strong) AFURLSessionManager *sessionManager;
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (nonatomic, strong) NSURLSessionDownloadTask *dataTask;
@end

@implementation BNM3U8FileDownLoadOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithFileInfo:(NSObject <BNM3U8FileDownloadProtocol> *)fileInfo sessionManager:(AFURLSessionManager*)sessionManager
                      speedBlock:(nonnull BNM3U8FileDownLoadOperationSpeedBlock)speedBlock resultBlock:(nonnull BNM3U8FileDownLoadOperationResultBlock)resultBlock {
    NSParameterAssert(fileInfo);
    self = [super init];
    if (self) {
        _fileInfo = fileInfo;
        _speedBlock = speedBlock;
        _resultBlock = resultBlock;
        _sessionManager = sessionManager;
    }
    return self;
}

#pragma mark -
- (void)start
{
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        
        if([BNFileManager exitItemWithPath:_fileInfo.dstFilePath]){
            _resultBlock(nil,_fileInfo);
            [self done];
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_fileInfo.downloadUrl]];
        
        __block NSData *data = nil;
        __block int64_t dataCount = 0;
        __block int64_t sCount = 0;
        __weak __typeof(self) weakSelf = self;
        NSURLSessionDownloadTask *downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            if (dataCount >= downloadProgress.totalUnitCount) {
                dataCount = 0;
            }
            if (sCount != downloadProgress.completedUnitCount - dataCount) {
                sCount = downloadProgress.completedUnitCount - dataCount;
                if (weakSelf.speedBlock) {
                    weakSelf.speedBlock(sCount);
                }
            }
            dataCount = downloadProgress.completedUnitCount;
            
#if DEBUG
//            NSLog(@"%@:%0.2lf%%\n",weakSelf.fileInfo.downloadUrl, (float)downloadProgress.completedUnitCount / (float)downloadProgress.totalUnitCount * 100);
#endif
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            data = [NSData dataWithContentsOfURL:targetPath];
            return nil;
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            if (weakSelf != nil) {
                if (!error) {
                    [weakSelf saveData:data];
                }
                else
                {
                    weakSelf.resultBlock(error, weakSelf.fileInfo);
                    [weakSelf done];
                }
            }
        }];
        self.dataTask = downloadTask;
        [downloadTask resume];
        self.executing = YES;
    }
}

- (void)cancel{
    @synchronized (self) {
        if(self.isFinished) return;
        [super cancel];
        [self.dataTask cancel];
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
        [self reset];
    }
}

#pragma mark -
- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset {
    @synchronized (self) {
        self.dataTask = nil;
    }
}

- (void)saveData:(NSData *)data
{
    __weak __typeof(self) weakSelf = self;
    [[BNFileManager shareInstance] saveDate:data ToFile:[_fileInfo dstFilePath] completaionHandler:^(NSError *error) {
            if(weakSelf.resultBlock) weakSelf.resultBlock(error, weakSelf.fileInfo);
            [weakSelf done];
    }];
}

- (void)suspend {
    @synchronized (self) {
        [self.dataTask suspend];
        NSLog(@"[self.dataTask suspend]");
    }
}

- (void)resume {
    @synchronized (self) {
        [self.dataTask resume];
        NSLog(@"[self.dataTask resume]");
    }
}

#pragma mark -
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

@end
