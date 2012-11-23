//==============================================================================
//
// File:		OverlayHelperWindow.h
//
// Purpose:		This child window helps create the illusion that a 
//				hardware-accelerated surface has a subview. 
//
//				This is a companion to OverlayViewCategory. It hosts the actual 
//				content of the overlay view. It fits in like this:
//					
//					* Hardware-accelerated view (parentView)
//						|
//						|- OverlayHelperView subview has child window:
//
//								* OverlayHelperWindow
//									|
//									|- content view is the overlay "subview" of 
//									   parentView. 
//
//				This convolution basically achieves two results:
//					1) The subview is visible and is composited over the 
//					parentView by the OS, thereby incurring zero performance 
//					penalty. 
//					2) The solution is implemented by a category method, so it 
//					is generic to all views. 
//
// Notes:		Adapted from Apple sample code "GLChildWindowDemo".
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "OverlayHelperWindow.h"

#import "OverlayViewCategory.h"


@implementation OverlayHelperWindow

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithContentRect:styleMask:backing:defer:parentView:ordered: ===
//
// Purpose:		Creates an overlay window. It doesn't actually do anything until 
//				you set its parentView, which is the "superview" for this 
//				window's overlay content. 
//
//==============================================================================
- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				   backing:(NSBackingStoreType)bufferingType
					 defer:(BOOL)flag
				   ordered:(NSWindowOrderingMode)place
{
	self = [super initWithContentRect:contentRect
							styleMask:aStyle
							  backing:bufferingType
								defer:flag];
	if(self)
	{
		self->order       = place;
		
		[self setOpaque:NO];
		[self setAlphaValue:.999];
		[self setIgnoresMouseEvents:YES];
	}
	
	return self;
	
}//end initWithContentRect:styleMask:backing:defer:parentView:ordered:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== parentView ========================================================
//==============================================================================
- (NSView *) parentView
{
	return parentView;
}


//========== setParentView: ====================================================
//
// Purpose:		Sets the pseudo-superview to which this window kowtows. The 
//				parentView is presumably a hardware-accelerated surface which 
//				would incur a performance penality for containing its own drawn 
//				subviews. 
//
//==============================================================================
- (void) setParentView:(NSView *)parentViewIn
{
	self->parentView = parentViewIn;
	
	[self registerNotifications];
}


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== parentViewChanged: ================================================
//
// Purpose:		The parentView's frame, bounds, or visible rect have changed. We 
//				must resize ourself in order to maintain the illusion that our 
//				content is actually a subview of the parentView. 
//
//==============================================================================
- (void) parentViewChanged:(NSNotification *)note
{
	[self updateFrameToMatchParentView];
	
}//end parentViewChanged:


//========== windowDidUpdateNotification: ======================================
//
// Purpose:		This notification captures when the window moves onscreen. 
//				(Cocoa does not have an NSWindowDidOpenNotification.) 
//
//				Due to some interplay with sheets and window groups, we 
//				absolutely can not display the overlay window until AFTER the 
//				parent window has opened. (Showing it before will cause some 
//				sort of CG error and prevent the parent sheet from opening if 
//				the parent view is in a sheet.) 
//
//==============================================================================
- (void) windowDidUpdateNotification:(NSNotification *)note
{
	// Force synchronize with the parent view's size. If we don't do this here, 
	// the overlay can open in the wrong location if it hasn't been 
	// orderFront:'ed before this point. I don't know what makes this happen, 
	// because it should be tracking the view size notifications already. 
	[self updateFrameToMatchParentView];
	
	// Open the overlay window (self) now that the parent view's window is open. 
	// Actually, it won't be open until this event loop completes, so make sure 
	// we open on the *next* cycle, by which time the parent will be onscreen.
	// Note: If we were using the undocumented _NSWindowDidBecomeVisible, we 
	//		 wouldn't have to do the delay hack. 
	[self performSelector:@selector(orderFront:) withObject:self afterDelay:0];
	
	// And we don't care about window updating anymore.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidUpdateNotification object:nil];

}//end windowDidUpdateNotification:


#pragma mark -

