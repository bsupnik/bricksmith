//==============================================================================
//
// File:		FocusRingView.h
//
// Purpose:		This is a view which draws a focus ring inside the border of its 
//				visible area. 
//
// Modified:	11/7/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


////////////////////////////////////////////////////////////////////////////////
//
// class FocusRingView
//
////////////////////////////////////////////////////////////////////////////////
@interface FocusRingView : NSView
{
	NSView	*focusSource;	// the view which, if in focus, prompts us to draw a focus ring.
}

- (void) setFocusSource:(NSView *)newObject;

@end
