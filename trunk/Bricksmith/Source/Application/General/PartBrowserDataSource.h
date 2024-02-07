//==============================================================================
//
// File:		PartBrowserDataSource.h
//
// Purpose:		Provides a standarized data source for part browser interface.
//
//  Created by Allen Smith on 2/17/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawGLView.h"
#import "MacLDraw.h"

@class LDrawViewerContainer;
@class PartLibrary;

////////////////////////////////////////////////////////////////////////////////
//
// class PartBrowserDataSource
//
////////////////////////////////////////////////////////////////////////////////
@interface PartBrowserDataSource : NSObject <NSOutlineViewDelegate, NSOutlineViewDataSource>
{
	__weak IBOutlet NSButton		*searchAllCategoriesButton;
	__weak IBOutlet NSButton		*searchSelectedCategoryButton;
	__weak IBOutlet NSSearchField	*searchField;
	
	__weak IBOutlet NSOutlineView	*categoryTable;
	__weak IBOutlet NSTableView		*partsTable;
	__weak IBOutlet LDrawGLView		*partPreview;
	__weak IBOutlet LDrawViewerContainer	*partPreviewViewport;
	__weak IBOutlet NSButton		*zoomInButton;
	__weak IBOutlet NSButton		*zoomOutButton;
	__weak IBOutlet NSButton		*addRemoveFavoriteButton;
	__weak IBOutlet NSButton		*insertButton;
	__weak IBOutlet NSMenu			*contextualMenu;

	__weak PartLibrary	*partLibrary; //weak reference to the shared part catalog.
	__weak NSString		*selectedCategory;
	__weak NSArray 		*categoryList;
	NSMutableArray  	*tableDataSource;
	SearchModeT			searchMode;

}

//Accessors
- (NSString *) category;
- (NSString *) selectedPartName;

- (void) setPartLibrary:(PartLibrary *)partLibraryIn;
- (BOOL) loadCategory:(NSString *)newCategory;
- (void) setCategoryList:(NSArray *)categoryList;
- (void) setTableDataSource:(NSMutableArray *) partsInCategory;

//Actions
- (IBAction) searchAllCategoriesButtonClicked:(id)sender;
- (IBAction) searchSelectedCategoryButtonClicked:(id)sender;
- (IBAction) addPartClicked:(id)sender;
- (IBAction) addFavoriteClicked:(id)sender;
- (void) doubleClickedInPartTable:(id)sender;
- (IBAction) removeFavoriteClicked:(id)sender;
- (IBAction) searchFieldChanged:(id)sender;

//Notifications
- (void) sharedPartCatalogDidChange:(NSNotification *)notification;

//Utilities
- (NSMutableArray *) filterPartRecords:(NSArray *)partRecords bySearchString:(NSString *)searchString excludeParts:(NSSet *)excludedParts;
- (NSUInteger) indexOfPartNamed:(NSString *)searchName;
- (void) performSearch;
- (void) setConstraints;
- (void) scrollSelectedCategoryToCenter;
- (void) syncSelectionAndCategoryDisplayed;
- (void) syncSelectionAndPartDisplayed;
- (BOOL) writeSelectedPartToPasteboard:(NSPasteboard *)pasteboard;

@end
