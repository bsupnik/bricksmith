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
	[colorIn retain];
	[self->backgroundColor release];
	
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


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Turning a shade of blue.
//
//==============================================================================
- (void) dealloc
{
	[self->backgroundColor release];

	[super dealloc];
	
}//end dealloc

@end
