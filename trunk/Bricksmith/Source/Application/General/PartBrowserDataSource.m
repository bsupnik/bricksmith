//==============================================================================
//
// File:		PartBrowserDataSource.m
//
// Purpose:		Provides a standarized data source for part browser interface.
//
//				A part browser consists of a table which displays part numbers 
//				and descriptions, and a combo box to choose part categories. If 
//				you wish to make a part browser, you must lay out the UI in a 
//				manner appropriate to its setting, and then connect all the 
//				outlets specified by this class. 
//
// Usage:		An instance of this class should exist in each Nib file which 
//				contains a part browser, and the browser widgets and actions 
//				should be connected to it. This class will then take care of 
//				managing those widgets.
//
//				Clients wishing to know about part insertions should implement 
//				the action -insertLDrawPart:.
//
//  Created by Allen Smith on 2/17/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartBrowserDataSource.h"

#import "LDrawApplication.h"
#import "LDrawColorPanel.h"
#import "LDrawPart.h"
#import "LDrawModel.h"
#import "MacLDraw.h"
#import "PartLibrary.h"
#import "StringCategory.h"

NSString    *PART_NUMBER_KEY    = @"Part Number";
NSString    *PART_NAME_KEY      = @"Part Name";


@implementation PartBrowserDataSource


//========== awakeFromNib ======================================================
//
// Purpose:		This class is just about always initialized in a Nib file.
//				So when awaking, we grab the actual data source for the class.
//
//==============================================================================
- (void) awakeFromNib
{
	NSUserDefaults  *userDefaults       = [NSUserDefaults standardUserDefaults];
	NSString        *startingCategory   = [userDefaults stringForKey:PART_BROWSER_PREVIOUS_CATEGORY];
	NSInteger       startingRow         = [userDefaults integerForKey:PART_BROWSER_PREVIOUS_SELECTED_ROW];
	NSMenu          *searchMenuTemplate = nil;
	NSMenuItem      *recentsItem        = nil;
	NSMenuItem      *noRecentsItem      = nil;
	
	// Loading main nib (the one in which this helper controller was allocated)
	// By the time this is called, our accessory nib has already been loaded in 
	// -init.
	if(self->partsTable != nil)
	{
		//---------- Widget Setup ----------------------------------------------
		
		[self->partsTable setTarget:self];
		[self->partsTable setDoubleAction:@selector(doubleClickedInPartTable:)];
		
		[self->partPreview setAcceptsFirstResponder:NO];
		[self->partPreview setDelegate:self];
		
		[self->zoomInButton setTarget:self->partPreview];
		[self->zoomInButton setAction:@selector(zoomIn:)];
		[self->zoomInButton setToolTip:NSLocalizedString(@"ZoomInTooltip", nil)];
		
		[self->zoomOutButton setTarget:self->partPreview];
		[self->zoomOutButton setAction:@selector(zoomOut:)];
		[self->zoomOutButton setToolTip:NSLocalizedString(@"ZoomOutTooltip", nil)];

		[self->addRemoveFavoriteButton setTarget:self];
		[self->addRemoveFavoriteButton setToolTip:NSLocalizedString(@"AddRemoveFavoritesTooltip", nil)];
		
		[self->insertButton setTarget:self];
		[self->insertButton setAction:@selector(addPartClicked:)];
		
		// Configure the search field's menu
		searchMenuTemplate = [[NSMenu alloc] initWithTitle:@"Search template"];
		
		noRecentsItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"NoRecentSearches", nil)
												   action:NULL
											keyEquivalent:@"" ];
		[noRecentsItem setTag:NSSearchFieldNoRecentsMenuItemTag];
		
		recentsItem = [[NSMenuItem alloc] initWithTitle:@"recent items placeholder"
												 action:NULL
										  keyEquivalent:@"" ];
		[recentsItem setTag:NSSearchFieldRecentsMenuItemTag];
		
		[searchMenuTemplate insertItem:noRecentsItem atIndex:0];
		[searchMenuTemplate insertItem:recentsItem atIndex:1];
		
		[[self->searchField cell] setSearchMenuTemplate:searchMenuTemplate];
		
		// If there is no sort order yet, define one.
		if([[self->partsTable sortDescriptors] count] == 0)
		{
			NSTableColumn		*descriptionColumn	= [self->partsTable tableColumnWithIdentifier:PART_NAME_KEY];
			NSSortDescriptor	*sortDescriptor		= [descriptionColumn sortDescriptorPrototype];
			
			if(sortDescriptor != nil)
				[self->partsTable setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
		}
		
		[self->partsTable setMenu:self->contextualMenu];
		
		
		//---------- Set Data --------------------------------------------------
		
		[self setPartLibrary:[PartLibrary sharedPartLibrary]];
		[self loadCategory:startingCategory];
		
		[partsTable scrollRowToVisible:startingRow];
		[partsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:startingRow]
				byExtendingSelection:NO];
		[self syncSelectionAndPartDisplayed];
		
		
		//---------- Notifications ---------------------------------------------
		
		//We also want to know if the part catalog changes while the program is running.
		[[NSNotificationCenter defaultCenter]
				addObserver: self
				   selector: @selector(sharedPartCatalogDidChange:)
					   name: LDrawPartLibraryDidChangeNotification
					 object: nil ];
		
		
		//---------- Free Memory -----------------------------------------------
		[searchMenuTemplate	release];
		[recentsItem		release];
		[noRecentsItem		release];
	}
	// Loading "PartBrowserAccessories.nib"
	else
	{
	}

}//end awakeFromNib


