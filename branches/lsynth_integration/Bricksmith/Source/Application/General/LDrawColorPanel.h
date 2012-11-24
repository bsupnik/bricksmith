//==============================================================================
//
// File:		LDrawColorPanel.h
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
// Class:		LDrawColorPanel
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawColorPanel : NSPanel <LDrawColorable, NSWindowDelegate>
{
	IBOutlet	LDrawColorPanel		*colorPanel;
	IBOutlet	LDrawColorBar		*colorBar;
	IBOutlet	NSTableView			*colorTable;
	IBOutlet	NSSearchField		*searchField;
				
	IBOutlet	NSArrayController	*colorListController;
				
				//YES if we are in the middle of updating the color panel to 
				// reflect the current selection, NO any other time.
				BOOL				 updatingToReflectFile;
}

//Initialization
+ (LDrawColorPanel *) sharedColorPanel;

//Actions
- (void) focusSearchField:(id)sender;
- (void) sendAction;
- (IBAction) searchFieldChanged:(id)sender;
- (void) updateSelectionWithObjects:(NSArray *)selectedObjects;

//Utilities
- (NSInteger) indexOfColor:(LDrawColor *)colorSought;
- (void) loadInitialSortDescriptors;
- (NSPredicate *) predicateForSearchString:(NSString *)searchString;

@end
