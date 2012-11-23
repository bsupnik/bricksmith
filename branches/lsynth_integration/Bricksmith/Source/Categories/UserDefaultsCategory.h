//==============================================================================
//
// Category: UserDefaultsCategory.h
//
//		Convenient window utility methods.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>


@interface NSUserDefaults (UserDefaultsCategory)

- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey;
- (NSColor *)colorForKey:(NSString *)aKey;

@end
