//
//  SearchPanel.h
//  Bricksmith
//
//  Created by Robin Macharg on 06/02/2014.
//

#import <Cocoa/Cocoa.h>
#import "LDrawColorWell.h"

// UI radio buttons are tagged:
// Where to search
typedef enum {
    ScopeFile  = 1,
    ScopeModel = 2,
    ScopeStep  = 3,
    ScopeSelection = 4
} ScopeT;

// How to search for colors
typedef enum {
    ColorNoFilter = 1,
    ColorSelectionFilter = 2,
    ColorFilter = 3
} ColorFilterT;

// What to search for
typedef enum {
    SearchAllParts = 1,
    SearchSpecificPart = 2,
    SearchSelectedParts = 3
} SearchPartCriteriaT;

@interface SearchPanelController : NSWindowController <NSWindowDelegate, NSDraggingDestination>
{
	__weak IBOutlet NSMatrix		*scopeMatrix;
	__weak IBOutlet NSMatrix		*colorMatrix;
	__weak IBOutlet LDrawColorWell	*colorWell;
	__weak IBOutlet NSMatrix		*findTypeMatrix;
	__weak IBOutlet NSButton		*searchInsideLSynthContainers;
	__weak IBOutlet NSButton		*searchHiddenParts;
	__weak IBOutlet NSTextField		*partName;
	__weak IBOutlet NSTextField		*warningText;
}

//Initialization
+ (SearchPanelController *) searchPanel;

// Accessors
+ (BOOL) isVisible;

// Actions
- (IBAction)doSearchAndSelect:(id)sender;
- (IBAction)scopeChanged:(id)sender;
- (IBAction)colorOptionChanged:(id)sender;
- (IBAction)findTypeOptionChanged:(id)sender;

// Utility
- (void) updateInterfaceForSelection:(NSArray *)selectedObjects;

@end
