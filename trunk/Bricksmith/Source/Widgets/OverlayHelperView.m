//==============================================================================
//
// File:		OverlayHelperView.m
//
// Purpose:		Manages a "subview" which is painted over a hardware-accelerated 
//				surface such as OpenGL. 
//
//				This is a companion to OverlayViewCategory. It provides hooks for 
//				tracking the size of the receiver, which the OverlayViewCategory 
//				category can't do directly. But by implementing as a category, 
//				we produce fully generic and portable code not dependent on any 
//				particular view class. 
//
// Notes:		Adapted from Apple sample code "GLChildWindowDemo".
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "OverlayHelperView.h"

#import "OverlayHelperWindow.h"


@implementation OverlayHelperView


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithFrame: ====================================================
//
// Purpose:		Initialize the object.
//
// Parameters:	overlayView	- the "subview" of the hardware-accelerated surface.
//
//==============================================================================
- (id) initWithOverlayView:(NSView *)overlayView
{
	self = [super initWithFrame:NSZeroRect];
	
	// The overlay content itself is offloaded to a child window (which is 
	// hardware-composited by the OS for sizzling performance). 
	self->helperWindow = [[OverlayHelperWindow alloc] initWithContentRect:NSMakeRect(-10000,-10000,1,1)
																styleMask:NSBorderlessWindowMask
																  backing:NSBackingStoreBuffered
																	defer:YES
																  ordered:NSWindowAbove];
	// The window can get auto-closed by the OS when its parent window is 
	// closed, leaving us with a dangling pointer if we didn't call this.
	[helperWindow setReleasedWhenClosed:NO]; 
	
	[helperWindow setContentView:overlayView];
	
	return self;

}//end initWithFrame:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== overlayView =======================================================
//
// Purpose:		Returns the overlay view this window manages (by hosting in a 
//				child window). 
//
//==============================================================================
- (NSView *) overlayView
{
	return [self->helperWindow contentView];
	
}//end overlayView


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== viewWillMoveToWindow: =============================================
//
// Purpose:		Pass this important info along!
//
//==============================================================================
- (void) viewWillMoveToWindow:(NSWindow *)theWindow
{
	[helperWindow parentViewWillMoveToWindow:theWindow];
	
}//end viewWillMoveToWindow:


//========== viewDidMoveToWindow ===============================================
//
// Purpose:		Pass this important info along!
//
//==============================================================================
- (void) viewDidMoveToWindow
{
	[helperWindow parentViewDidMoveToWindow];
	
}//end viewDidMoveToWindow


//========== viewWillMoveToSuperview: ==========================================
//
// Purpose:		The view is now being added to its superview. The superview is 
//				the hardware-accelerated surface which cannot display subviews 
//				on its own. 
//
//==============================================================================
- (void) viewWillMoveToSuperview:(NSView *)newSuperview
{
	// The child window needs to watch the frame of the hardware-accelerated 
	// view. 
	[helperWindow setParentView:newSuperview];
	
}//end viewWillMoveToSuperview:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We are of help no more.
//
//==============================================================================
- (void) dealloc
{
	[helperWindow release];

	[super dealloc];

}//end dealloc


@end


