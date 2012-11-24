//==============================================================================
//
// File:		BricksmithUtilities.m
//
// Purpose:		Miscellaneous utility methods for the Bricksmith application.
//
// Notes:		Utility methods specific to LDraw syntax, manipulation, or 
//				display or found in LDrawUtilities. 
//
// Modified:	02/07/2011 Allen Smith. Creation Date.
//
//==============================================================================
#import "BricksmithUtilities.h"

#import "BezierPathCategory.h"
#import "MacLDraw.h"


@implementation BricksmithUtilities

//---------- dragImageWithOffset: ------------------------------------[static]--
//
// Purpose:		Returns the image used to denote drag-and-drop of parts. 
//
// Notes:		We don't use this image when dragging rows in the file contents, 
//				just when using physically moving parts within the model. 
//
//------------------------------------------------------------------------------
+ (NSImage *) dragImageWithOffset:(NSPointPointer)dragImageOffset
{
	NSImage	*brickImage			= [NSImage imageNamed:@"Brick"];
	CGFloat	 border				= 3;
	NSSize	 dragImageSize		= NSMakeSize([brickImage size].width + border*2, [brickImage size].height + border*2);
	NSImage	*dragImage			= [[NSImage alloc] initWithSize:dragImageSize];
	NSImage *arrowCursorImage	= [[NSCursor arrowCursor] image];
	NSSize	 arrowSize			= [arrowCursorImage size];
	
	[dragImage lockFocus];
	
	[[NSColor colorWithDeviceWhite:0.6 alpha:0.75] set];
	[[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, dragImageSize.width,dragImageSize.height) radiusPercentage:50.0] fill];
	
	[brickImage drawAtPoint:NSMakePoint(border, border) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	[dragImage unlockFocus];
	
	if(dragImageOffset != NULL)
	{
		// Now provide an offset to move the image over so it looks like a badge 
		// next to the cursor: 
		//   ...Turns out the arrow cursor image is a 24 x 24 picture, and the 
		//   arrow itself occupies only a small part of the lefthand side of 
		//   that space. We have to resort to a hardcoded assumption that the 
		//   actual arrow picture fills only half the full image. 
		//   ...We subtract from y; that is the natural direction for a lowering 
		//   offset. In a flipped view, negate that value.  
		(*dragImageOffset).x +=  arrowSize.width/2;
		(*dragImageOffset).y -= (arrowSize.height/2 + [dragImage size].height/2);
	}
	
	return [dragImage autorelease];
	
}//end dragImageWithOffset:


//---------- gridSpacingForMode: -------------------------------------[static]--
//
// Purpose:		Translates the given grid spacing granularity into an actual 
//				number of LDraw units, according to the user's preferences. 
//
// Notes:		This value represents distances "along the studs"--that is, 
//			    horizontal along the brick. Vertical distances may be adjusted. 
//
//------------------------------------------------------------------------------
+ (float) gridSpacingForMode:(gridSpacingModeT)gridMode
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	float			 gridSpacing	= 0.0;
	
	switch(gridMode)
	{
		case gridModeFine:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_FINE];
			break;
			
		case gridModeMedium:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_MEDIUM];
			break;
			
		case gridModeCoarse:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_COARSE];
			break;
	}
	
	return gridSpacing;
	
}//end gridSpacingForMode:


@end
