//==============================================================================
//
// File:		OverlayHelperWindow.h
//
// Purpose:		This child window helps create the illusion that a 
//				hardware-accelerated surface has a subview. 
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


////////////////////////////////////////////////////////////////////////////////
//
// class OverlayHelperWindow
//
////////////////////////////////////////////////////////////////////////////////
@interface OverlayHelperWindow : NSWindow
{
	NSView                  *parentView;
	NSWindowOrderingMode    order;
}

// Initialization
- (id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle
	backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
	ordered:(NSWindowOrderingMode)place;

// Accessors
- (NSView *) parentView;
- (void) setParentView:(NSView *)parentViewIn;

// Notifications
- (void) parentViewWillMoveToWindow:(NSWindow *)window;
- (void) parentViewDidMoveToWindow;

// Utilities
- (void) registerNotifications;
- (void) updateFrameToMatchParentView;

@end


