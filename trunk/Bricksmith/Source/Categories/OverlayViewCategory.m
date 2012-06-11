//==============================================================================
//
// File:        OverlayViewCategory.m
//
// Purpose:		Provides methods to add or remove "overlay" views to 
//				hardware-accelerated views such as NSOpenGLView. The overlay is 
//				visually indistinguishable from a subview, except that it has 
//				major performance advantages. 
//
//				There are three methods for drawing Cocoa content overtop of 
//				OpenGL: 
//
//				Method     Performance          Ease of Implementation
//						   Considerations
//				----------------------------------------------------------------
//				Underlay   40% fps reduction.   Easy. Set the OpenGL surface
//				surface    Redrawing subviews   order, make the window non-
//						   will cause a full    opaque, fill a clearColor in the
//						   OpenGL redraw.       GLView, and add subviews.
//				----------------------------------------------------------------
//				Core       20% fps reduction.   Undetermined. Enabling layer-
//				Animation                       backing is trivial, but my
//												projection was messed up and I
//												didn't try debugging it.
//				----------------------------------------------------------------
//				Child      0% fps reduction!    A total pain. Multiple helper
//				window     Subviews may be      indirection classes needed. Oh,
//						   drawn independently  and you get to track the
//						   of OpenGL.           clipping region yourself.
//
//				Since the first two methods come with unacceptable performance 
//				impacts, we go with door #3. 
//
// Notes:		Adapted from Apple sample code "GLChildWindowDemo".
//				By implementing this as a category, we produce fully generic and 
//				portable code not dependent on any particular view class. 
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "OverlayViewCategory.h"

#import "OverlayHelperView.h"
#import "OverlayHelperWindow.h"


@implementation NSView (OverlayView)

//========== addOverlayView: ===================================================
//
// Purpose:		Adds theView as a subview of a transparent window which is 
//				attached to hover overtop of the receiver. 
//
//				The result is something that looks like a subview, but is 
//				actually composited in a separate window. The result is 
//				drastically improved performance over other methods for adding 
//				subviews to hardware-backed views such as OpenGL views.
//
//==============================================================================
- (void) addOverlayView:(NSView *)overlayView
{
	OverlayHelperView   *helperView = nil;
	
	// Add a special NSView to the parent so we can track a few things...
	helperView  = [[OverlayHelperView alloc] initWithOverlayView:overlayView];
	
	[self addSubview:helperView];
	
	[helperView release];
	
}//end addOverlayView:ordered:


//========== removeOverlayView: ================================================
//
// Purpose:		Removes the pseudo-subview.
//
// Notes:		You only need to call this if you wish to remove the overlay 
//				prior to natural deallocation. Otherwise, it will be removed 
//				automatically. 
//
//==============================================================================
- (void) removeOverlayView:(NSView *)overlayViewIn
{
	NSView  *currentView    = nil;
	NSView  *overlayHelper  = nil;
	NSView  *currentOverlay = nil;

	// Find the helper view which manages the given overlay
	for(currentView in [self subviews])
	{
		if([currentView respondsToSelector:@selector(overlayView)])
		{
			currentOverlay = [(OverlayHelperView*)currentView overlayView];
			
			if(currentOverlay == overlayViewIn)
			{
				overlayHelper = currentView;
				break;
			}
		}
	}
	
	if(overlayHelper)
	{
		[overlayHelper removeFromSuperview];
	}

	[self setNeedsDisplay:YES];
	
}//end removeOverlayView:


@end

