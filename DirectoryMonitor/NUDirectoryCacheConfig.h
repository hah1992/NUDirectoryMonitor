//
//  NUDirectoryCacheConfig.h
//
//
//  Created by nuclear on 2018/10/26.
//  Copyright © 2018年 nuclear. All rights reserved.
//

#import <Foundation/Foundation.h>

// 文件最大个数：5000
extern NSUInteger const NUDirectoryLimiteFileCount;
// 文件缓存size：500M
extern NSUInteger const NUDirectoryLimiteCachleSize;
// 文件过期时间：7天
extern NSTimeInterval const NUDirectoryMaxCacheAge;
// 两次监测时间间隔：1天
extern NSTimeInterval const NUDirectoryMonitorTimeInterval;

typedef NS_ENUM(NSInteger, NUDirectoryCleanStrategy) {
    NUDirectoryCleanFIFO, // First In First Ou，按照文件创建时间清除缓存
    NUDirectoryCleanLRU,  // Least Recently Used, 最近较少使用
    // TODO: 添加淘汰逻辑
//    NUDirectoryCleanLFU,  // Least Frequently Used, 最少使用
};

/*!
 * 文件变化事件
 *
 * @typedef dispatch_source_vnode_flags_t
 * Type of dispatch_source_vnode flags
 *
 * @constant DISPATCH_VNODE_DELETE
 * The filesystem object was deleted from the namespace.
 *
 * @constant DISPATCH_VNODE_WRITE
 * The filesystem object data changed.
 *
 * @constant DISPATCH_VNODE_EXTEND
 * The filesystem object changed in size.
 *
 * @constant DISPATCH_VNODE_ATTRIB
 * The filesystem object metadata changed.
 *
 * @constant DISPATCH_VNODE_LINK
 * The filesystem object link count changed.
 *
 * @constant DISPATCH_VNODE_RENAME
 * The filesystem object was renamed in the namespace.
 *
 * @constant DISPATCH_VNODE_REVOKE
 * The filesystem object was revoked.
 *
 * @constant DISPATCH_VNODE_FUNLOCK
 * The filesystem object was unlocked.
 */
typedef NS_OPTIONS(NSInteger, NUDirectoryChangeEvent) {
    NUDirectoryChangeEventDelete = DISPATCH_VNODE_DELETE,
    NUDirectoryChangeEventModify = DISPATCH_VNODE_WRITE,
    NUDirectoryChangeEventSizeChange = DISPATCH_VNODE_EXTEND,
    NUDirectoryChangeEventMeta = DISPATCH_VNODE_ATTRIB,
    NUDirectoryChangeEventRename = DISPATCH_VNODE_RENAME,
    NUDirectoryChangeEventLinkCount = DISPATCH_VNODE_LINK,
    NUDirectoryChangeEventRevoked = DISPATCH_VNODE_REVOKE,
    NUDirectoryChangeEventUnlocked = DISPATCH_VNODE_FUNLOCK
};

@interface NUDirectoryCacheConfig : NSObject
// 监听的变化事件
@property(nonatomic, assign) NUDirectoryChangeEvent changeEvent;
// 缓存淘汰策略
@property(nonatomic, assign) NUDirectoryCleanStrategy cleanStrategy;
// 最大缓存size, 单位：byte
@property(nonatomic, assign) NSUInteger limiteCacheSize;
// 最大缓存格式, 单位：个
@property(nonatomic, assign) NSUInteger limiteFileCount;
// 缓存超时时间，单位：s
@property(nonatomic, assign) NSTimeInterval cacheAge;
// 两次监测的时间间隔，单位：s
@property(nonatomic, assign) NSTimeInterval monitorTimeInterval;
// 待删除url过滤器
@property(nonatomic, copy) BOOL (^filter)(NSURL *url);
@end
