//==============================================================================
//
// File:		ScopeBar.m
//
// Purpose:		Displays a AHIG-compliant scope bar. Scope bars are used to 
//				filter objects by specific criteria, and there is a prescribed 
//				set of controls which may appear in them. Unfortunately, Apple 
//				provided no class for actually drawing the scope bar background 
//				itself, even though it appears to have a standardized 
//				appearance. 
//
//				This class draws the scope bar background and border. It is not 
//				responsible for drawing or managing any content. You should do 
//				that using subviews, probably defined in Interface Builder. 
//
// Notes:		A regular scope bar should be 25 px. high.
//
// Modified:	9/1/08 Allen Smith. Creation date.
//
//==============================================================================
#import "ScopeBar.h"


@implementation ScopeBar

//========== initWithFrame: ====================================================
//
// Purpose:		
//
//==============================================================================
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code here.
    }
    return self;
	
}//end initWithFrame:


//========== drawRect: =========================================================
//
// Purpose:		Draw the scope bar background.
//
// Notes:		These things have a particular appearance, but there seems to be 
//				no API for reproducing it. We must fall back on magic numbers 
//				here. Furthermore, the appearance will be degenerate on Tiger 
//				because I do not feel like pounding out the manual CoreGraphics 
//				calls which NSGradient is using. Sooner or later we will be 
//				dumping Tiger and then none of it will matter! 
//
//==============================================================================
- (void) drawRect:(NSRect)rect
{
	NSColor         *topColor       = [NSColor colorWithCalibratedWhite:0.91 alpha:1.0];
	NSColor         *bottomColor    = [NSColor colorWithCalibratedWhite:0.82 alpha:1.0];
	NSColor         *borderColor    = [NSColor colorWithCalibratedWhite:0.58 alpha:1.0];
	NSRect          bounds          = [self bounds];
	NSBezierPath    *bottomLine     = [NSBezierPath bezierPath];
	NSGradient      *gradient       = [[[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor] autorelease];
	
	[gradient drawInRect:bounds angle:90];
	
	// bottom line border
	[bottomLine moveToPoint:NSMakePoint( NSMinX(bounds) - 0.5, NSMinY(bounds) )];
	[bottomLine lineToPoint:NSMakePoint( NSMaxX(bounds) - 0.5, NSMinY(bounds) )];
	
	[borderColor set];
	[bottomLine stroke];
	
}//end drawRect:

@end
