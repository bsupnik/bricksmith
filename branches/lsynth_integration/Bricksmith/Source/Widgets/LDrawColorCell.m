//==============================================================================
//
// File:		LDrawColorCell.m
//
// Purpose:		Displays a swatch of an LDraw color in a cell.
//
//  Created by Allen Smith on 2/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawColorCell.h"

#import "ColorLibrary.h"
#import "LDrawColor.h"

@implementation LDrawColorCell

//========== drawInteriorWithFrame:inView: =====================================
//
// Purpose:		Draw a swatch representing the current color without alpha.
//
//==============================================================================
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	LDrawColor  *colorObject    = [self objectValue];
	NSColor     *cellColor      = nil;
	GLfloat     components[4];
	
	// Get the color components and covert them. Discard alpha.
	[colorObject getColorRGBA:components];
	cellColor = [NSColor colorWithCalibratedRed:components[0]
										  green:components[1]
										   blue:components[2]
										  alpha:1.0 ];
	
	// Draw
	[cellColor set];
	NSRectFillUsingOperation(cellFrame, NSCompositeSourceOver);
	
}//end drawInteriorWithFrame:inView:

@end
