//
//  Utilites.m
//  
//
//  Created by Blankwonder on 6/14/15.
//
//

#import "Utilites.h"

@implementation Utilites

static NSData *kCRLFData;
+ (void)load {
    kCRLFData = [NSData dataWithBytes:"\r\n" length:2];
}

+ (NSData *)CRLFData {
    return kCRLFData;
}

@end
