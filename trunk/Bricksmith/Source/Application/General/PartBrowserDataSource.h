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

@class PartLibrary;

////////////////////////////////////////////////////////////////////////////////
//
// class PartBrowserDataSource
//
////////////////////////////////////////////////////////////////////////////////
@interface PartBrowserDataSource : NSObject
{
	IBOutlet NSComboBox		*categoryComboBox;
	IBOutlet NSSearchField	*searchField;
	IBOutlet NSTableView	*partsTable;
	IBOutlet LDrawGLView	*partPreview;
	IBOutlet NSButton		*zoomInButton;
	IBOutlet NSButton		*zoomOutButton;
	IBOutlet NSButton		*addRemoveFavoriteButton;
	IBOutlet NSButton		*insertButton;
	IBOutlet NSMenu			*contextualMenu;

	PartLibrary     *partLibrary; //weak reference to the shared part catalog.
	NSString		*selectedCategory;
	NSArray         *categoryList;
	NSMutableArray  *tableDataSource;

}

//Accessors
- (NSString *) category;
- (NSString *) selectedPartName;

- (void) setPartLibrary:(PartLibrary *)partLibraryIn;
- (BOOL) loadCategory:(NSString *)newCategory;
- (void) setCategoryList:(NSArray *)categoryList;
- (void) setTableDataSource:(NSMutableArray *) partsInCategory;

//Actions
- (IBAction) addPartClicked:(id)sender;
- (IBAction) addFavoriteClicked:(id)sender;
- (IBAction) categoryComboBoxChanged:(id)sender;
- (void) doubleClickedInPartTable:(id)sender;
- (IBAction) removeFavoriteClicked:(id)sender;
- (IBAction) searchFieldChanged:(id)sender;

//Notifications
- (void) sharedPartCatalogDidChange:(NSNotification *)notification;

//Utilities
- (NSMutableArray *) filterPartRecords:(NSArray *)partRecords bySearchString:(NSString *)searchString;
- (NSUInteger) indexOfPartNamed:(NSString *)searchName;
- (void) setConstraints;
- (void) syncSelectionAndPartDisplayed;
- (BOOL) writeSelectedPartToPasteboard:(NSPasteboard *)pasteboard;

@end
