//
//  BNM3U8Manager.m
//  m3u8Demo
//
//  Created by liangzeng on 6/14/19.
//  Copyright © 2019 liangzeng. All rights reserved.
//

#import "BNM3U8Manager.h"
#import "BNM3U8DownloadOperation.h"
#import "AFNetworking.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

@implementation BNM3U8ManagerConfig
@end

@interface BNM3U8Manager()
@property (nonatomic, strong) BNM3U8ManagerConfig *config;
@property (nonatomic, strong) NSMutableDictionary <NSString*, BNM3U8DownloadOperation*> *downloadOperationsMap;
@property (nonatomic, strong) dispatch_semaphore_t operationSemaphore;
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, strong) AFURLSessionManager *sessionManager;
@end

@implementation BNM3U8Manager

+ (instancetype)shareInstance{
    static BNM3U8Manager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = BNM3U8Manager.new;
        manager.operationSemaphore = dispatch_semaphore_create(1);
        manager.downloadQueue = [[NSOperationQueue alloc]init];
        manager.downloadQueue.qualityOfService = NSQualityOfServiceUtility;
        manager.downloadOperationsMap = NSMutableDictionary.new;
    });
    return manager;
}

- (void)fillConfig:(BNM3U8ManagerConfig*)config{
    if (!_config) {
        _config = config;
        _downloadQueue.maxConcurrentOperationCount = _config.videoMaxConcurrenceCount;
    }
    else{
        NSAssert(0, @"config不允许重新赋值");
    }
}

#pragma mark -
- (void)downloadVideoWithConfig:(BNM3U8DownloadConfig *)config
                  progressBlock:(BNM3U8DownloadProgressBlock)progressBlock
                     speedBlock:(BNM3U8DownloadSpeedBlock)speedBlock
                    resultBlock:(BNM3U8DownloadResultBlock)resultBlock{
    
    NSParameterAssert(config.url);
    LOCK(_operationSemaphore);
    if([_downloadOperationsMap.allKeys containsObject:config.url]){
        NSLog(@"任务已经存在！");
        UNLOCK(_operationSemaphore);
        return;
    }
    UNLOCK(_operationSemaphore);

    BNM3U8DownloadOperation *operation =  [[BNM3U8DownloadOperation alloc] initWithConfig:config downloadDstRootPath:self.config.downloadDstRootPath sessionManager:self.sessionManager progressBlock:^(CGFloat progress) {
        if(progressBlock) progressBlock(progress);
    } speedBlock:^(int64_t data) {
        if(speedBlock) speedBlock(data);
    } resultBlock:^(NSError * _Nullable error, NSString * _Nullable relativeUrl, NSString * _Nullable name) {
        ///下载回调
        if(resultBlock) resultBlock(error, relativeUrl, name);
        LOCK(self.operationSemaphore);
        [self.downloadOperationsMap removeObjectForKey:config.url];
        UNLOCK(self.operationSemaphore);
    }];
    LOCK(_operationSemaphore);
    [_downloadOperationsMap setValue:operation forKey:config.url];
    [_downloadQueue addOperation:operation];
    UNLOCK(_operationSemaphore);
}

- (void)cannel:(NSString *)url{
    if ([_downloadOperationsMap valueForKey:url] == nil) {
        return;
    }
    LOCK(_operationSemaphore);
    BNM3U8DownloadOperation *operation = [_downloadOperationsMap valueForKey:url];
    UNLOCK(_operationSemaphore);
    if(!operation)return;
    NSParameterAssert(operation);
    if (!operation.isCancelled) {
        [operation cancel];
    }
    ///remove
    LOCK(_operationSemaphore);
    [_downloadOperationsMap removeObjectForKey:url];
    UNLOCK(_operationSemaphore);
}

/*全部取消,遍历operation cnnel. queue的cannel all operation 只能在创建/重新创建或者 dealloc时执行*/
- (void)cancels:(NSArray *)urls{
    LOCK(_operationSemaphore);
    NSArray *arr = _downloadOperationsMap.allKeys;
    UNLOCK(_operationSemaphore);
    [arr enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString * u in urls) {
            if ([u isEqualToString:url]) {
                [self cannel:url];
            }
        }
    }];
}

- (void)suspends: (NSArray *)urls{
    if(_downloadQueue.suspended) return;
    _downloadQueue.suspended = YES;
    LOCK(_operationSemaphore);
    NSArray *arr = _downloadOperationsMap.allKeys;
    [arr enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString * u in urls) {
            if ([u isEqualToString:url]) {
                BNM3U8DownloadOperation *operation = [self.downloadOperationsMap valueForKey:url];
                [operation suspend];
            }
        }
    }];
    UNLOCK(_operationSemaphore);
}

- (void)resumes:(NSArray *)urls{
    if(!_downloadQueue.suspended) return;
    _downloadQueue.suspended = NO;
    LOCK(_operationSemaphore);
    NSArray *arr = _downloadOperationsMap.allKeys;
    [arr enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString * u in urls) {
            if ([u isEqualToString:url]) {
                BNM3U8DownloadOperation *operation = [self.downloadOperationsMap valueForKey:url];
                [operation resume];
            }
        }
    }];
    UNLOCK(_operationSemaphore);
}

- (AFURLSessionManager *)sessionManager
{
    if (!_sessionManager) {
        NSURLSessionConfiguration * s = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"video_down"];
        s.sessionSendsLaunchEvents = YES;
        _sessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:s];
        _sessionManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return _sessionManager;
}

@end