//========== parentViewWillMoveToWindow: =======================================
//
// Purpose:		Parent view is changing windows. Provide some management and 
//				notifications. 
//
//==============================================================================
- (void) parentViewWillMoveToWindow:(NSWindow *)window
{
	if(window == nil && window != [self parentWindow])
	{
		NSView *overlayView = [self contentView];
		
		if([overlayView respondsToSelector:@selector(viewWillResignOverlay)])
			[overlayView viewWillResignOverlay];
		
		[[self parentWindow] removeChildWindow:self];
		
		if([overlayView respondsToSelector:@selector(viewDidResignOverlay)])
			[overlayView viewDidResignOverlay];
	}
}//end parentViewWillMoveToWindow:


//========== parentViewDidMoveToWindow =========================================
//
// Purpose:		Parent view has changed windows. Provide some management and 
//				notifications. 
//
//==============================================================================
- (void) parentViewDidMoveToWindow
{
	NSView      *overlayView        = [self contentView];
	NSWindow    *newParentWindow    = [self->parentView window];
	
	if(newParentWindow != nil)
	{
		if([overlayView respondsToSelector:@selector(viewWillBecomeOverlay)])
			[overlayView viewWillBecomeOverlay];
		
		// Attach to the new window and move in concert with it.
		if([self parentWindow] != newParentWindow)
			[newParentWindow addChildWindow:self ordered:order];
		
		if([newParentWindow isVisible])
			[self orderFront:nil];
		
		[self parentViewChanged:nil];
		
		if([overlayView respondsToSelector:@selector(viewDidBecomeOverlay)])
			[overlayView viewDidBecomeOverlay];
	}
	
	[self registerNotifications];
	
}//end parentViewDidMoveToWindow


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== registerNotifications =============================================
//
// Purpose:		Watch the frames of important views so this overlay window can 
//				keep its size in sync. 
//
//==============================================================================
- (void) registerNotifications
{
	NSNotificationCenter    *notificationCenter = [NSNotificationCenter defaultCenter];
	NSView                  *currentView        = nil;
	
	// Unregister existing cruft
	[notificationCenter removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
	[notificationCenter removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
	[notificationCenter removeObserver:self name:nil object:nil];
	
	// Watch EVERY single superview for frame-change notifications, because any 
	// one of them could result in different viewport occlusions. Since we need 
	// to watch the visible rect of our view, we must be ready for *anything.* 
	currentView = self->parentView;
	while(currentView)
	{
		[notificationCenter addObserver:self
							   selector:@selector(parentViewChanged:)
								   name:NSViewFrameDidChangeNotification
								 object:currentView];
		
		[notificationCenter addObserver:self
							   selector:@selector(parentViewChanged:)
								   name:NSViewBoundsDidChangeNotification
								 object:currentView];
								 
		// We need to know when the parent window opens so we know when to open 
		// ourself. This seems to be the only way to do it without using the 
		// undocumented notification _NSWindowDidBecomeVisible. 
		if([currentView window])
		{
			[notificationCenter addObserver:self
								   selector:@selector(windowDidUpdateNotification:)
									   name:NSWindowDidUpdateNotification
									 object:[currentView window]];
		}
								 
		currentView = [currentView superview];
	}

}//end registerNotifications


//========== updateFrameToMatchParentView ======================================
//
// Purpose:		Resize this overlay window in order to maintain the illusion 
//				that our content is actually a subview of the parentView. 
//
//==============================================================================
- (void) updateFrameToMatchParentView
{
	NSRect  viewRect    = NSZeroRect;
	NSRect  windowRect  = NSZeroRect;
	
	// Get the "superview's" rect in window coordinates.
	viewRect = [self->parentView convertRect:[self->parentView visibleRect] toView:nil];
	
	// Position ourself overtop the parentViews visible rect.
	windowRect = [[self->parentView window] frame];
	
	viewRect.origin.x += windowRect.origin.x;
	viewRect.origin.y += windowRect.origin.y;
	
	[self setFrame:viewRect display:YES];
	
}//end updateFrameToMatchParentView


@end
