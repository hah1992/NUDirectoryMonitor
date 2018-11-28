//
//  NUDirectoryMonitor.m
//
//
//  Created by Huang,Anhua on 2018/10/26.
//  Copyright © 2018年 nuclear. All rights reserved.
//

#import "NUDirectoryMonitor.h"
#import "NUDirectoryCacheConfig.h"

@interface NUDirectorMonitorModel : NSObject
@property(nonatomic, copy) NSString *path;;
@property(nonatomic, strong) dispatch_source_t source;
@property(nonatomic, strong) NUDirectoryCacheConfig *config;
+ (instancetype)modelWithPath:(NSString *)path
                       source:(dispatch_source_t)source
                       config:(NUDirectoryCacheConfig *)config;
@end

//static dispatch_queue_t ioQueue
@interface NUDirectoryMonitor()
@property(nonatomic, strong) dispatch_queue_t monitorQueue;
@property(nonatomic, strong) dispatch_queue_t ioQueue;
@property(nonatomic, strong) NSMutableDictionary *sourceInfo;
@property(nonatomic, strong) NSFileManager *fileManager;
@end

@implementation NUDirectoryMonitor

+ (void)startMonitorDirectoryAtPath:(NSString *)path
                   usingCacheConfig:(NUDirectoryCacheConfig *)config
                        changeBlock:(void (^)(NUDirectoryChangeEvent events))block {
    [[NUDirectoryMonitor sharedMonitor] monitorDirectoryAtPath:path usingCacheConfig:config changeBlock:block];
}

+ (void)stopMonitorDirectoryAtPath:(NSString *)path {
    NSMutableDictionary *dic = [NUDirectoryMonitor sharedMonitor].sourceInfo;
    dispatch_source_t source = [(NUDirectorMonitorModel *)dic[path] source];
    !source ?: dispatch_source_cancel(source);
    [dic removeObjectForKey:path];
}


#pragma mark - private

+ (instancetype)sharedMonitor {
    static NUDirectoryMonitor *monitor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitor = [[NUDirectoryMonitor alloc] init];
    });
    
    return monitor;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _monitorQueue = dispatch_queue_create("com.nuclear.pan.directoryMonitorQuque", DISPATCH_QUEUE_CONCURRENT);
        _ioQueue = dispatch_queue_create("com.nuclear.pan.directoryIOQuque", DISPATCH_QUEUE_CONCURRENT);
        _sourceInfo = [NSMutableDictionary dictionary];
        dispatch_sync(_ioQueue, ^{
            self->_fileManager = [[NSFileManager alloc] init];
        });
    }
    return self;
}

- (void)dealloc {
    NSArray <NSString *> *keys = self.sourceInfo.allKeys;
    for (NSString *modelkey in keys) {
        NUDirectorMonitorModel *model = self.sourceInfo[modelkey];
        model.source ?: dispatch_cancel(model.source);
    }
}


- (void)monitorDirectoryAtPath:(NSString *)path usingCacheConfig:(NUDirectoryCacheConfig *)config changeBlock:(void (^)(NUDirectoryChangeEvent events))block {
    int dirFD = open([path fileSystemRepresentation], O_EVTONLY);
    if (dirFD > 0) {
        unsigned long event =
        DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE | DISPATCH_VNODE_WRITE;
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, dirFD, event, self.monitorQueue);

        dispatch_source_set_event_handler(source, ^() {
            unsigned long eventTypes = dispatch_source_get_data(source);
            if (eventTypes & DISPATCH_VNODE_WRITE) {
                [self autoCleanDirectoryCache:path withConfig:config];
            }
            if (!block) {
                return;
            }
            [self notifyEventsChange:eventTypes withConfig:config changeBlock:block];
        });
        
        dispatch_source_set_cancel_handler(source, ^() {
            close(dirFD);
            [self.sourceInfo removeObjectForKey:path];
        });
        
        dispatch_resume(source);
        
        NUDirectorMonitorModel *model = [NUDirectorMonitorModel modelWithPath:path source:source config:config];
        [self.sourceInfo setValue:model forKey:path];
    }
}

