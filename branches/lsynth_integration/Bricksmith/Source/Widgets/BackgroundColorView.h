//==============================================================================
//
// File:		BackgroundColorView.h
//
// Purpose:		A view which paints a background color.
//
// Modified:	07/23/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


////////////////////////////////////////////////////////////////////////////////
//
// class BackgroundColorView
//
////////////////////////////////////////////////////////////////////////////////
@interface BackgroundColorView : NSView
{
	NSColor *backgroundColor;
}

// Accessors
- (void) setBackgroundColor:(NSColor *)colorIn;

@end
