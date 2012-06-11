//==============================================================================
//
// File:		ScrollViewCategory.m
//
// Purpose:		Provides extra functionality to scroll views.
//
// Modified:	11/23/07 Allen Smith. Creation date.
//
//==============================================================================
#import "ScrollViewCategory.h"

#import "CenteringClipView.h"

@implementation NSScrollView (ScrollViewCategory)

//========== centerDocumentView ================================================
//
// Purpose:		Forces the document view to be drawn in the center of the scroll 
//				view when it does not entirely fill the scroll view. 
//
//==============================================================================
- (void) centerDocumentView
{
	NSView				*documentView		= [[self documentView] retain];
	NSClipView			*oldClipView		= [self contentView];
	CenteringClipView	*centeringClipView	= [[CenteringClipView alloc] initWithFrame:[oldClipView frame]];
	NSRect				visibleRect 		= [self documentVisibleRect];
	
	// replicate settings
	[centeringClipView	setBackgroundColor:[NSColor windowBackgroundColor]];
//	[centeringClipView	setCopiesOnScroll:[oldClipView copiesOnScroll]];
	[centeringClipView	setCopiesOnScroll:NO];
	[centeringClipView	setDrawsBackground:[oldClipView drawsBackground]];
	
	// set the new view in the scroll view
	[self setContentView:centeringClipView];
	[self setDocumentView:documentView];
	[[self documentView] scrollRectToVisible:visibleRect];
	
	// Let My Bits Go!
	[documentView		release];
	[centeringClipView	release];
	
}//end centerDocumentView


@end
