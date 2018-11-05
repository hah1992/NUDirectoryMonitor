//
//  ViewController.m
//  DirecytoryMonitor
//
//  Created by Huang,Anhua on 2018/11/2.
//  Copyright © 2018年 nuclear. All rights reserved.
//

#import "ViewController.h"
#import "NUDirectoryMonitor.h"

@interface ViewController ()
@property(nonatomic, copy) NSString *path;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NUDirectoryCacheConfig *config = [[NUDirectoryCacheConfig alloc] init];
    config.limiteCacheSize = 1024*150;
    config.limiteFileCount = 5;
    config.cacheAge = 60000;
    config.cleanStrategy = NUDirectoryCleanFIFO;
    
    [NUDirectoryMonitor startMonitorDirectoryAtPath:_path
                                       usingCacheConfig:config
                                           changeBlock:^(NUDirectoryChangeEvent events) {
                                               NSLog(@"NU cache monitor: %ld", events);
                                           }];
}


static NSInteger i = 0;

- (IBAction)create:(id)sender {
    UIImage *img = [UIImage imageNamed:@"chat_send_btn"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    [UIImagePNGRepresentation(img) writeToFile:[_path stringByAppendingFormat:@"/%ld", i++] atomically:YES];
}

- (IBAction)remove:(id)sender {
    NSError *err;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURLResourceKey cacheContentKey = NSURLContentModificationDateKey;
    NSURL *diskCacheURL = [NSURL fileURLWithPath:_path isDirectory:YES];
    NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, cacheContentKey, NSURLTotalFileAllocatedSizeKey];
    
    NSDirectoryEnumerator *fileEnumerator = [manager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
    for (NSURL *url in fileEnumerator) {
        [manager removeItemAtURL:url error:&err];
        if (err) {
            NSLog(@"remove file error: %@", err);
        }
    }
    
}

@end
