//
//  NUDirectoryMonitor.h
//
//
//  Created by Huang,Anhua on 2018/10/26.
//  Copyright © 2018年 nuclear. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NUDirectoryCacheConfig.h"

@interface NUDirectoryMonitor : NSObject


/**
 开始文件夹监测

 @param path 文件夹路径
 @param config 缓存配置
 @param block 当文件夹发生变化时的回调
 */
+ (void)startMonitorDirectoryAtPath:(NSString *)path
                   usingCacheConfig:(NUDirectoryCacheConfig *)config
                        changeBlock:(void (^)(NUDirectoryChangeEvent events))block;

+ (void)stopMonitorDirectoryAtPath:(NSString *)path;

@end
