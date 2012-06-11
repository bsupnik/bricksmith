//==============================================================================
//
// File:		ToolPalette.h
//
// Purpose:		Manages the current tool mode in effect when the mouse is used 
//				in an LDrawGLView.
//
//  Created by Allen Smith on 1/20/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@class LDrawColorWell;

////////////////////////////////////////////////////////////////////////////////
//
//		Types and Constants
//
////////////////////////////////////////////////////////////////////////////////

typedef enum
{
	RotateSelectTool			= 0,	// click to select, drag to rotate
//	AddToSelectionTool			= 1,	//    check key directly, so we can click around in different views.
	PanScrollTool				= 2,	// "grabber" to scroll around while dragging
	SmoothZoomTool				= 3,	// zoom in and out based on drag direction
	ZoomInTool					= 4,	// click to zoom in
	ZoomOutTool					= 5,	// click to zoom out
	SpinTool					= 6,	// spin the model in space
	EraserTool					= 7		// delete clicked parts (for pen tablet erasers)

} ToolModeT;



////////////////////////////////////////////////////////////////////////////////
//
//		ToolPalette
//
////////////////////////////////////////////////////////////////////////////////
@interface ToolPalette : NSObject
{
	ToolModeT				 baseToolMode;			//as selected in the palette
	ToolModeT				 effectiveToolMode;		//accounting for modifiers.
	
	//Event Tracking
	NSString				*currentKeyCharacters;	//identifies the current keys down, independent of modifiers (empty string if no keys down)
	NSUInteger				 currentKeyModifiers;	//identifiers the current modifiers down (including device-dependent)
	BOOL					 mouseButton3IsDown;
	NSPointingDeviceType	 tabletPointingDevice;	// current pen-tablet device currently in proximity

	NSPanel					*palettePanel;

	//Nib connections
	IBOutlet NSView			*paletteContents;
	IBOutlet NSMatrix		*toolButtons;
	IBOutlet LDrawColorWell	*colorWell;
}


//Initialization
+ (ToolPalette *) sharedToolPalette;

//Accessors
+ (ToolModeT) toolMode;
- (BOOL) isVisible;
- (ToolModeT) toolMode;
- (void) setToolMode:(ToolModeT)newToolMode;

//Actions
- (void) hideToolPalette:(id)sender;
- (void) showToolPalette:(id)sender;
- (IBAction) toolButtonClicked:(id)sender;

// Event notifiers
- (void) mouseButton3DidChange:(NSEvent *)theEvent;

//Utilities
- (void) resolveCurrentToolMode;
+ (NSString *) keysForToolMode:(ToolModeT)toolMode modifiers:(NSUInteger*)modifiersOut;
+ (BOOL) toolMode:(ToolModeT)toolMode matchesCharacters:(NSString *)characters modifiers:(NSUInteger)modifiers;

@end
