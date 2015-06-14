//
//  BinaryParser.h
//  
//
//  Created by Blankwonder on 6/14/15.
//
//

#import <Foundation/Foundation.h>

extern BOOL IsResponseBinaryCompleted(NSArray *lines);
extern id ParseResponseBinary(NSArray *lines, NSStringEncoding stringEncoding);