//========== init ==============================================================
//
// Purpose:		This is very basic; it's not where the action is.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	// Load the accessories from our private nib file.
	[NSBundle loadNibNamed:@"PartBrowserAccessories" owner:self];
	
	// Not displaying anything yet.
	categoryList	= [[NSArray array] retain];
	tableDataSource	= [[NSMutableArray array] retain];
	
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== category ==========================================================
//
// Purpose:		Returns the currently-selected category.
//
//==============================================================================
- (NSString *) category
{
	return self->selectedCategory;
	
}//end category


//========== selectedPartName ==================================================
//
// Purpose:		Returns the name of the selected part file.
//				i.e., "3001.dat"
//
//==============================================================================
- (NSString *) selectedPartName
{
	NSInteger       rowIndex    = [partsTable selectedRow];
	NSDictionary    *partRecord = nil;
	NSString        *partName   = nil;
	
	if(rowIndex >= 0)
	{
		partRecord	= [tableDataSource objectAtIndex:rowIndex];
		partName	= [partRecord objectForKey:PART_NUMBER_KEY];
	}
	
	return partName;
	
}//end selectedPartName


#pragma mark -

//========== loadCategory: =====================================================
//
// Purpose:		Causes the parts browser to display all the parts in 
//				newCategory. 
//
//==============================================================================
- (BOOL) loadCategory:(NSString *)newCategory
{
	NSString        *allCategoriesString        = NSLocalizedString(@"AllCategories", nil);
	NSString        *favoritesString            = NSLocalizedString(@"Favorites", nil);
	NSArray         *partsInCategory            = nil;
	NSMutableArray  *allPartRecords             = [NSMutableArray array];
	NSDictionary    *partRecord                 = nil;
	NSString        *partNumber                 = nil;
	NSString        *partDescription            = nil;
	NSUInteger      counter                     = 0;
	BOOL            success                     = NO;
	
	// Get the appropriate category list.
	if([newCategory isEqualToString:allCategoriesString])
	{
		// Retrieve all parts. We can do this by getting the entire (unsorted) 
		// contents of PARTS_LIST_KEY in the partCatalog, which is actually 
		// a dictionary of all parts.
		partsInCategory = [self->partLibrary allPartNames];
		success = YES;
		
	}
	else if([newCategory isEqualToString:favoritesString])
	{
		partsInCategory = [self->partLibrary favoritePartNames];
		success = YES;
	}
	else
	{
		// Get the part list for the category:
		partsInCategory = [self->partLibrary partNamesInCategory:newCategory];
		success = (partsInCategory != nil);
	}
	
	if(success == YES)
	{
		// Build the (sortable) list of part records.
		for(counter = 0; counter < [partsInCategory count]; counter++)
		{
			partNumber      = [partsInCategory objectAtIndex:counter];
			partDescription = [self->partLibrary descriptionForPartName:partNumber];
			
			partRecord      = [NSDictionary dictionaryWithObjectsAndKeys:
							   partNumber,		PART_NUMBER_KEY,
							   partDescription,	PART_NAME_KEY,
							   nil ];
			
			[allPartRecords addObject:partRecord];					
		}
		
		// Update data
		[self setTableDataSource:allPartRecords];
		[categoryComboBox setStringValue:newCategory];
	}
	else
	{	// The user entered an invalid category; display no list.
		[self setTableDataSource:[NSMutableArray array]];
	}
	
	[self setConstraints];
	
	// finally, assign instance variable
	[newCategory retain];
	[self->selectedCategory release];
	self->selectedCategory = newCategory;
	
	return success;
	
}//end loadCategory:


