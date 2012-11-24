//==============================================================================
//
// Category: UserDefaultsCategory.m
//
//		Allows storing certain objects that otherwise cannot be stored directly.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "UserDefaultsCategory.h"


@implementation NSUserDefaults (UserDefaultsCategory)

//========== setColor:forKey: ==================================================
//
// Purpose:		Saves a color into UserDefaults.
//
//==============================================================================
- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey
{
    NSData	*theData = [NSArchiver archivedDataWithRootObject:aColor];
	
    [self setObject:theData forKey:aKey];
	
}//end setColor:forKey:


//========== colorForKey: ======================================================
//
// Purpose:		Retrieves a color stored in UserDefaults.
//
//==============================================================================
- (NSColor *)colorForKey:(NSString *)aKey

{
	NSColor	*theColor	= nil;
    NSData	*theData	= [self dataForKey:aKey];
	
    if (theData != nil)
        theColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
	
    return theColor;
	
}//end colorForKey:


@end
