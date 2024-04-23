//==============================================================================
//
// File:		BackgroundColorView.h
//
// Purpose:		A view which paints a background color.
//
// Modified:	07/23/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "BackgroundColorView.h"


@implementation BackgroundColorView

//========== initWithFrame: ====================================================
//
// Purpose:		
//
//==============================================================================
- (id) initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code here.
    }
	
    return self;
	
}//end initWithFrame:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== setBackgroundColor: ===============================================
//
// Purpose:		Sets the color to draw on the view.
//
//==============================================================================
- (void) setBackgroundColor:(NSColor *)colorIn
{
	self->backgroundColor = colorIn;
	
}//end setBackgroundColor:


//========== drawRect: =========================================================
//
// Purpose:		Paint the colors.
//
//==============================================================================
- (void)drawRect:(NSRect)rect
{
	[self->backgroundColor set];
	NSRectFill(rect);
	
}//end drawRect:


@end
