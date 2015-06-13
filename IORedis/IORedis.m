//
//  Redis.m
//  Redis
//
//  Created by Blankwonder on 6/12/15.
//  Copyright (c) 2015 Yach. All rights reserved.
//

#import "IORedis.h"
#import "GCDAsyncSocket.h"

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

static NSData *kCRLFData;
+ (void)load {
    kCRLFData = [NSData dataWithBytes:"\r\n" length:2];
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

        NSMutableData *data = [NSMutableData data];
        NSArray *lines = [self parameterDataWithObject:bulk stringEncoding:stringEncoding];
        
        [self buildDataFromArray:lines mutableData:data];
        
        [_socket writeData:data withTimeout:60 tag:1];
        
        IORedisOperation *operation = [[IORedisOperation alloc] init];
        operation.success = success;
        operation.failure = failure;
        operation.stringEncoding = stringEncoding;
        
        [_operationQueue addObject:operation];
    });
}

- (NSArray *)parameterDataWithObject:(id)obj stringEncoding:(NSStringEncoding)stringEncoding{
    if ([obj isKindOfClass:[NSData class]]) {
        NSData *lengthData = [[NSString stringWithFormat:@"$%lu", (unsigned long)[obj length]] dataUsingEncoding:NSASCIIStringEncoding];
        return @[lengthData, obj];
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        NSString *str = [NSString stringWithFormat:@":%lld", [(NSNumber *)obj longLongValue]];
        NSData *data = [str dataUsingEncoding:NSASCIIStringEncoding];
        
        return @[data];
    } else if (obj == [NSNull null]) {
        return @[[@"$-1" dataUsingEncoding:NSASCIIStringEncoding]];
    } else if ([obj isKindOfClass:[NSString class]]) {
        if (stringEncoding == 0) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"NSString in parameters but string encoding disabled"];
            return nil;
        } else {
            NSData *data = [(NSString *)obj dataUsingEncoding:stringEncoding];
            NSData *lengthData = [[NSString stringWithFormat:@"$%lu", (unsigned long)data.length] dataUsingEncoding:NSASCIIStringEncoding];
            
            return @[lengthData, data];
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        [array addObject:[[NSString stringWithFormat:@"*%lu", (unsigned long)[obj count]] dataUsingEncoding:NSASCIIStringEncoding]];
        
        for (id subobj in obj) {
            [array addObject:[self parameterDataWithObject:subobj stringEncoding:stringEncoding]];
        }
        return array;
    }
    
    [NSException raise:NSInternalInconsistencyException
                format:@"Unknown parameters type found: %@", NSStringFromClass([obj class])];
    return nil;
}

- (void)buildDataFromArray:(NSArray *)array mutableData:(NSMutableData *)data {
    for (id obj in array) {
        if ([obj isKindOfClass:[NSData class]]) {
            [data appendData:obj];
            [data appendData:kCRLFData];
        } else {
            [self buildDataFromArray:obj mutableData:data];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (!_readBuffer) {
        _readBuffer = [NSMutableData data];
    }
    [_readBuffer appendData:data];
    
    NSUInteger offset = 0;
    while (offset < _readBuffer.length) {
        NSUInteger newOffset = [_readBuffer rangeOfData:kCRLFData
                                                options:0
                                                  range:NSMakeRange(offset, _readBuffer.length - offset)].location;
        
        if (newOffset == NSNotFound) {
            break;
        } else {
            [_lines addObject:[_readBuffer subdataWithRange:NSMakeRange(offset, newOffset - offset)]];
            offset = newOffset + kCRLFData.length;
        }
    }
    if (offset >= _readBuffer.length) {
        NSAssert(offset == _readBuffer.length, @"");
        _readBuffer = nil;
    } else {
        _readBuffer = [[_readBuffer subdataWithRange:NSMakeRange(offset, _readBuffer.length - offset)] mutableCopy];
    }
    
    id result;
    do {
        IORedisOperation *operation = _operationQueue.firstObject;
        result = [self readBufferResultWithStringEncoding:operation.stringEncoding];
        if (result) {
            if ([result isKindOfClass:[NSError class]]) {
                operation.failure(result);
            } else {
                operation.success(result);
            }
            [_operationQueue removeObjectAtIndex:0];
        }
    } while (result && _lines.count > 0);
    
    [_socket readDataWithTimeout:-1 tag:0];
}

- (id)readBufferResultWithStringEncoding:(NSStringEncoding)stringEncoding{
    NSInteger lineIndex = 0;
    id result = [self parseResultWithLines:_lines lineIndex:&lineIndex stringEncoding:stringEncoding];
    
    if (result) {
        [_lines removeObjectsInRange:NSMakeRange(0, lineIndex)];
    }
    
    return result;
}

- (id)parseResultWithLines:(NSArray *)lines lineIndex:(NSInteger *)lineIndex stringEncoding:(NSStringEncoding)stringEncoding{
    if ( *lineIndex >= lines.count) return nil;
    NSData *first = lines[*lineIndex];
    const char *bytes = first.bytes;
    
    (*lineIndex)++;
    
    switch (bytes[0]) {
        case '+': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            if (stringEncoding == 0) {
                return data;
            } else {
                return [[NSString alloc] initWithData:data encoding:stringEncoding];
            }
        }
            break;
        case '-': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            
            NSError *error = [NSError errorWithDomain:IORedisServerErrorDomain
                                                 code:0
                                             userInfo:@{IORedisServerErrorMessageKey: [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]}];
            
            return error;
        }
            break;
        case ':': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            return [NSNumber numberWithInteger:str.integerValue];
        }
            break;
        case '$': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            long long length = [str longLongValue];
            
            if (length == -1) return [NSNull null];
            
            if ( *lineIndex >= lines.count) return nil;
            NSData *second = lines[*lineIndex];
            (*lineIndex)++;

            if (second.length != length)  return nil;
            
            if (stringEncoding == 0) {
                return second;
            } else {
                return [[NSString alloc] initWithData:second encoding:stringEncoding];
            }
        }
        case '*': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            long long length = [str longLongValue];
            
            if (length == -1) return [NSNull null];

            NSMutableArray *array = [NSMutableArray arrayWithCapacity:length];
            for (int i = 0; i < length; i++) {
                id result = [self parseResultWithLines:lines lineIndex:lineIndex stringEncoding:stringEncoding];
                if (!result) {
                    return nil;
                }
                [array addObject:result];
            }
            
            return array;
        }
            
        default: {
            NSLog(@"Unknown line: %@", first);
            return nil;
        }
            break;
    }
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