//========== setPartCatalog: ===================================================
//
// Purpose:		A new part catalog has been read out of the LDraw folder. Now we 
//				set up the data sources to reflect it.
//
//==============================================================================
- (void) setPartLibrary:(PartLibrary *)partLibraryIn
{
	NSArray         *categories         = nil;
	NSString        *allCategoriesItem  = nil;
	NSString		*favoritesItem		= nil;
	NSMutableArray  *fullCategoryList   = [NSMutableArray array];
	
	// Assign ivar
	self->partLibrary = partLibraryIn;
	
	
	// Get all the categories and sort them.
	categories = [partLibrary categories];
	categories = [categories sortedArrayUsingSelector:@selector(compare:)];
	
	allCategoriesItem	= NSLocalizedString(@"AllCategories", nil);
	favoritesItem		= NSLocalizedString(@"FavoritesCategory", nil);
	
	//Assemble the complete category list, which also includes an item for 
	// displaying every category.
	[fullCategoryList addObject:allCategoriesItem];
	[fullCategoryList addObject:favoritesItem];
	[fullCategoryList addObjectsFromArray:categories]; //add all the actual categories
	
	//and now we have a complete list.
	[self setCategoryList:fullCategoryList];
	
	//And set the current category to show everything
	[self loadCategory:allCategoriesItem];
	
}//end setPartCatalog:


//========== setCategoryList: ==================================================
//
// Purpose:		Sets the complete list of all the categories avaibaled; used as 
//				the category combo box's data source.
//
//==============================================================================
- (void) setCategoryList:(NSArray *)newCategoryList
{
	//swap the variable
	[newCategoryList retain];
	[categoryList release];
	
	categoryList = newCategoryList;
	
	//Update the category chooser
	[categoryComboBox reloadData];
	
}//end setCategoryList


//========== setTableDataSource: ===============================================
//
// Purpose:		The table displays a list of the parts in a category. The array
//				here is an array of part records containg names and 
//				descriptions.
//
//				The new parts are then displayed in the table.
//
//==============================================================================
- (void) setTableDataSource:(NSMutableArray *)allPartRecords
{
	NSString        *originalSelectedPartName   = [self selectedPartName];
	NSUInteger      newSelectedIndex            = NSNotFound;

	[allPartRecords sortUsingDescriptors:[partsTable sortDescriptors]];
	
	// Swap out the variable
	[allPartRecords retain];
	[self->tableDataSource release];
	
	self->tableDataSource = allPartRecords;
	[partsTable reloadData];
	
	// Attempt to restore the original selection (happens especially if clearing 
	// the search field) 
	newSelectedIndex = [self indexOfPartNamed:originalSelectedPartName];
	if(newSelectedIndex == NSNotFound)
		newSelectedIndex = 0;
	
	// Scroll to the new selection
	[partsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newSelectedIndex] byExtendingSelection:NO];
	[partsTable scrollRowToVisible:newSelectedIndex];
	
}//end setTableDataSource


#pragma mark -
#pragma mark ACTIONS
#pragma mark -


//========== addPartClicked: ===================================================
//
// Purpose:		Need to add the selected part to whoever is interested in that. 
//				This is dispatched as a nil-targeted action, and will most 
//				likely be picked up by the foremost document.
//
//==============================================================================
- (IBAction) addPartClicked:(id)sender
{
	//anyone who implements this message will know what to do.
	[NSApp sendAction:@selector(insertLDrawPart:) to:nil from:self];

}//end addPartClicked:


//========== addFavoriteClicked: ===============================================
//
// Purpose:		Adds the currently-selected part to the library's list of 
//				"favorite" parts. It seems users like to have a list like this. 
//
//==============================================================================
- (IBAction) addFavoriteClicked:(id)sender
{
	NSString *selectedPartName = [self selectedPartName];
	
	[self->partLibrary addPartNameToFavorites:selectedPartName];
	
	[self setConstraints];

}//end addFavoriteClicked:


