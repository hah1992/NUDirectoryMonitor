//
//  NUDirectoryCacheConfig.m
//
//
//  Created by Huang,Anhua on 2018/10/26.
//  Copyright © 2018年 nuclear. All rights reserved.
//

#import "NUDirectoryCacheConfig.h"

NSUInteger const NUDirectoryLimiteFileCount = 5000;
NSUInteger const NUDirectoryLimiteCachleSize = 1024*1024*500;
NSTimeInterval const NUDirectoryMaxCacheAge = 60*60*24*7;
NSTimeInterval const NUDirectoryMonitorTimeInterval = 60*60*24;

@implementation NUDirectoryCacheConfig

@end
