//==============================================================================
//
// File:		FocusRingView.m
//
// Purpose:		This is a view which draws a focus ring inside the border of its 
//				visible area. 
//
//				Why would you want/need such a view?
//
//				It's for non-Cocoa views such as NSOpenGLView. Drawing a focus 
//				ring in OpenGL is a pain!  
//
// Modified:	11/7/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "FocusRingView.h"


@implementation FocusRingView

//========== initWithFrame: ====================================================
//
// Purpose:		Nothing to do here, actually.
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

//========== setFocusSource: ===================================================
//
// Purpose:		Sets the view whose focus state we reflect. 
//
// Notes:		The view is still responsible for telling us when to redisplay!
//
//==============================================================================
- (void) setFocusSource:(NSView *)newObject
{
	self->focusSource = newObject;
}


#pragma mark -
#pragma mark DRAWING
#pragma mark -

//========== drawRect: =========================================================
//
// Purpose:		Draw the focus ring.
//
//==============================================================================
- (void) drawRect:(NSRect)dirtyRect
{
	BOOL inFocus = NO;

	// We have no internal content of our own. We just let someone else's 
	// content shine through underneath us. 
	[[NSColor clearColor] set];
	NSRectFill([self bounds]);
	
	// Is our "content" in focus?
	if(self->focusSource == nil)
	{
		// Use superview as focus source
		if([[self window] firstResponder] == [self superview])
		{
			inFocus = YES;
		}
	}
	else
	{
		// Use specified view as the focus source
		if([[self->focusSource window] firstResponder] == self->focusSource)
		{
			inFocus = YES;
		}
	}

	// Draw the focus ring.
	if(inFocus == YES)
	{
		NSSetFocusRingStyle(NSFocusRingOnly);
		NSRectFill(NSInsetRect([self visibleRect], 2, 2));
	}
	
}//end drawRect:


#pragma mark -
#pragma mark EVENTS
#pragma mark -

//========== hitTest: ==========================================================
//
// Purpose:		This view is supposed to overlay a view which can't draw its own 
//				focus ring, so we want to direct all events through this view to 
//				the one it's covering. 
//
//==============================================================================
- (NSView *) hitTest:(NSPoint)aPoint
{
	return [self superview];
	
}//end hitTest:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Out of focus.
//
//==============================================================================
- (void) dealloc
{
	[super dealloc];
}


@end