//========== categoryComboBoxChanged: ==========================================
//
// Purpose:		A new category has been selected.
//
//==============================================================================
- (IBAction) categoryComboBoxChanged:(id)sender
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSString		*newCategory	= [sender stringValue];
	BOOL			 success		= NO;
	
	// Only set the category if we're actually changing it. The reason is that 
	// loading a category will cause the current selection to change. But this 
	// action is also sent whenever focus leaves the category field, even when 
	// that's because the user just attempted to change the part selection! 
	if([newCategory isEqualToString:[self category]] == NO)
	{
		//Clear the search field
		[self->searchField setStringValue:@""];
		
		success = [self loadCategory:newCategory];
		[self syncSelectionAndPartDisplayed];
		
		if(success == YES)
			[userDefaults setObject:newCategory forKey:PART_BROWSER_PREVIOUS_CATEGORY];
	}

}//end categoryComboBoxChanged:


//========== doubleClickedInPartTable: =========================================
//
// Purpose:		We mean this to insert a part.
//
//==============================================================================
- (void) doubleClickedInPartTable:(id)sender
{
	[self addPartClicked:sender];
	
}//end doubleClickedInPartTable:


//========== removeFavoriteClicked: ============================================
//
// Purpose:		Removes the currently-selected part from the library's 
//				"favorites" list, if it happens to be in it. 
//
//==============================================================================
- (IBAction) removeFavoriteClicked:(id)sender
{
	NSString *selectedPartName = [self selectedPartName];
	
	[self->partLibrary removePartNameFromFavorites:selectedPartName];
	
	[self setConstraints];
	
}//end removeFavoriteClicked:


//========== searchFieldChanged: ===============================================
//
// Purpose:		The search string has been changed. We do a search on the entire 
//				part library.
//
//==============================================================================
- (IBAction) searchFieldChanged:(id)sender
{
	NSString        *searchString   = [self->searchField stringValue];
	NSMutableArray  *filteredParts  = nil;

	// Reload all available parts
	[self loadCategory:NSLocalizedString(@"AllCategories", nil)];
	
	// Re-filter the records
	filteredParts = [self filterPartRecords:self->tableDataSource bySearchString:searchString];
	[self setTableDataSource:filteredParts];
	
	[self syncSelectionAndPartDisplayed];
	[self setConstraints];

}//end searchFieldChanged:


#pragma mark -
#pragma mark DATA SOURCES
#pragma mark -

#pragma mark Combo Box

//**** NSComboBoxDataSource ****
//========== numberOfItemsInComboBox: ==========================================
//
// Purpose:		Returns the number of browsable categories.
//
//==============================================================================
- (NSInteger) numberOfItemsInComboBox:(NSComboBox *)comboBox
{
	return [categoryList count];
	
}//end numberOfItemsInComboBox:


//**** NSComboBoxDataSource ****
//========== comboBox:objectValueForItemAtIndex: ===============================
//
// Purpose:		Brings the window on screen.
//
//==============================================================================
- (id) comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
	return [categoryList objectAtIndex:index];
	
}//end comboBox:objectValueForItemAtIndex:


//**** NSComboBoxDataSource ****
//========== comboBox:completedString: =========================================
//
// Purpose:		Do a lazy string completion; no capital letters required.
//
//==============================================================================
- (NSString *) comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString
{
	NSString            *currentCategory    = nil;
	BOOL                foundMatch          = NO;
	NSComparisonResult  comparisonResult    = NSOrderedSame;
	NSString            *completedString    = nil;
	NSUInteger          counter             = 0;
	
	//Search through all available categories, trying to find one with a 
	// case-insensitive prefix of uncompletedString
	while(counter < [categoryList count] && foundMatch == NO)
	{
		currentCategory = [categoryList objectAtIndex:counter];
		
		//See if the current category starts with the string we are looking for.
		comparisonResult = 
			[currentCategory compare:uncompletedString
							 options:NSCaseInsensitiveSearch
							   range:NSMakeRange(0, [uncompletedString length]) 
							   //only compare on the relevant part of the string
				];
		if(comparisonResult == NSOrderedSame)
			foundMatch = YES;
			
		counter++;
	}//end while
	
	if(foundMatch == YES)
		completedString = currentCategory;
	else
		completedString = uncompletedString; //no completion possible
	
	return completedString;
	
}//end comboBox:completedString:


