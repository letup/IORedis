//
//  AppDelegate.m
//  IORedis Test
//
//  Created by Blankwonder on 6/13/15.
//  Copyright (c) 2015 Yach. All rights reserved.
//

#import "AppDelegate.h"
#import "IORedis.h"

@interface AppDelegate () <IORedisDelegate> {
    IORedis *_redis;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _redis = [[IORedis alloc] init];
    _redis.delegate = self;
    [_redis connectToHost:@"127.0.0.1" port:6379 error:nil];
}

- (void)redisClient:(IORedis *)client didConnectToHost:(NSString *)host port:(uint16_t)port {
    [client executeCommand:@"GET" parameters:@[@"foo"] stringEncoding:NSUTF8StringEncoding success:^(id result) {
        NSLog(@"%@", result);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
    [client executeCommand:@"GET" parameters:@[@"foo"] stringEncoding:NSUTF8StringEncoding success:^(id result) {
        NSLog(@"%@", result);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
    [client executeCommand:@"GET" parameters:@[@"foo"] stringEncoding:NSUTF8StringEncoding success:^(id result) {
        NSLog(@"%@", result);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
    [client executeCommand:@"GET" parameters:@[@"foo"] stringEncoding:NSUTF8StringEncoding success:^(id result) {
        NSLog(@"%@", result);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
    [client executeCommand:@"GET" parameters:@[@"foo"] stringEncoding:NSUTF8StringEncoding success:^(id result) {
        NSLog(@"%@", result);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
}

- (void)redisClientDidDisconnect:(IORedis *)client withError:(NSError *)err {
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
