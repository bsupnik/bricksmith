//==============================================================================
//
// File:		StringCategory.h
//
// Purpose:		Handy string utilities.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>


@interface NSString (StringCategory)

- (BOOL) containsString:(NSString *)substring options:(NSUInteger)mask;
+ (NSString *) CRLF;
- (NSComparisonResult)numericCompare:(NSString *)string;
- (NSArray *) separateByLine;
- (NSString *) stringByRemovingWhitespace;

@end