#pragma mark Table

//**** NSTableDataSource ****
//========== numberOfRowsInTableView: ==========================================
//
// Purpose:		Should return the number of parts in the category currently 
//				being browsed.
//
//==============================================================================
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableDataSource count];
	
}//end numberOfRowsInTableView


//**** NSTableDataSource ****
//========== tableView:objectValueForTableColumn:row: ===============================
//
// Purpose:		Displays information for the part in the record.
//
//==============================================================================
- (id)				tableView:(NSTableView *)tableView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
						  row:(NSInteger)rowIndex
{
	NSDictionary	*partRecord			= [self->tableDataSource objectAtIndex:rowIndex];
	NSString		*columnIdentifier	= [tableColumn identifier];
	
	NSString		*cellValue			= [partRecord objectForKey:columnIdentifier];
	
	//If it's a part, get rid of the file extension on its name.
	if([columnIdentifier isEqualToString:PART_NUMBER_KEY])
		cellValue = [cellValue stringByDeletingPathExtension];
	
	return cellValue;
	
}//end tableView:objectValueForTableColumn:row:


//**** NSTableDataSource ****
//========== tableView:sortDescriptorsDidChange: ===============================
//
// Purpose:		Resort the table elements.
//
//==============================================================================
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *newDescriptors = [tableView sortDescriptors];
	[tableDataSource sortUsingDescriptors:newDescriptors];
	[tableView reloadData];
	
}//end tableView:sortDescriptorsDidChange:


#pragma mark -

//**** NSTableDataSource ****
//========== tableView:writeRowsWithIndexes:toPasteboard: ======================
//
// Purpose:		It's time for drag-and-drop parts!
//
//				This method adds LDraw parts to the pasteboard.
//
// Notes:		We can have but one part selected in the browser, so the rows 
//				parameter is irrelevant. 
//
//==============================================================================
- (BOOL)     tableView:(NSTableView *)aTableView
  writeRowsWithIndexes:(NSIndexSet *)rowIndexes
		  toPasteboard:(NSPasteboard *)pasteboard
{
	BOOL	success = NO;
	
	// Select the dragged row (it may not have been selected), then write it to 
	// the pasteboard. 
	[self->partsTable selectRowIndexes:rowIndexes byExtendingSelection:NO];
	success = [self writeSelectedPartToPasteboard:pasteboard];
	
	return success;
		
}//end tableView:writeRowsWithIndexes:toPasteboard:


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

#pragma mark LDrawGLView

//========== LDrawGLView:writeDirectivesToPasteboard:asCopy: ===================
//
// Purpose:		Begin a drag-and-drop part insertion initiated in the directive 
//				view. 
//
//==============================================================================
- (BOOL)         LDrawGLView:(LDrawGLView *)glView
 writeDirectivesToPasteboard:(NSPasteboard *)pasteboard
					  asCopy:(BOOL)copyFlag
{
	BOOL	success = [self writeSelectedPartToPasteboard:pasteboard];
	
	return success;
	
}//end LDrawGLView:writeDirectivesToPasteboard:asCopy:


#pragma mark -
#pragma mark NSTableView

