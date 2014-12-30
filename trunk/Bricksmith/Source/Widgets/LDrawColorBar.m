//==============================================================================
//
// File:		LDrawColorBar.h
//
// Purpose:		Color view used to display an LDraw color. It's just a big 
//				rectangle; that's it. You can view the one and only specimen of 
//				this widget in the LDrawColorPanelController (the big thing at 
//				the top). 
//
//  Created by Allen Smith on 2/27/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawColorBar.h"

#import "LDrawColor.h"

@implementation LDrawColorBar


//========== drawRect: =========================================================
//
// Purpose:		Paints the represented color inside the bar, along with a small 
//				border.
//
//==============================================================================
- (void) drawRect:(NSRect)aRect
{
	[super drawRect:aRect]; //does nothing.
	
//	NSBezierPath *rectPath = [NSBezierPath bezierPathWithRect:aRect];
//	[rectPath stroke];
	
	[[NSColor grayColor] set];
	NSRectFill(aRect);
	
	[[NSColor whiteColor] set];
	NSRectFill(NSInsetRect(aRect, 1, 1));
	
	//We can let the OS do it, but I'm not going to. Basically, it's because 
	// their display of transparent colors is mind-bogglingly ugly.
	// You also get a little triangle in the corner when using device colors,
	// which I am for no apparent reason.
//	[self->nsColor drawSwatchInRect:NSInsetRect(aRect, 2, 2)];
	[self->nsColor set];
	NSRectFill(NSInsetRect(aRect, 2, 2));
	
}//end drawRect:

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code represented by this button.
//
//==============================================================================
- (LDrawColor *) LDrawColor
{
	return color;
	
}//end LDrawColor


//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the LDraw color code of the receiver to newColorCode and 
//				redraws the receiever.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *) newColor
{
	NSString    *description    = nil;
	GLfloat     components[4];
	
	// assign ivar
	[newColor retain];
	[self->color release];
	self->color = newColor;
	
	// Set cached NSColor too
	[newColor getColorRGBA:components];
	
	[self->nsColor release];
	self->nsColor = [[NSColor colorWithCalibratedRed:components[0]
											   green:components[1]
												blue:components[2]
											   alpha:1.0 ] retain];
	
	//Create a tool tip to identify the LDraw color code.
	description	= [newColor localizedName];
	[self setToolTip:[NSString stringWithFormat:@"LDraw %d\n%@", [newColor colorCode], description]];
	
	[self setNeedsDisplay:YES];
	
}//end setLDrawColor:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Entering the long dark night.
//
//==============================================================================
- (void) dealloc
{
	[self->nsColor	release];
	
	[super dealloc];
	
}//end dealloc


@end
