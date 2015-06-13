//
//  Redis.h
//  Redis
//
//  Created by Blankwonder on 6/12/15.
//  Copyright (c) 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^IORedisSuccessBlock)(id result); // NSString, NSNumber, NSNull, NSArray
typedef void(^IORedisFailureBlock)(NSError *error);

extern NSString * const IORedisServerErrorDomain;
extern NSString * const IORedisServerErrorMessageKey;

@protocol IORedisDelegate;

@interface IORedis : NSObject

- (BOOL)connectToHost:(NSString *)host port:(uint16_t)port error:(NSError **)error;
- (void)disconnect;

- (void)executeCommand:(NSString *)command
            parameters:(NSArray *)parameters
        stringEncoding:(NSStringEncoding)stringEncoding
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure;

- (void)executeCommand:(NSString *)command
            parameters:(NSArray *)parameters
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure;

- (void)executeCommand:(NSString *)command
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure;

@property (weak) id <IORedisDelegate> delegate;

@end

@protocol IORedisDelegate <NSObject>

@optional
- (void)redisClient:(IORedis *)client didConnectToHost:(NSString *)host port:(uint16_t)port;
- (void)redisClientDidDisconnect:(IORedis *)client withError:(NSError *)err;

@end