//**** NSTableView ****
//========== tableViewSelectionDidChange: ======================================
//
// Purpose:		A new part has been selected.
//
//==============================================================================
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
	NSInteger       newRow          = [self->partsTable selectedRow];
	
	//Redisplay preview.
	[self syncSelectionAndPartDisplayed];
	[self setConstraints];
	
	//save for posterity.
	if(newRow != -1)
	{
		[userDefaults setInteger:newRow forKey:PART_BROWSER_PREVIOUS_SELECTED_ROW];
	}
	
}//end tableViewSelectionDidChange


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== sharedPartCatalogDidChange: =======================================
//
// Purpose:		The application has loaded a new part catalog from the LDraw 
//				folder. Data sources must be updated accordingly.
//
//==============================================================================
- (void) sharedPartCatalogDidChange:(NSNotification *)notification
{
	PartLibrary *newLibrary         = [notification object];
	NSString    *currentCategory    = [self->categoryComboBox stringValue];
	NSInteger   selectedRow         = [self->partsTable selectedRow];
	
	[self setPartLibrary:newLibrary];
	
	// Restore the original selection (setting the part library wipes it out)
	[self loadCategory:currentCategory];
	[partsTable scrollRowToVisible:selectedRow];
	[partsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow]
			byExtendingSelection:NO];
	[self syncSelectionAndPartDisplayed];
	
}//end sharedPartCatalogDidChange:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== filterPartRecords:bySearchString: =================================
//
// Purpose:		Searches partRecords for all records containing searchString; 
//				returns the matching records. The search will be conducted on 
//				both the part numbers and descriptions.
//
// Returns:		An array with all matching parts, or an empty array if no parts 
//				match.
//
// Notes:		The nasty problem is that LDraw names are formed so that they 
//				line up nicely in a monospaced font. Thus we have names like 
//				"Brick  2 x  4" (note extra spaces!). I sidestep the problem by 
//				stripping all the spaces from the search and find strings. It's 
//				still lame, but probably okay for most uses.
//
//				Tiger has fantabulous search predicates that would reduce a 
//				hefty hunk of this code to a 1-liner AND be whitespace neutral 
//				too. But I don't have Tiger, so instead I'm going for the 
//				cheeseball approach.  
//
//==============================================================================
- (NSMutableArray *) filterPartRecords:(NSArray *)partRecords
						bySearchString:(NSString *)searchString
{
	NSDictionary    *record                 = nil;
	NSUInteger      counter                 = 0;
	NSString        *partNumber             = nil;
	NSString        *partDescription        = nil;
	NSString        *partSansWhitespace     = nil;
	NSMutableArray  *matchingParts          = nil;
	NSString        *searchSansWhitespace   = [searchString stringByRemovingWhitespace];
	
	if([searchString length] == 0)
	{
		//Everybody's a winner here.
		matchingParts = [NSMutableArray arrayWithArray:partRecords];
	}
	else
	{
		matchingParts = [NSMutableArray array];
		
		// Search through all the given records and try to find matches on the 
		// search string. But search part names whitespace-neutral so as not to 
		// be thrown off by goofy name spacing. 
		for(counter = 0; counter < [partRecords count]; counter++)
		{
			record				= [partRecords objectAtIndex:counter];
			partNumber			= [record objectForKey:PART_NUMBER_KEY];
			partDescription		= [record objectForKey:PART_NAME_KEY];
			partSansWhitespace	= [partDescription stringByRemovingWhitespace];
			
			if(		[partNumber			containsString:searchString options:NSCaseInsensitiveSearch]
				||	[partSansWhitespace	containsString:searchSansWhitespace options:NSCaseInsensitiveSearch] )
			{
				[matchingParts addObject:record];
			}
		}
	}//end else we have to search
	
	
	return matchingParts;
	
}//end filterPartRecords:bySearchString:


//========== indexOfPartNamed: =================================================
//
// Purpose:		Returns the index of the part with the given name in the current 
//				found set. 
//
//				Returns NSNotFound if the part is not a member of the 
//				currently-displayed part list. 
//
//==============================================================================
- (NSUInteger) indexOfPartNamed:(NSString *)searchName
{
	NSDictionary    *partRecord     = nil;
	NSString        *partName       = nil;
	NSUInteger      currentIndex    = 0;
	NSUInteger      foundIndex      = NSNotFound;

	// Find a part record with the given name
	for(partRecord in self->tableDataSource)
	{
		partName = [partRecord objectForKey:PART_NUMBER_KEY];
		if([partName isEqualToString:searchName])
		{
			foundIndex = currentIndex;
			break;
		}
		currentIndex++;
	}
	
	// In 10.6, we can do something much fancier!
//	foundIndex = [self->tableDataSource indexOfObjectPassingTest:
//						^(id partRecord, NSUInteger idx, BOOL *stop)
//						{
//							NSString    *partName   = [partRecord objectForKey:PART_NUMBER_KEY];
//							BOOL        isMatch     = [partName isEqualToString:searchName];
//							return isMatch;
//						} ];
	
	return foundIndex;
	
}//end indexOfPartNamed:


