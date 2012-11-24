//==============================================================================
//
// File:		BezierPathCategory.m
//
// Purpose:		Handy Bezier path methods Apple forgot.
//
//  Created by Allen Smith on 6/11/07.
//  Copyright 2007. All rights reserved.
//==============================================================================
#import "BezierPathCategory.h"


@implementation NSBezierPath (BezierPathCategory)

//---------- bezierPathWithRect:radiusPercentage: --------------------[static]--
//
// Purpose:		Creates a beautiful Round Rect. It's as fun as MacPaint!
//
// Parameters:	rect				- bounds in which the round rect is 
//									  inscribed
//				radiusPercentage	- percentage (0-100) of the width of the 
//									  bounds which should be rounded. Passing 
//									  100 will cause the top and bottom to 
//									  become semicircles. 
//
//------------------------------------------------------------------------------
+ (NSBezierPath *) bezierPathWithRect:(NSRect)rect
					 radiusPercentage:(CGFloat)radiusPercentage
{
	NSBezierPath	*roundRect		= [NSBezierPath bezierPath];
	CGFloat			radius			= NSWidth(rect)/2 * (radiusPercentage/100);
	
	//start with a blank path.
	
	// start above the lower left corner, drawing counter-clockwise
	[roundRect moveToPoint:  NSMakePoint(NSMinX(rect),			NSMinY(rect) + radius	)];
	
	//Bottom left corner
	[roundRect appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect),			NSMinY(rect))
										toPoint:NSMakePoint(NSMinX(rect) + radius,	NSMinY(rect))
										 radius:radius];
	//Bottom side
	[roundRect lineToPoint:  NSMakePoint(NSMaxX(rect) - radius, NSMinY(rect)			)];
	
	
	//Bottom Right Corner
	[roundRect appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect),			NSMinY(rect))
										toPoint:NSMakePoint(NSMaxX(rect),			NSMinY(rect) + radius)
										 radius:radius];
	//Right side
	[roundRect lineToPoint:  NSMakePoint(NSMaxX(rect),			NSMaxY(rect) - radius   )];
	
	
	//Top right corner
	[roundRect appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect),			NSMaxY(rect))
										toPoint:NSMakePoint(NSMaxX(rect) - radius,	NSMaxY(rect))
										 radius:radius];
	//Top side
	[roundRect lineToPoint:  NSMakePoint(NSMinX(rect) + radius, NSMaxY(rect)			)];
	
	
	//Top left corner
	[roundRect appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect),			NSMaxY(rect))
										toPoint:NSMakePoint(NSMinX(rect),			NSMaxY(rect) - radius)
										 radius:radius];
	//Left side
	//[roundRect lineToPoint:  NSMakePoint(NSMinX(rect),			NSMinY(rect) + radius   )];
	[roundRect closePath];
	
	return roundRect;
	
}//end bezierPathWithRect:radiusPercentage:




@end
