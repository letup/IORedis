//
//  BinaryParser.m
//  
//
//  Created by Blankwonder on 6/14/15.
//
//

#import "ResponseBinaryParser.h"
#import "IORedis.h"

static BOOL IsResponseBinaryCompletedIterate(NSArray *lines, NSInteger* lineIndex)  {
    if ( *lineIndex >= lines.count) return NO;
    NSData *first = lines[*lineIndex];
    const char *bytes = first.bytes;
    
    (*lineIndex)++;
    
    switch (bytes[0]) {
        case '+': return YES;
        case '-': return YES;
        case ':': return YES;
        case '$': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            long long length = [str longLongValue];
            
            if (length == -1) return YES;
            
            if ( *lineIndex >= lines.count) return NO;
            (*lineIndex)++;
            
            return YES;
        }
        case '*': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            long long length = [str longLongValue];
            
            if (length == -1) return YES;
            
            for (int i = 0; i < length; i++) {
                BOOL result = IsResponseBinaryCompletedIterate(lines, lineIndex);
                if (!result) return NO;
            }
            
            return YES;
        }
        default: {
            NSLog(@"Unknown line: %@", first);
            return NO;
        }
    }
}

extern BOOL IsResponseBinaryCompleted(NSArray *lines) {
    NSInteger lineIndex = 0;
    return IsResponseBinaryCompletedIterate(lines, &lineIndex);
}


static id ParseResponseBinaryIterate(NSArray *lines, NSStringEncoding stringEncoding, NSInteger* lineIndex){
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
            
            if (stringEncoding == 0) {
                return second;
            } else {
                return [[NSString alloc] initWithData:second encoding:stringEncoding];
            }
        }
            break;
        case '*': {
            NSData *data = [first subdataWithRange:NSMakeRange(1, first.length - 1)];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            long long length = [str longLongValue];
            
            if (length == -1) return [NSNull null];
            
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:length];
            for (int i = 0; i < length; i++) {
                id result = ParseResponseBinaryIterate(lines, stringEncoding, lineIndex);
                if (!result) {
                    return nil;
                }
                [array addObject:result];
            }
            
            return array;
        }
            break;
        default: {
            NSLog(@"Unknown line: %@", first);
            return nil;
        }
            break;
    }
}

extern id ParseResponseBinary(NSMutableArray *lines, NSStringEncoding stringEncoding) {
    NSInteger lineIndex = 0;
    id result = ParseResponseBinaryIterate(lines, stringEncoding, &lineIndex);
    
    if (result) {
        [lines removeObjectsInRange:NSMakeRange(0, lineIndex)];
    }
    
    return result;
}
