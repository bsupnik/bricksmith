//==============================================================================
//
// File:		DocumentToolbarController.h
//
// Purpose:		Repository for methods relating to creating and maintaining the 
//				toolbar for the main document window.
//
//  Created by Allen Smith on 5/4/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawDocument.h"

#define TOOLBAR_GRID_SPACING_IDENTIFIER	@"GridSpacing"
#define TOOLBAR_NUDGE_X_IDENTIFIER		@"NudgeX"
#define TOOLBAR_NUDGE_Y_IDENTIFIER		@"NudgeY"
#define TOOLBAR_NUDGE_Z_IDENTIFIER		@"NudgeZ"
#define TOOLBAR_PART_BROWSER			@"PartBrowser"
	//Rotation identifiers match both localized string key and image name.
#define TOOLBAR_ROTATE_POSITIVE_X		@"Rotate+X"
#define TOOLBAR_ROTATE_NEGATIVE_X		@"Rotate-X"
#define TOOLBAR_ROTATE_POSITIVE_Y		@"Rotate+Y"
#define TOOLBAR_ROTATE_NEGATIVE_Y		@"Rotate-Y"
#define TOOLBAR_ROTATE_POSITIVE_Z		@"Rotate+Z"
#define TOOLBAR_ROTATE_NEGATIVE_Z		@"Rotate-Z"
#define TOOLBAR_SHOW_COLORS				@"ShowColors"
#define TOOLBAR_SHOW_INSPECTOR			@"ShowInspector"
#define TOOLBAR_SNAP_TO_GRID			@"Snap To Grid"
#define TOOLBAR_ZOOM_IN					@"Zoom In"
#define TOOLBAR_ZOOM_OUT				@"Zoom Out"
#define TOOLBAR_ZOOM_SPECIFY			@"Specify Zoom"

////////////////////////////////////////////////////////////////////////////////
//
// class DocumentToolbarController
//
////////////////////////////////////////////////////////////////////////////////
@interface DocumentToolbarController : NSObject <NSToolbarDelegate>
{
	IBOutlet LDrawDocument			*document; //link to the documnt to which this is attached.

	IBOutlet NSView					*nudgeXToolView;
	IBOutlet NSView					*nudgeYToolView;
	IBOutlet NSView					*nudgeZToolView;
	IBOutlet NSView					*zoomToolView; //enter zoom percentage.
	
	IBOutlet NSSegmentedControl		*gridSegmentedControl;
}

//Button factories
- (NSToolbarItem *) makeGridSpacingItem;
- (NSToolbarItem *) makeRotationPlusXItem;
- (NSToolbarItem *) makeRotationMinusXItem;
- (NSToolbarItem *) makeRotationPlusYItem;
- (NSToolbarItem *) makeRotationMinusYItem;
- (NSToolbarItem *) makeRotationPlusZItem;
- (NSToolbarItem *) makeRotationMinusZItem;
- (NSToolbarItem *) makeShowColorsItem;
- (NSToolbarItem *) makeShowInspectorItem;
- (NSToolbarItem *) makePartBrowserItem;
- (NSToolbarItem *) makeSnapToGridItem;
- (NSToolbarItem *) makeZoomInItem;
- (NSToolbarItem *) makeZoomOutItem;
- (NSToolbarItem *) makeZoomItem;

//Accessors
- (void) setGridSpacingMode:(gridSpacingModeT)newMode;

//Actions
- (IBAction) gridSpacingSegmentedControlClicked:(id)sender;
- (IBAction) nudgeXClicked:(id)sender;
- (IBAction) nudgeYClicked:(id)sender;
- (IBAction) nudgeZClicked:(id)sender;
- (IBAction) zoomSegmentedControlClicked:(id)sender;
- (IBAction) zoomScaleChanged:(id)sender;

@end
