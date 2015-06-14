//
//  RequestBinaryParser.m
//  
//
//  Created by Blankwonder on 6/14/15.
//
//

#import "RequestBinaryParser.h"
#import "Utilites.h"

static NSArray *PasreRequestObjectToLinesIterate(id obj, NSStringEncoding stringEncoding){
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
            [array addObject:PasreRequestObjectToLinesIterate(subobj, stringEncoding)];
        }
        return array;
    }
    
    [NSException raise:NSInternalInconsistencyException
                format:@"Unknown parameters type found: %@", NSStringFromClass([obj class])];
    return nil;
}

static void BuildDataFromLines(NSArray *array, NSMutableData *data) {
    for (id obj in array) {
        if ([obj isKindOfClass:[NSData class]]) {
            [data appendData:obj];
            [data appendData:[Utilites CRLFData]];
        } else {
            BuildDataFromLines(obj, data);
        }
    }
}


extern NSData *PasreRequestArray(NSArray *array, NSStringEncoding stringEncoding) {
    NSArray *lines = PasreRequestObjectToLinesIterate(array, stringEncoding);
    
    NSMutableData *data = [NSMutableData data];
    BuildDataFromLines(lines, data);

    return data;
}