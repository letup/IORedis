//
//  Redis.m
//  Redis
//
//  Created by Blankwonder on 6/12/15.
//  Copyright (c) 2015 Yach. All rights reserved.
//

#import "IORedis.h"
#import "GCDAsyncSocket.h"
#import "ResponseBinaryParser.h"
#import "RequestBinaryParser.h"
#import "Utilites.h"

NSString * const IORedisServerErrorDomain = @"IORedisServerErrorDomain";
NSString * const IORedisServerErrorMessageKey = @"IORedisServerErrorMessageKey";

@interface IORedisOperation : NSObject
@property (copy) IORedisSuccessBlock success;
@property (copy) IORedisFailureBlock failure;
@property NSStringEncoding stringEncoding;
@end


@interface IORedis () <GCDAsyncSocketDelegate>
@end

@implementation IORedis {
    GCDAsyncSocket *_socket;
    dispatch_queue_t _dispatch_queue;
    
    NSMutableArray *_operationQueue;
    NSMutableData *_readBuffer;
    
    NSMutableArray *_lines;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatch_queue = dispatch_queue_create("IORedis", NULL);
        _operationQueue = [NSMutableArray array];
        _lines = [NSMutableArray array];
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_dispatch_queue];
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)host port:(uint16_t)port error:(NSError **)error {
    return [_socket connectToHost:host onPort:port error:error];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if ([self.delegate respondsToSelector:@selector(redisClient:didConnectToHost:port:)]) {
        [self.delegate redisClient:self didConnectToHost:host port:port];
    }
    [_socket readDataWithTimeout:-1 tag:0];
}

- (void)disconnect {
    [_socket disconnect];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if ([self.delegate respondsToSelector:@selector(redisClientDidDisconnect:withError:)]) {
        [self.delegate redisClientDidDisconnect:self withError:err];
    }
}

- (void)executeCommand:(NSString *)command
            parameters:(NSArray *)parameters
        stringEncoding:(NSStringEncoding)stringEncoding
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure {
    dispatch_async(_dispatch_queue, ^{
        
        NSMutableArray *bulk = [NSMutableArray arrayWithObject:[command dataUsingEncoding:NSASCIIStringEncoding]];
        [bulk addObjectsFromArray:parameters];
        NSData *data = PasreRequestArray(bulk, stringEncoding);
        
        [_socket writeData:data withTimeout:60 tag:1];
        
        IORedisOperation *operation = [[IORedisOperation alloc] init];
        operation.success = success;
        operation.failure = failure;
        operation.stringEncoding = stringEncoding;
        
        [_operationQueue addObject:operation];
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (!_readBuffer) {
        _readBuffer = [NSMutableData data];
    }
    [_readBuffer appendData:data];
    
    NSUInteger offset = 0;
    while (offset < _readBuffer.length) {
        NSUInteger newOffset = [_readBuffer rangeOfData:[Utilites CRLFData]
                                                options:0
                                                  range:NSMakeRange(offset, _readBuffer.length - offset)].location;
        
        if (newOffset == NSNotFound) {
            break;
        } else {
            [_lines addObject:[_readBuffer subdataWithRange:NSMakeRange(offset, newOffset - offset)]];
            offset = newOffset + [Utilites CRLFData].length;
        }
    }
    
    if (offset == 0) {
    } else if (offset >= _readBuffer.length) {
        NSAssert(offset == _readBuffer.length, @"");
        _readBuffer = nil;
    } else {
        _readBuffer = [[_readBuffer subdataWithRange:NSMakeRange(offset, _readBuffer.length - offset)] mutableCopy];
    }
    
    id result;
    while (_lines.count > 0 && IsResponseBinaryCompleted(_lines)) {
        IORedisOperation *operation = _operationQueue.firstObject;
        result = ParseResponseBinary(_lines, operation.stringEncoding);
        if (result) {
            if ([result isKindOfClass:[NSError class]]) {
                operation.failure(result);
            } else {
                operation.success(result);
            }
            [_operationQueue removeObjectAtIndex:0];
        }
    }
    
    [_socket readDataWithTimeout:-1 tag:0];
}

- (void)executeCommand:(NSString *)command
            parameters:(NSArray *)parameters
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure {
    [self executeCommand:command parameters:parameters stringEncoding:0 success:success failure:failure];
}

- (void)executeCommand:(NSString *)command
               success:(IORedisSuccessBlock)success
               failure:(IORedisFailureBlock)failure {
    [self executeCommand:command parameters:nil success:success failure:failure];
}

@end

@implementation IORedisOperation

@end