- (void)autoCleanDirectoryCache:(NSString *)path withConfig:(NUDirectoryCacheConfig *)config {
    
    NSArray *directoryList = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (directoryList.count == 0) {
        return;
    }
    NSString *key = [path stringByReplacingOccurrencesOfString:directoryList.lastObject withString:@""];
    NSTimeInterval lastTime = [NUDirectoryMonitor lasMonitorDirectoryCacheTimeSince1970AtPath:key];
    
    // 距离上次清除时间间隔太短
    NSTimeInterval interval = [[NSDate date] timeIntervalSince1970] - lastTime;
    if (interval < config.monitorTimeInterval) {
        return;
    }
    
    @autoreleasepool {
        NSUInteger currentCacheSize = 0;
        NSURLResourceKey cacheContentKey = [self keyForCacheStrategy:config.cleanStrategy];
        NSURL *diskCacheURL = [NSURL fileURLWithPath:path isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, cacheContentKey, NSURLTotalFileAllocatedSizeKey];
        
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                       includingPropertiesForKeys:resourceKeys
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     errorHandler:NULL];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-config.cacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        
        // 1. 先清除过期的文件
        // 2. 计算剩余的文件size是否超过设置大小
        // 3. 计算剩余的文件个数是否超过设置
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
            
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            // 统计过期的文件
            NSDate *modificationDate = resourceValues[cacheContentKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                // 未设定filter或者满足filter条件的URL，添加到待删除数组中
                if (!config.filter || (config.filter && config.filter(fileURL))) {
                    [urlsToDelete addObject:fileURL];
                }
                continue;
            }
            
            // 计算删除后的剩余的文件size大小
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
        }
        
        // 删除过期文件
        for (NSURL *fileURL in urlsToDelete) {
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // 进行cache size维度的清除
        if (config.limiteCacheSize > 0 && currentCacheSize > config.limiteCacheSize) {
            // 设定 target 为 cache size 的 4/5
            const NSUInteger desiredCacheSize = config.limiteCacheSize / 5 * 4;
            // 按时间 晚->早 的顺序排序文件
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[cacheContentKey] compare:obj2[cacheContentKey]];
                                                                     }];
            // 删除文件
            for (NSURL *fileURL in sortedFiles) {
                // 忽略不符合filter条件的URL
                if (config.filter && !config.filter(fileURL)) {
                    continue;
                }
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    // 移除已经清除的文件
                    [cacheFiles removeObjectForKey:fileURL];
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        
        // 进行文件个数维度清除
        if (config.limiteFileCount > 0 && cacheFiles.count > config.limiteFileCount) {
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[cacheContentKey] compare:obj2[cacheContentKey]];
                                                                     }];
            for (NSUInteger i = 0; i < sortedFiles.count - config.limiteFileCount/2; i ++) {
                NSURL *fileURL = [sortedFiles objectAtIndex:i];
                // 忽略不符合filter条件的URL
                if (config.filter && !config.filter(fileURL)) {
                    continue;
                }
                [self.fileManager removeItemAtURL:sortedFiles[i] error:nil];
            }
        }
        
        // 记录当前时间
        [NUDirectoryMonitor setMonitorDirectoryCacheTimeSince1970AtPath:key];
    }
}

- (void)notifyEventsChange:(unsigned long)eventTypes
                withConfig:(NUDirectoryCacheConfig *)config
                 changeBlock:(void (^)(NUDirectoryChangeEvent events))block {
    
    BOOL recreateDispatchSource = NO;
    NSMutableSet *eventSet = [[NSMutableSet alloc] initWithCapacity:7];
    if (eventTypes & DISPATCH_VNODE_ATTRIB)
    {
        [eventSet addObject:@(NUDirectoryChangeEventMeta)];
    }
    if (eventTypes & DISPATCH_VNODE_DELETE)
    {
        [eventSet addObject:@(NUDirectoryChangeEventDelete)];
        recreateDispatchSource = YES;
    }
    if (eventTypes & DISPATCH_VNODE_EXTEND)
    {
        [eventSet addObject:@(NUDirectoryChangeEventSizeChange)];
    }
    if (eventTypes & DISPATCH_VNODE_LINK)
    {
        [eventSet addObject:@(NUDirectoryChangeEventLinkCount)];
    }
    if (eventTypes & DISPATCH_VNODE_RENAME)
    {
        [eventSet addObject:@(NUDirectoryChangeEventRename)];
        recreateDispatchSource = YES;
    }
    if (eventTypes & DISPATCH_VNODE_REVOKE)
    {
        [eventSet addObject:@(NUDirectoryChangeEventRevoked)];
    }
    if (eventTypes & DISPATCH_VNODE_WRITE)
    {
        [eventSet addObject:@(NUDirectoryChangeEventModify)];
    }
    
    for (NSNumber *eventValue in eventSet) {
        NUDirectoryChangeEvent event = eventValue.integerValue;
        if (!(eventTypes & event) ) {
            continue;
        }
        !block ?: block(event);
    }
}

- (NSURLResourceKey)keyForCacheStrategy:(NUDirectoryCleanStrategy)strategy {
    switch (strategy) {
        case NUDirectoryCleanFIFO:
            return  NSURLContentModificationDateKey;
        case NUDirectoryCleanLRU:
            return NSURLContentAccessDateKey;
    }
    
    return NSURLContentModificationDateKey;
}

+ (NSTimeInterval)lasMonitorDirectoryCacheTimeSince1970AtPath:(NSString *)path {
    return [[[NSUserDefaults standardUserDefaults] valueForKey:path] doubleValue];
}

+ (void)setMonitorDirectoryCacheTimeSince1970AtPath:(NSString *)path {
    [[NSUserDefaults standardUserDefaults] setValue:@([[NSDate date] timeIntervalSince1970]) forKey:path];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


@end

@implementation NUDirectorMonitorModel
+ (instancetype)modelWithPath:(NSString *)path source:(dispatch_source_t)source config:(NUDirectoryCacheConfig *)config {
    
    NUDirectorMonitorModel *model = [[NUDirectorMonitorModel alloc] init];
    model.path = path;
    model.source = source;
    model.config = config;
    
    return model;
}
@end
