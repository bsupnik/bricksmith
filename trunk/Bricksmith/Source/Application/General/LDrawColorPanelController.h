//==============================================================================
//
// File:		LDrawColorPanelController.h
//
// Purpose:		Color-picker for Bricksmith.
//
//  Created by Allen Smith on 2/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ColorLibrary.h"

@class LDrawColorBar;

////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawColorPanelController
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawColorPanelController : NSWindowController <LDrawColorable>
{
	__weak IBOutlet	LDrawColorBar		*colorBar;
	__weak IBOutlet	NSPopUpButton		*materialPopUpButton;
	__weak IBOutlet	NSTableView			*colorTable;
	__weak IBOutlet	NSSearchField		*searchField;
				
	__weak IBOutlet	NSArrayController	*colorListController;
	
				//YES if we are in the middle of updating the color panel to 
				// reflect the current selection, NO any other time.
				BOOL				 updatingToReflectFile;
}

//Initialization
+ (LDrawColorPanelController *) sharedColorPanel;

//Actions
- (void) focusSearchField:(id)sender;
- (IBAction) materialPopUpButtonChanged:(id)sender;
- (void) sendAction;
- (IBAction) searchFieldChanged:(id)sender;
- (void) updateSelectionWithObjects:(NSArray *)selectedObjects;

//Utilities
- (NSInteger) indexOfColor:(LDrawColor *)colorSought;
- (void) loadInitialSortDescriptors;

@end
