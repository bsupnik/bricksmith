//==============================================================================
//
// File:		OverlayHelperView.h
//
// Purpose:		Manages a "subview" which is painted over a hardware-accelerated 
//				surface such as OpenGL. 
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

@class OverlayHelperWindow;

////////////////////////////////////////////////////////////////////////////////
//
// class OverlayHelperView
//
////////////////////////////////////////////////////////////////////////////////
@interface OverlayHelperView : NSView
{
	OverlayHelperWindow *helperWindow;
}

// Initialization
- (id) initWithOverlayView:(NSView *)overlayView;

// Accessors
- (NSView *) overlayView;

@end


