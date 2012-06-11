//==============================================================================
//
// File:		CenteringClipView.m
//
// Purpose:		Centers the document view of a scroll view.
//
//				Cocoa is very annoying in that it sticks the document view at a 
//				corner (top or bottom, depending on whether the view is 
//				flipped), which is almost never where we actually want it. 
//				Worse, it provides no API to get it there, and it's not very 
//				obvious what to subclass in order to make this happen. (In fact, 
//				I stumpped an Apple Cocoa engineer at WWDC once with this one.) 
//
//				Eventually, the internet came to the rescue:
//				http://www.bergdesign.com/missing_cocoa_docs/nsclipview.html
//				by Brock Brandenberg
//
//				I had to tweak it though. The code as posted didn't actually 
//				work, but the idea was there. 
//
// Notes:		In order to use this functionality, you must set the scroll 
//				view's clip view to be a member of this subclass. That is 
//				problematic with Interface Builder, since the scroll view's clip 
//				view will be archived and unpacked as an NSClipView. To allow 
//				this class to be used, I have written a category on NSScrollView 
//				which replaces the current clip view with a newly-allocated one 
//				of this class. 
//
// Modified:	11/23/07 Allen Smith. Creation date.
//
//==============================================================================
#import "CenteringClipView.h"

#import <math.h>


@implementation CenteringClipView

//========== centerDocumentView ================================================
//
// Purpose:		Changes the scroll position so that the document view is 
//				centered in the scrollview, provided that the scrollview is 
//				larger than the document view. 
//
//==============================================================================
- (void) centerDocumentView
{
	NSRect docRect	= [[self documentView] frame];
	NSRect clipRect = [self bounds];
	
	if(NSWidth(docRect) < NSWidth(clipRect))
		clipRect.origin.x = docRect.origin.x - (NSWidth(clipRect) - NSWidth(docRect))/2;
	
	if(NSHeight(docRect) < NSHeight(clipRect))
		clipRect.origin.y = docRect.origin.y - (NSHeight(clipRect) - NSHeight(docRect))/2;
	
	// Align to pixel boundaries. But don't use NSIntegralRect, because it will 
	// alter the width/height. 
//	NSIntegralRect(clipRect);
	clipRect.origin.x = floor(clipRect.origin.x);
	clipRect.origin.y = floor(clipRect.origin.y);
	
	[self scrollToPoint:clipRect.origin];
	
}//end centerDocumentView


//========== constrainScrollPoint: =============================================
//
// Purpose:		We need to override this so that the superclass doesn't decide 
//				our new origin point is invalid.
//
//==============================================================================
- (NSPoint) constrainScrollPoint:(NSPoint)proposedNewOrigin
{
	NSRect	docRect				= [[self documentView] frame];
	NSRect	clipRect			= [self bounds];
	NSPoint	constrainedPoint	= [super constrainScrollPoint:proposedNewOrigin];
	NSPoint	newScrollPoint		= constrainedPoint;

	if(NSWidth(docRect) < NSWidth(clipRect))
		newScrollPoint.x = docRect.origin.x - (NSWidth(clipRect) - NSWidth(docRect))/2;
	
	if(NSHeight(docRect) < NSHeight(clipRect))
		newScrollPoint.y = docRect.origin.y - (NSHeight(clipRect) - NSHeight(docRect))/2;
	
	return newScrollPoint;
	
}//end constrainScrollPoint:


//========== viewBoundsChanged: ================================================
//
// Purpose:		If the view changes, we must recenter.
//
//==============================================================================
- (void) viewBoundsChanged:(NSNotification *)notification
{
	[super viewBoundsChanged:notification];
	[self centerDocumentView];
	
}//end viewBoundsChanged:


//========== viewFrameChanged: =================================================
//
// Purpose:		If the view changes, we must recenter.
//
//==============================================================================
- (void) viewFrameChanged:(NSNotification *)notification
{
	[super viewFrameChanged:notification];
	[self centerDocumentView];
	
}//end viewFrameChanged:


#pragma mark -
#pragma mark FRAME-CHANGING METHODS
#pragma mark -

// ----------------------------------------
// These superclass methods change the bounds rect directly without sending any 
// notifications, so we're not sure what other work they silently do for us. As 
// a result, we let them do their work and then swoop in behind to change the 
// bounds origin ourselves. This appears to work just fine without us having to 
// reinvent the methods from scratch. 


//========== setFrame: =========================================================
//==============================================================================
- (void) setFrame:(NSRect)frameRect
{
	[super setFrame:frameRect];
	[self centerDocumentView];
	
}//end setFrame:


//========== setFrameOrigin: ===================================================
//==============================================================================
- (void) setFrameOrigin:(NSPoint)newOrigin
{
	[super setFrameOrigin:newOrigin];
	[self centerDocumentView];
	
}//end setFrameOrigin:


//========== setFrameSize: =====================================================
//==============================================================================
- (void)setFrameSize:(NSSize)newSize
{
	[super setFrameSize:newSize];
	[self centerDocumentView];
	
}//end setFrameSize:


//========== setFrameRotation: =================================================
//==============================================================================
- (void)setFrameRotation:(CGFloat)angle
{
	[super setFrameRotation:angle];
	[self centerDocumentView];
	
}//end setFrameRotation:


@end
