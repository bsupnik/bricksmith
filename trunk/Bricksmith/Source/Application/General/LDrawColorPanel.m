//==============================================================================
//
// File:		LDrawColorPanel.m
//
// Purpose:		Color-picker for Bricksmith. The color panel is used to browse, 
//				select, and apply LDraw colors. The colors are presented by 
//				both swatch and name.
//
//  Created by Allen Smith on 2/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawColorPanel.h"

#import "ColorLibrary.h"
#import "LDrawColor.h"
#import "LDrawColorBar.h"
#import "LDrawColorCell.h"
#import "LDrawColorWell.h"
#import "MacLDraw.h"
#import "StringCategory.h"

typedef enum
{
	MaterialTypeAll			= 0,
	MaterialTypeSolid		= 1,
	MaterialTypeTransparent = 2,
	MaterialTypeChrome		= 3,
	MaterialTypePearlescent	= 4,
	MaterialTypeRubber		= 5,
	MaterialTypeMetal		= 6,
	MaterialTypeOther		= 7,
	
} MaterialPopUpTagT;

#define COLOR_SORT_DESCRIPTORS_KEY @"ColorTable Sort Ordering"

@implementation LDrawColorPanel

//There is supposed to be only one of these.
LDrawColorPanel *sharedColorPanel = nil;


//========== awakeFromNib ======================================================
//
// Purpose:		Brings the LDraw color panel to life.
//
// Note:		Please note that this method is called BEFORE most class
//				initialization code. For instance, awake is called before the 
//				table's data is even loaded, so you can't sort the data here.
//
//==============================================================================
- (void) awakeFromNib
{
	LDrawColorCell	*colorCell		= [[[LDrawColorCell alloc] init] autorelease];
	NSTableColumn	*colorColumn	= [colorTable tableColumnWithIdentifier:@"colorCode"];
	
	[colorColumn setDataCell:colorCell];
	
	[materialPopUpButton selectItemWithTag:MaterialTypeAll];
	
	//Remember, this method is called twice for an LDrawColorPanel; the first time 
	// is for the File's Owner, which is promptly overwritten.
	
}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- sharedColorPanel ----------------------------------------[static]--
//
// Purpose:		Returns the global instance of the color panel.
//
//------------------------------------------------------------------------------
+ (LDrawColorPanel *) sharedColorPanel
{
	if(sharedColorPanel == nil)
		sharedColorPanel = [[LDrawColorPanel alloc] init];
	
	return sharedColorPanel;
	
}//end sharedColorPanel