//========== setConstraints ====================================================
//
// Purpose:		Sets the enabled or disabled state of controls in the part 
//				browser. 
//
//==============================================================================
- (void) setConstraints
{
	NSString    *selectedPart       = [self selectedPartName];
	NSArray     *favorites          = [self->partLibrary favoritePartNames];
	BOOL        partIsInFavorites   = NO;
	
	if(		selectedPart != nil
	   &&	[favorites containsObject:selectedPart] )
	{
		partIsInFavorites = YES;
	}
	
	
	//---------- Set constraints -----------------------------------------------
	
	[self->insertButton				setEnabled:(selectedPart != nil)];
	[self->addRemoveFavoriteButton	setEnabled:(selectedPart != nil)];
	
	// Add/Remove button image/action
	if(partIsInFavorites == YES)
	{
		[self->addRemoveFavoriteButton	setAction:@selector(removeFavoriteClicked:)];
		[self->addRemoveFavoriteButton	setImage:[NSImage imageNamed:@"FavoriteRemove"]];
	}
	else
	{
		[self->addRemoveFavoriteButton	setAction:@selector(addFavoriteClicked:)];
		[self->addRemoveFavoriteButton	setImage:[NSImage imageNamed:@"FavoriteAdd"]];
	}
	
	// Hide inapplicable menu items.
	[[self->contextualMenu itemWithTag:partBrowserAddFavoriteTag]		setHidden:(partIsInFavorites == YES)];
	[[self->contextualMenu itemWithTag:partBrowserRemoveFavoriteTag]	setHidden:(partIsInFavorites == NO)];
	
}//end setConstraints


//========== syncSelectionAndPartDisplayed =====================================
//
// Purpose:		Makes the current part displayed match the part selected in the 
//				table.
//
//==============================================================================
- (void) syncSelectionAndPartDisplayed
{
	NSString    *selectedPartName   = [self selectedPartName];
	LDrawPart   *newPart            = nil;
		
	if(selectedPartName != nil)
	{
		// Not this simple anymore. We have to make sure to draw the optimized 
		// vertexes. The easiest way to do that is to create a part referencing 
		// the model. 
//		modelToView = [self->partLibrary modelForName:selectedPartName];

		newPart		= [[[LDrawPart alloc] init] autorelease];
		
		//Set up the part attributes
		[newPart setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]];
		[newPart setDisplayName:selectedPartName];
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		[newPart optimizeOpenGL];
	}
	[partPreview setLDrawDirective:newPart];
	
}//end syncSelectionAndPartDisplayed


//========== writeSelectedPartToPasteboard: ====================================
//
// Purpose:		Writes the current part-browser selection onto the pasteboard.
//
//==============================================================================
- (BOOL) writeSelectedPartToPasteboard:(NSPasteboard *)pasteboard
{
	NSMutableArray	*archivedParts		= [NSMutableArray array];
	NSString		*partName			= [self selectedPartName];
	LDrawPart		*newPart			= nil;
	NSData			*partData			= nil;
	LDrawColor		*selectedColor		= [[LDrawColorPanel sharedColorPanel] LDrawColor];
	BOOL			 success			= NO;
	
	//We got a part; let's add it!
	if(partName != nil)
	{
		newPart		= [[[LDrawPart alloc] init] autorelease];
		
		//Set up the part attributes
		[newPart setLDrawColor:selectedColor];
		[newPart setDisplayName:partName];
		
		partData	= [NSKeyedArchiver archivedDataWithRootObject:newPart];
		
		[archivedParts addObject:partData];
		
		// Set up pasteboard
		[pasteboard declareTypes:[NSArray arrayWithObjects:LDrawDraggingPboardType, LDrawDraggingIsUninitializedPboardType, nil] owner:self];
		
		[pasteboard setPropertyList:archivedParts
							forType:LDrawDraggingPboardType];
		
		[pasteboard setPropertyList:[NSNumber numberWithBool:YES]
							forType:LDrawDraggingIsUninitializedPboardType];
		
		success = YES;
	}
	
	return success;
	
}//end writeSelectedPartToPasteboard:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		It's AppKit, in the Library, with the Lead Pipe!!!
//
//==============================================================================
- (void) dealloc
{
	//Remove notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	//Release data
	[categoryList		release];
	[tableDataSource	release];
	[contextualMenu		release];
	
	[super dealloc];
	
}//end dealloc


@end
