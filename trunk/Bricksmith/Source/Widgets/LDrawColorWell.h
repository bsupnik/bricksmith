//==============================================================================
//
// File:		LDrawColorWell.h
//
// Purpose:		Provides a means of choosing an LDraw color for an element.
//
//  Created by Allen Smith on 2/27/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ColorLibrary.h"

////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawColorWell
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawColorWell : NSButton <LDrawColorable>
{
	LDrawColor  *color;
	NSColor     *nsColor;
}

//Active color well
+ (LDrawColorWell *) activeColorWell;
+ (void) setActiveColorWell:(LDrawColorWell *)newWell;

//Actions
- (void) changeLDrawColorWell:(id)sender;

@end