//========== init ==============================================================
//
// Purpose:		Brings the LDraw color panel to life.
//
//==============================================================================
- (id) init
{
	id              oldself         = [super init];
	ColorLibrary    *colorLibrary   = [ColorLibrary sharedColorLibrary];
	NSArray         *colorList      = [colorLibrary colors];

	[NSBundle loadNibNamed:@"ColorPanel" owner:self];
	
	self = colorPanel; //this don't look good, but it works.
						//this takes the place of calling [super init]
						// Note that connections in the Nib file must be made 
						// to the colorPanel, not to the File's Owner!
						
	//While the data is being loaded in the table, a color will automatically 
	// be selected. We do not want this color-selection to generate a 
	// changeColor: message, so we turn on this flag.
	updatingToReflectFile = YES;
	
		// Set the list of colors to display.
		[self->colorListController setContent:colorList];
		[self->colorListController addObserver:self forKeyPath:@"selectedObjects" options:kNilOptions context:NULL];
		[self->colorListController addObserver:self forKeyPath:@"sortDescriptors" options:kNilOptions context:NULL];
		
		[self loadInitialSortDescriptors];
		
		[self setLDrawColor:[colorLibrary colorForCode:LDrawRed]];
	updatingToReflectFile = NO;
	
	[self setDelegate:self];
	[self setWorksWhenModal:YES];
	[self setLevel:NSStatusWindowLevel];
	[self setBecomesKeyOnlyIfNeeded:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
	
	[oldself release];
	
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== LDrawColor ========================================================
//
// Purpose:		Returns the color code of the panel's currently-selected color.
//
//==============================================================================
- (LDrawColor *) LDrawColor
{
	NSArray		*selection			= [self->colorListController selectedObjects];
	LDrawColor	*selectedColor		= nil;
	
	//It is possible there are no rows selected, if a search has limited the 
	// color list out of existence.
	if([selection count] > 0)
	{
		selectedColor = [selection objectAtIndex:0];
	}
	//Just return whatever was last selected.
	else
	{
		selectedColor = [colorBar LDrawColor];
	}
	
	return selectedColor;
	
}//end LDrawColor


//========== setLDrawColor: ====================================================
//
// Purpose:		Chooses newColor in the color table. As long as newColor is a 
//				valid color, this method will select it, even if it has to 
//				change the found set.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *)newColor
{
	//Try to find the color we are after in the current list.
	NSInteger rowToSelect = [self indexOfColor:newColor]; //will be the row index for the color we want.
	
	if(rowToSelect == NSNotFound)
	{
		//It wasn't in the currently-displayed list. Search the master list.
		[self->colorListController setFilterPredicate:nil];
		rowToSelect = [self indexOfColor:newColor];
	}
	
	//We'd better have found it by now!
	if(rowToSelect != NSNotFound)
	{
		[self->colorListController setSelectionIndex:rowToSelect];
		[colorBar setLDrawColor:newColor];
	}
	
}//end setLDrawColor:

#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== focusSearchField: =================================================
//
// Purpose:		Makes the search field the first responder.
//
// Notes:		This is to pacify those who wish to type in color codes rather 
//				than clicking them. Once the search field is made key by some 
//				keyboard combination, the color code can be typed in. 
//
//==============================================================================
- (void) focusSearchField:(id)sender
{
	[self makeFirstResponder:self->searchField];
	
}//end focusSearchField:


//========== materialPopUpButtonChanged: =======================================
//
// Purpose:		Chose a different material filter for the color search.
//
//==============================================================================
- (void) materialPopUpButtonChanged:(id)sender
{
	[self updateColorFilter];
}

//========== orderOut: =========================================================
//
// Purpose:		The color panel is being closed. If there is an active color 
//				well, it needs to deactivate.
//
//==============================================================================
- (void) orderOut:(id)sender
{
	//deactivate active color well.
	if([LDrawColorWell activeColorWell] != nil)
		[LDrawColorWell setActiveColorWell:nil];
	
	[super orderOut:sender];
	
}//end orderOut:


//========== sendAction ========================================================
//
// Purpose:		Dispatches the change-color action as appropriate. If there is 
//				an active color well, it will be the sole recipient of the color 
//				change. Otherwise, a nil-targeted -changeLDrawColor: message 
//				will be dispatched.
//
//==============================================================================
- (void) sendAction
{
	LDrawColorWell *activeColorWell = [LDrawColorWell activeColorWell];

	if(activeColorWell != nil)
	{
		//we have an active color well, so it is the only one whose color should 
		// change.
		[activeColorWell changeLDrawColorWell:self];
	}
	else
	{
		//Well, our color has changed. Presumably, somebody wants to update a 
		// part color in response to this momentous event. But who knows who? So 
		// we just send this message toddling along, and let whoever want it get 
		// it.
		//
		//But--if this notification is coming in response to selecting a 
		// different part in the file, then our color did not *really* change; 
		// we are just displaying a new one. In that case, we don't want any 
		// parts changing colors.
		if(updatingToReflectFile == NO)
		{
			[NSApp sendAction:@selector(changeLDrawColor:)
						   to:nil //just send it somewhere!
						 from:self]; //it's from us (we'll be the sender)
			
		}
		
		//Clients that are tracking the global color state always need to know 
		// about the current color, though!
		[[NSNotificationCenter defaultCenter]
							postNotificationName:LDrawColorDidChangeNotification
										  object:[self LDrawColor] ];
	}

}//end sendAction


//========== searchFieldChanged: ===============================================
//
// Purpose:		The user has changed the search string. We need to research 
//				the list of colors for those whose names match the new string.
//
// Notes:		For the sake of concise code, I do not bother to optimize this 
//				search. After all, we only have 64 colors; that's no time.
//
//==============================================================================
- (IBAction) searchFieldChanged:(id)sender
{
	[self updateColorFilter];
	
}//end searchFieldChanged:


//========== updateSelectionWithObjects: =======================================
//
// Purpose:		Updates the selected color based on the colors in 
//				selectedObjects, which should be a list of LDrawDirectives 
//				which have been selected in a document window.
//
//				If two or more directives have different colors, then the color 
//				of the last object selected is displayed.
//
//				If there are no colorable directives in selectedObjects, then 
//				the color selection remains unchanged.
//
//==============================================================================
- (void) updateSelectionWithObjects:(NSArray *)selectedObjects
{
	id          currentObject   = [selectedObjects lastObject];
	LDrawColor  *objectColor    = [self LDrawColor];
	
	//Find the color code of the last object selected. I suppose this is rather 
	// tacky to do such a simple search, but I would prefer not to write the 
	// interface required to denote multiple selection.
	if(currentObject != nil)
	{
		if([currentObject conformsToProtocol:@protocol(LDrawColorable)])
			objectColor = [currentObject LDrawColor];
	}
	
	updatingToReflectFile = YES;
		[self setLDrawColor:objectColor];
	updatingToReflectFile = NO;
	
}//end updateSelectionWithObjects:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== indexOfColor: =================================================
//
// Purpose:		Returns the row index of colorCodeSought in the panel's table, 
//				or NSNotFound if colorCodeSought is not displayed. 
//
//==============================================================================
- (NSInteger) indexOfColor:(LDrawColor *)colorSought
{
	NSArray     *visibleColors  = [self->colorListController arrangedObjects];
	NSInteger   numberColors    = [visibleColors count];
	LDrawColor  *currentColor   = nil;
	LDrawColorT currentCode     = LDrawColorBogus;
	LDrawColorT	colorCodeSought = [colorSought colorCode];
	NSInteger   rowToSelect     = NSNotFound; //will be the row index for the color we want.
	NSInteger   counter         = 0;
	
	//Search through all the colors in the current color set and see if the 
	// one we are after is in there. A brute force search.
	for(counter = 0; counter < numberColors && rowToSelect == NSNotFound; counter++)
	{
		currentColor	= [visibleColors objectAtIndex:counter];
		currentCode		= [currentColor colorCode];
		
		if(currentCode == colorCodeSought)
			rowToSelect = counter;
	}
	
	return rowToSelect;
	
}//end indexOfColor:


//========== loadInitialSortDescriptors ========================================
//
// Purpose:		Reads the last-used sort descriptors from preferences and 
//				applies them to the color list. 
//
// Notes:		Once moved entirely to Leopard, we can dispense with some of 
//				this and bind directly to the data using 
//				NSKeyedUnarchiveFromData. That would also be an easy class to 
//				replicate on Tiger, but I'm not feeling like I need it all that 
//				much. 
//
//==============================================================================
- (void) loadInitialSortDescriptors
{
	NSData				*savedDescriptorData	= nil;
	NSArray				*savedDescriptors		= nil;
	NSSortDescriptor	*initialDescriptor		= nil;
	NSUserDefaults		*userDefaults			= [NSUserDefaults standardUserDefaults];
	
	// Get the object from preferences.
	savedDescriptorData = [userDefaults objectForKey:COLOR_SORT_DESCRIPTORS_KEY];
	if(savedDescriptorData != nil)
		savedDescriptors = [NSKeyedUnarchiver unarchiveObjectWithData:savedDescriptorData];
	
	// Regenerate them if needed
	if(savedDescriptors == nil)
	{
		initialDescriptor	= [[self->colorTable tableColumnWithIdentifier:@"colorCode"] sortDescriptorPrototype];
		savedDescriptors	= [NSArray arrayWithObject:initialDescriptor];
	}
	
	// and sort.
	[self->colorListController setSortDescriptors:savedDescriptors];

}//end loadInitialSortDescriptors


//========== predicateForSearchString: =========================================
//
// Purpose:		Returns a search predicate suitable for finding colors based on 
//				the given search string. 
//
//				If the search string consists entirely of numerals, the 
//				predicate will search for colors having that exact integer code. 
//
//==============================================================================
- (NSPredicate *) predicateForSearchString:(NSString *)searchString
								  material:(MaterialPopUpTagT)material
{
	NSString		*keywordFormat		= nil;
	NSArray 		*keywordArguments	= nil;
	NSString		*materialFormat 	= nil;
	NSArray 		*materialArguments	= nil;
	NSMutableString *predicateFormat	= nil;
	NSMutableArray	*predicateArguments = nil;
	NSPredicate 	*searchPredicate	= nil;
	BOOL			searchByCode		= NO; //color name search by default.
	NSScanner		*digitScanner		= nil;
	NSInteger		colorCode			= 0;
	
	// If there is no string, then clear the search predicate (find all).
	if([searchString length] == 0)
		searchPredicate = nil;
	else
	{
		// Find out whether this search is intended to be based on the LDraw 
		// code. If the search string can be parsed into an integer, we'll 
		// assume this is a color-code search. Otherwise, it will be a name 
		// search. 
		digitScanner	= [NSScanner scannerWithString:searchString];
		searchByCode	= [digitScanner scanInteger:&colorCode];
		
		// If it is an LDraw code search, try to find a color code equal to the 
		// search number entered. 
		if(searchByCode == YES)
		{
			keywordFormat		= @"%K == %@";
			keywordArguments	= [NSArray arrayWithObjects:NSStringFromSelector(@selector(colorCode)), @(colorCode), nil];
		}
		else
		{
			// This is a search based on color names. If we can find the search 
			// string in any component of the color string, we consider it a 
			// match. 
			keywordFormat		= @"%K CONTAINS[cd] %@";
			keywordArguments	= [NSArray arrayWithObjects:NSStringFromSelector(@selector(localizedName)), searchString, nil];
		}
	}
	
	switch(material)
	{
		case MaterialTypeAll:
			// nothing
			break;
			
		case MaterialTypeSolid:
			materialFormat = @"(%K == %@) AND (%K == 1.0)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialNone), NSStringFromSelector(@selector(alpha)), nil];
			break;
			
		case MaterialTypeTransparent:
			materialFormat = @"(%K == %@) AND (%K < 1.0)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialNone), NSStringFromSelector(@selector(alpha)), nil];
			break;
			
		case MaterialTypeChrome:
			materialFormat = @"(%K == %@)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialChrome), nil];
			break;
		
		case MaterialTypePearlescent:
			materialFormat = @"(%K == %@)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialPearlescent), nil];
			break;
			
		case MaterialTypeRubber:
			materialFormat = @"(%K == %@)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialRubber), nil];
			break;
		
		case MaterialTypeMetal:
			materialFormat = @"(%K == %@) OR (%K == %@)";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialMetal), NSStringFromSelector(@selector(material)), @(LDrawColorMaterialMatteMetallic), nil];
			break;
		
		case MaterialTypeOther:
			materialFormat = @"((%K == %@) OR (%K == %@) OR (%K == %@))";
			materialArguments = [NSArray arrayWithObjects:NSStringFromSelector(@selector(material)), @(LDrawColorMaterialCustom),
								 NSStringFromSelector(@selector(colorCode)), @(LDrawCurrentColor),
								 NSStringFromSelector(@selector(colorCode)), @(LDrawEdgeColor),
								 nil];
			break;
	}
	
	if(keywordFormat || materialFormat)
	{
		predicateFormat 	= [NSMutableString string];
		predicateArguments	= [NSMutableArray array];
	}
	
	if(keywordFormat)
	{
		[predicateFormat appendString:keywordFormat];
		[predicateArguments addObjectsFromArray:keywordArguments];
	}
	
	if(materialFormat)
	{
		if([predicateFormat length])
			[predicateFormat appendString:@"AND "];
		
		[predicateFormat appendFormat:@"(%@)", materialFormat];
		[predicateArguments addObjectsFromArray:materialArguments];
	}
	
	if(predicateFormat)
	{
		searchPredicate = [NSPredicate predicateWithFormat:predicateFormat argumentArray:predicateArguments];
	}
	
	return searchPredicate;
	
}//end predicateForSearchString:


//========== updateColorFilter =================================================
//
// Purpose:		Searches the global color list for colors matching the selected 
//				parameters.
//
//==============================================================================
- (void) updateColorFilter
{
	NSString			*searchString				= [searchField stringValue];
	MaterialPopUpTagT	materialType				= [[materialPopUpButton selectedItem] tag];
	NSPredicate 		*searchPredicate			= nil;
	LDrawColor			*currentColor				= [self LDrawColor];
	NSInteger			indexOfPreviousSelection	= 0;
	
	searchPredicate = [self predicateForSearchString:searchString material:materialType];
	
	//Update the table with our results.
	[self->colorListController setFilterPredicate:searchPredicate];
	
	// The array controller will automatically maintain the selection if it can.
	// But if it can't, we need to come up a reasonable new answer.
	indexOfPreviousSelection = [self indexOfColor:currentColor];
	// If the previous color is no longer in the list, what should we do? I have
	// chosen to automatically select the first color, since I don't want to
	// introduce the UI confusion of empty selection.
	if(indexOfPreviousSelection == NSNotFound)
	{
		[self->colorListController setSelectionIndex:0];
	}
}//end updateColorFilter


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//========== observeValueForKeyPath:ofObject:change:context: ===================
//
// Purpose:		We need to know when our color selection changes, so we use 
//				Key-Value Observing. 
//
//==============================================================================
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	// Selected color has changed. Need to update everything to indicate that a 
	// new color was selected. 
	if([keyPath isEqualToString:@"selectedObjects"])
	{
		if([[self->colorListController selectedObjects] count] > 0)
		{
			//Update internal information.
			[self->colorBar setLDrawColor:[self LDrawColor]];
			
			[self sendAction];
		}
	}
	
	// Sort descriptors changed; save in preferences.
	// Once we are Leopard-only, we can dispense with this and just use the 
	// NSKeyedUnarchiveFromData transformer. 
	else if([keyPath isEqualToString:@"sortDescriptors"])
	{
		NSArray			*newDescriptors			= [self->colorListController sortDescriptors];;
		NSData			*savedDescriptorData	= [NSKeyedArchiver archivedDataWithRootObject:newDescriptors];
		NSUserDefaults	*userDefaults			= [NSUserDefaults standardUserDefaults];
		
		// Set the object in preferences.
		[userDefaults setObject:savedDescriptorData forKey:COLOR_SORT_DESCRIPTORS_KEY];
	}
	
}//end observeValueForKeyPath:ofObject:change:context:


//**** NSWindow ****
//========== windowWillReturnUndoManager: ======================================
//
// Purpose:		Allows Undo to keep working transparently through this window by 
//				allowing the undo request to forward on to the active document.
//
//==============================================================================
- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	
	return [currentDocument undoManager];
	
}//end windowWillReturnUndoManager:


//========== applicationWillTerminate: =========================================
//
// Purpose:		It seems we have some memory to mange. 
//
//==============================================================================
- (void) applicationWillTerminate:(NSNotification *)notification
{
	[self release];
	
}//end applicationWillTerminate:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The Roll has been called up Yonder, and we will be there.
//
//==============================================================================
- (void) dealloc
{
	[colorListController removeObserver:self forKeyPath:@"selectedObjects"];
	[colorListController removeObserver:self forKeyPath:@"sortDescriptors"];

	[colorListController	release];
	
	[super dealloc];
	
}//end dealloc


@end

