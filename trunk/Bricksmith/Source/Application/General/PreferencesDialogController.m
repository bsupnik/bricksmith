//==============================================================================
//
// File:		PreferencesDialogController.m
//
// Purpose:		Handles the user interface between the application and its 
//				preferences file.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PreferencesDialogController.h"

#import "LDrawApplication.h"
#import "LDrawGLView.h"			//for ViewOrientationT
#import "LDrawPaths.h"
#import "MacLDraw.h"
#import "PartLibrary.h"
#import "PartLibraryController.h"
#import "UserDefaultsCategory.h"
#import "WindowCategory.h"


@implementation PreferencesDialogController

#define PREFERENCES_WINDOW_AUTOSAVE_NAME	@"PreferencesWindow"


//The shared preferences window. We need to store this reference here so that 
// we can simply bring the window to the front when it is already onscreen, 
// rather than accidentally creating a whole new one.
PreferencesDialogController *preferencesDialog = nil;


//========== awakeFromNib ======================================================
//
// Purpose:		Show the preferences window.
//
//==============================================================================
- (void) awakeFromNib
{
	//Grab the current window content from the Nib (it should be blank). 
	// We will display this while changing panes.
	blankContent = [[preferencesWindow contentView] retain];

	NSToolbar *tabToolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preferences"] autorelease];
	[tabToolbar setDelegate:self];
	[preferencesWindow setToolbar:tabToolbar];
	
	//Restore the last-seen tab.
	NSUserDefaults	*userDefaults = [NSUserDefaults standardUserDefaults];
	NSString		*lastIdentifier = [userDefaults stringForKey:PREFERENCES_LAST_TAB_DISPLAYED];
	if(lastIdentifier == nil)
		lastIdentifier = PREFS_LDRAW_TAB_IDENTFIER;
	[self selectPanelWithIdentifier:lastIdentifier];
	
	// After the window has been resized for the tab, *then* restore the size.
	[self->preferencesWindow setFrameUsingName:PREFERENCES_WINDOW_AUTOSAVE_NAME];
	
}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- doPreferences -------------------------------------------[static]--
//
// Purpose:		Show the preferences window.
//
//------------------------------------------------------------------------------
+ (void) doPreferences
{
	if(preferencesDialog == nil)
		preferencesDialog = [[PreferencesDialogController alloc] init];
	
	[preferencesDialog showPreferencesWindow];

}//end doPreferences


//========== init ==============================================================
//
// Purpose:		Make us an object. Load us our window.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	[NSBundle loadNibNamed:@"Preferences" owner:self];
	
	return self;
	
}//end init


//========== showPreferencesWindow =============================================
//
// Purpose:		Brings the window on screen.
//
//==============================================================================
- (void) showPreferencesWindow
{
	[self setDialogValues];
	[preferencesWindow makeKeyAndOrderFront:nil];
	
}//end showPreferencesWindow


#pragma mark -

//========== setDialogValues ===================================================
//
// Purpose:		Brings the window on screen.
//
//==============================================================================
- (void) setDialogValues
{
	//Make sure there are actually preferences to read before attempting to 
	// retrieve them.
	[PreferencesDialogController ensureDefaults];

	[self setGeneralTabValues];
	[self setStylesTabValues];
	[self setLDrawTabValues];
	
}//end setDialogValues


//========== setGeneralTabValues ===============================================
//
// Purpose:		Updates the data in the General tab to match what is on the 
//			    disk.  
//
//==============================================================================
- (void) setGeneralTabValues
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	
	//Grid Spacing.
	float gridFine		= [userDefaults floatForKey:GRID_SPACING_FINE];
	float gridMedium	= [userDefaults floatForKey:GRID_SPACING_MEDIUM];
	float gridCoarse	= [userDefaults floatForKey:GRID_SPACING_COARSE];
	[[gridSpacingForm cellAtIndex:0] setFloatValue:gridFine];
	[[gridSpacingForm cellAtIndex:1] setFloatValue:gridMedium];
	[[gridSpacingForm cellAtIndex:2] setFloatValue:gridCoarse];
	
	// Mouse Dragging
	MouseDragBehaviorT	mouseBehavior	= [userDefaults integerForKey:MOUSE_DRAGGING_BEHAVIOR_KEY];
	[self->mouseDraggingRadioButtons selectCellWithTag:mouseBehavior];
	
	RightButtonBehaviorT	rbBehavior = [userDefaults integerForKey:RIGHT_BUTTON_BEHAVIOR_KEY];
	[self->rightButtonRadioButtons selectCellWithTag:rbBehavior];
	
	RotateModeT			rBehavior = [userDefaults integerForKey:ROTATE_MODE_KEY];
	[self->rotateModeRadioButtons selectCellWithTag:rBehavior];	
	
	MouseWheelBeahviorT	wBehavior = [userDefaults integerForKey:MOUSE_WHEEL_BEHAVIOR_KEY];
	[self->mouseWheelRadioButtons selectCellWithTag:wBehavior];
	
	
	
}//end setGeneralTabValues


//========== setStylesTabValues ================================================
//
// Purpose:		Updates the data in the Styles tab to match what is on the disk.
//
//==============================================================================
- (void) setStylesTabValues
{
	NSUserDefaults	*userDefaults		= [NSUserDefaults standardUserDefaults];
	
	NSColor			*backgroundColor	= [userDefaults colorForKey:LDRAW_VIEWER_BACKGROUND_COLOR_KEY];
	NSColor			*modelsColor		= [userDefaults colorForKey:SYNTAX_COLOR_MODELS_KEY];
	NSColor			*stepsColor			= [userDefaults colorForKey:SYNTAX_COLOR_STEPS_KEY];
	NSColor			*partsColor			= [userDefaults colorForKey:SYNTAX_COLOR_PARTS_KEY];
	NSColor			*primitivesColor	= [userDefaults colorForKey:SYNTAX_COLOR_PRIMITIVES_KEY];
	NSColor			*colorsColor		= [userDefaults colorForKey:SYNTAX_COLOR_COLORS_KEY];
	NSColor			*commentsColor		= [userDefaults colorForKey:SYNTAX_COLOR_COMMENTS_KEY];
	NSColor			*unknownColor		= [userDefaults colorForKey:SYNTAX_COLOR_UNKNOWN_KEY];
	
	[backgroundColorWell	setColor:backgroundColor];
	
	[modelsColorWell		setColor:modelsColor];
	[stepsColorWell			setColor:stepsColor];
	[partsColorWell			setColor:partsColor];
	[primitivesColorWell	setColor:primitivesColor];
	[commentsColorWell		setColor:commentsColor];
	[colorsColorWell		setColor:colorsColor];
	[unknownColorWell		setColor:unknownColor];

}//end setStylesTabValues


//========== setLDrawTabValues =================================================
//
// Purpose:		Updates the data in the LDraw tab to match what is on the disk.
//
//==============================================================================
- (void) setLDrawTabValues
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	NSString			*ldrawPath			= [userDefaults stringForKey:LDRAW_PATH_KEY];
	PartBrowserStyleT	 partBrowserStyle	= [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	
	[self->partBrowserStyleRadioButtons selectCellWithTag:partBrowserStyle];
	
	if(ldrawPath != nil){
		[LDrawPathTextField setStringValue:ldrawPath];
	}//end if we have a folder.
	//No folder selected yet.
	else
		[self chooseLDrawFolder:self];
	
}//end showPreferencesWindow


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== changeTab: ========================================================
//
// Purpose:		Sent by the toolbar "tabs" to indicate the preferences pane 
//				should change.
//
//==============================================================================
- (void) changeTab:(id)sender
{	
	NSString	*itemIdentifier	= [sender itemIdentifier];
	
	[self selectPanelWithIdentifier:itemIdentifier];
	
}//end changeTab:


#pragma mark -
#pragma mark General Tab

//========== gridSpacingChanged: ===============================================
//
// Purpose:		User updated the amounts by which parts are shifted in different 
//				grid modes.
//
//==============================================================================
- (IBAction) gridSpacingChanged:(id)sender
{
	NSUserDefaults	*userDefaults		= [NSUserDefaults standardUserDefaults];

	//Grid Spacing.
	float gridFine	= [[gridSpacingForm cellAtIndex:0] floatValue];
	float gridMedium	= [[gridSpacingForm cellAtIndex:1] floatValue];
	float gridCoarse	= [[gridSpacingForm cellAtIndex:2] floatValue];
	
	[userDefaults setFloat:gridFine		forKey:GRID_SPACING_FINE];
	[userDefaults setFloat:gridMedium	forKey:GRID_SPACING_MEDIUM];
	[userDefaults setFloat:gridCoarse	forKey:GRID_SPACING_COARSE];

}//end gridSpacingChanged:


//========== mouseDraggingChanged: =============================================
//
// Purpose:		Mouse drag-and-drop behavior was changed.
//
//==============================================================================
- (IBAction) mouseDraggingChanged:(id)sender
{
	NSUserDefaults		*userDefaults	= [NSUserDefaults standardUserDefaults];
	MouseDragBehaviorT	mouseBehavior	= [self->mouseDraggingRadioButtons selectedTag];
	
	[userDefaults setInteger:mouseBehavior
					  forKey:MOUSE_DRAGGING_BEHAVIOR_KEY];
	
}//end mouseDraggingChanged:

- (IBAction) rightButtonChanged:(id)sender
{
	NSUserDefaults		*userDefaults	= [NSUserDefaults standardUserDefaults];
	RightButtonBehaviorT rbBehavior = [self->rightButtonRadioButtons selectedTag];
	[userDefaults setInteger:rbBehavior
						forKey:RIGHT_BUTTON_BEHAVIOR_KEY];
}

- (IBAction) rotateModeChanged:(id)sender
{
	NSUserDefaults		*userDefaults	= [NSUserDefaults standardUserDefaults];
	RotateModeT			rBehavior = [self->rotateModeRadioButtons selectedTag];
	[userDefaults setInteger:rBehavior
						forKey:ROTATE_MODE_KEY];
}

- (IBAction) mouseWheelChanged:(id)sender
{
	NSUserDefaults		*userDefaults	= [NSUserDefaults standardUserDefaults];
	MouseWheelBeahviorT		wBehavior = [self->mouseWheelRadioButtons selectedTag];
	[userDefaults setInteger:wBehavior
						forKey:MOUSE_WHEEL_BEHAVIOR_KEY];
}

#pragma mark -
#pragma mark Parts Tab

//========== partBrowserStyleChanged: ==========================================
//
// Purpose:		We have multiple ways of showing the part browser.
//
//==============================================================================
- (IBAction) partBrowserStyleChanged:(id)sender
{
	NSUserDefaults		*userDefaults	= [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT	 newStyle		= [self->partBrowserStyleRadioButtons selectedTag];
	
	[userDefaults setInteger:newStyle forKey:PART_BROWSER_STYLE_KEY];
	
	//inform interested parties.
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawPartBrowserStyleDidChangeNotification
						  object:[NSNumber numberWithInteger:newStyle] ];
	
}//end partBrowserStyleChanged:


#pragma mark -

//========== chooseLDrawFolder =================================================
//
// Purpose:		Present a folder choose dialog to find the LDraw folder.
//
//==============================================================================
- (IBAction)chooseLDrawFolder:(id)sender
{
	//Create a standard "Choose" dialog.
	NSOpenPanel *folderChooser = [NSOpenPanel openPanel];
	[folderChooser setCanChooseFiles:NO];
	[folderChooser setCanChooseDirectories:YES];
	
	//Tell the poor user what this dialog does!
	[folderChooser setTitle:NSLocalizedString(@"Choose LDraw Folder", nil)];
	[folderChooser setMessage:NSLocalizedString(@"LDrawFolderChooserMessage", nil)];
	[folderChooser setAccessoryView:folderChooserAccessoryView];
	[folderChooser setPrompt:NSLocalizedString(@"Choose", nil)];
	
	//Run the dialog.
	if([folderChooser runModalForTypes:nil] == NSOKButton){
		//Get the folder selected.
		NSString		*folderPath		= [[folderChooser filenames] objectAtIndex:0];
		
		[self changeLDrawFolderPath:folderPath];
	}
	
}//end chooseLDrawFolder:


//========== pathTextFieldChanged: =============================================
//
// Purpose:		The user has gone all geek on us and manually typed in a new 
//				LDraw folder path.
//
//==============================================================================
- (IBAction) pathTextFieldChanged:(id)sender
{
	NSString *newPath = [LDrawPathTextField stringValue];
	
	[self changeLDrawFolderPath:newPath];
	
}//end pathTextFieldChanged:


//========== reloadParts: ======================================================
//
// Purpose:		Scans the contents of the LDraw/Parts folder and produces a 
//				Mac-friendly index of parts.
//
//				Is it fast? No. Is it easy to code? Yes.
//
//==============================================================================
- (IBAction) reloadParts:(id)sender
{
	PartLibraryController   *libraryController	= [LDrawApplication sharedPartLibraryController];
	
	[libraryController reloadPartCatalog];
	
}//end reloadParts:


#pragma mark -
#pragma mark Styles Tab

//========== backgroundColorWellChanged: =======================================
//
// Purpose:		The color for the LDraw views' background has been changed. 
//				Update the value in the preferences.
//
//==============================================================================
- (IBAction) backgroundColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:LDRAW_VIEWER_BACKGROUND_COLOR_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawViewBackgroundColorDidChangeNotification
						  object:newColor ];
						  
}//end backgroundColorWellChanged:


//========== modelsColorWellChanged: ===========================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) modelsColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_MODELS_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end modelsColorWellChanged:


//========== stepsColorWellChanged: ============================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) stepsColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_STEPS_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end stepsColorWellChanged:


//========== partsColorWellChanged: ============================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) partsColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_PARTS_KEY];

	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end partsColorWellChanged:


//========== primitivesColorWellChanged: =======================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) primitivesColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_PRIMITIVES_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end primitivesColorWellChanged:


//========== colorsColorWellChanged: ===========================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) colorsColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_COLORS_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
	
}//end colorsColorWellChanged:


//========== commentsColorWellChanged: =========================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) commentsColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_COMMENTS_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end commentsColorWellChanged:


//========== unknownColorWellChanged: ==========================================
//
// Purpose:		This syntax-color well changed. Update the value in preferences.
//
//==============================================================================
- (IBAction) unknownColorWellChanged:(id)sender
{
	NSColor			*newColor		= [sender color];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setColor:newColor forKey:SYNTAX_COLOR_UNKNOWN_KEY];
	
	[[NSNotificationCenter defaultCenter] 
			postNotificationName:LDrawSyntaxColorsDidChangeNotification
						  object:NSApp ];
						  
}//end unknownColorWellChanged:


#pragma mark -
#pragma mark TOOLBAR DELEGATE
#pragma mark -

//**** NSToolbar ****
//========== toolbarAllowedItemIdentifiers: ====================================
//
// Purpose:		The tabs allowed in the preferences window.
//
//==============================================================================
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
						PREFS_GENERAL_TAB_IDENTIFIER,
						PREFS_LDRAW_TAB_IDENTFIER,
						PREFS_STYLE_TAB_IDENTFIER,
						nil ];
}//end toolbarAllowedItemIdentifiers:


//**** NSToolbar ****
//========== toolbarDefaultItemIdentifiers: ====================================
//
// Purpose:		The tabs shown by default in the preferences window.
//
//==============================================================================
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
	
}//end toolbarDefaultItemIdentifiers:


//**** NSToolbar ****
//========== toolbarSelectableItemIdentifiers: =================================
//
// Purpose:		The tabs selectable in the preferences window.
//
//==============================================================================
- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
	
}//end toolbarSelectableItemIdentifiers:


//**** NSToolbar ****
//========== toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar: ==========
//
// Purpose:		Creates the "tabs" used in the preferences window.
//
//==============================================================================
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
	 itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *newItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	
	[newItem setLabel:NSLocalizedString(itemIdentifier, nil)];
	
	if([itemIdentifier isEqualToString:PREFS_GENERAL_TAB_IDENTIFIER])
		[newItem setImage:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
	
	else if([itemIdentifier isEqualToString:PREFS_LDRAW_TAB_IDENTFIER])
		[newItem setImage:[NSImage imageNamed:@"LDrawLogo"]];
	
	else if([itemIdentifier isEqualToString:PREFS_STYLE_TAB_IDENTFIER])
		[newItem setImage:[NSImage imageNamed:@"SyntaxColoring"]];
	
	[newItem setTarget:self];
	[newItem setAction:@selector(changeTab:)];
	
	return [newItem autorelease];
	
}//end toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:


#pragma mark -
#pragma mark WINDOW DELEGATE
#pragma mark -

//**** NSWindow ****
//========== windowShouldClose: ================================================
//
// Purpose:		Used to release the preferences controller.
//
//==============================================================================
- (BOOL) windowShouldClose:(id)sender
{
	//Save out the last tab view.
	NSUserDefaults	*userDefaults = [NSUserDefaults standardUserDefaults];
	NSString		*lastIdentifier = [[preferencesWindow toolbar] selectedItemIdentifier];
	
	[userDefaults setObject:lastIdentifier
					 forKey:PREFERENCES_LAST_TAB_DISPLAYED];
	
	// Cocoa autosaving doesn't necessarily get restored when we need it to, so 
	// we have to track in manually.  
	[self->preferencesWindow saveFrameUsingName:PREFERENCES_WINDOW_AUTOSAVE_NAME];
	
	//Make sure our memory is all released.
	[preferencesDialog autorelease];
	
	return YES;
	
}//end windowShouldClose:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -


//---------- ensureDefaults ------------------------------------------[static]--
//
// Purpose:		Verifies that all expected settings exist in preferences. If a 
//				setting is not found, it is restored to its default value.
//
//				This method should be called upon program launch, so that the 
//				rest of the program need not worry about preference 
//				error-checking.
//
//------------------------------------------------------------------------------
+ (void) ensureDefaults
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	NSMutableDictionary	*initialDefaults	= [NSMutableDictionary dictionary];
	
	NSColor				*backgroundColor	= [NSColor whiteColor];
	NSColor				*modelsColor		= [NSColor blackColor];
	NSColor				*stepsColor			= [NSColor blackColor];
	NSColor				*partsColor			= [NSColor blackColor];
	NSColor				*primitivesColor	= [NSColor blueColor];
	NSColor				*colorsColor		= [NSColor colorWithDeviceRed:  0./ 255
																    green:128./ 255
																	 blue:128./ 255
																    alpha:1.0 ];
	NSColor				*commentsColor		= [NSColor colorWithDeviceRed: 35./ 255
																    green:110./ 255
																	 blue: 37./ 255
																    alpha:1.0 ];
	NSColor				*unknownColor		= [NSColor lightGrayColor];
	
	//
	// General
	//
	[initialDefaults setObject:[NSNumber numberWithInteger:PartBrowserShowAsPanel]			forKey:PART_BROWSER_STYLE_KEY];
	[initialDefaults setObject:[NSNumber numberWithInteger:MouseDraggingBeginImmediately]	forKey:MOUSE_DRAGGING_BEHAVIOR_KEY];

	[initialDefaults setObject:[NSNumber numberWithInteger:RightButtonContextual]			forKey:RIGHT_BUTTON_BEHAVIOR_KEY];
	[initialDefaults setObject:[NSNumber numberWithInteger:RotateModeTrackball]				forKey:ROTATE_MODE_KEY];
	[initialDefaults setObject:[NSNumber numberWithInteger:MouseWheelScrolls]				forKey:MOUSE_WHEEL_BEHAVIOR_KEY];


	[initialDefaults setObject:[NSNumber numberWithInteger:NSDrawerClosedState]	forKey:PART_BROWSER_DRAWER_STATE];
	[initialDefaults setObject:(id)kCFBooleanTrue								forKey:PART_BROWSER_PANEL_SHOW_AT_LAUNCH];
	
	[initialDefaults setObject:(id)kCFBooleanTrue								forKey:VIEWPORTS_EXPAND_TO_AVAILABLE_SIZE];
	[initialDefaults setObject:(id)kCFBooleanFalse								forKey:COLUMNIZE_OUTPUT_KEY]; // appease LDraw traditionalists
	
	//
	// Syntax Colors
	//
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:backgroundColor]	forKey:LDRAW_VIEWER_BACKGROUND_COLOR_KEY];
	
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:modelsColor]		forKey:SYNTAX_COLOR_MODELS_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:stepsColor]		forKey:SYNTAX_COLOR_STEPS_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:partsColor]		forKey:SYNTAX_COLOR_PARTS_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:primitivesColor]	forKey:SYNTAX_COLOR_PRIMITIVES_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:commentsColor]	forKey:SYNTAX_COLOR_COMMENTS_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:colorsColor]		forKey:SYNTAX_COLOR_COLORS_KEY];
	[initialDefaults setObject:[NSArchiver archivedDataWithRootObject:unknownColor]		forKey:SYNTAX_COLOR_UNKNOWN_KEY];
	
	//
	// Grid Spacing
	//
	[initialDefaults setObject:[NSNumber numberWithFloat: 1]	forKey:GRID_SPACING_FINE];
	[initialDefaults setObject:[NSNumber numberWithFloat:10]	forKey:GRID_SPACING_MEDIUM];
	[initialDefaults setObject:[NSNumber numberWithFloat:20]	forKey:GRID_SPACING_COARSE];
	
	//
	// Initial Window State
	//
	
	// OpenGL viewer settings -- see -restoreConfiguration in LDrawGLView.
	[initialDefaults setObject:[NSNumber numberWithInteger:ViewOrientation3D]			forKey:[LDRAW_GL_VIEW_ANGLE			stringByAppendingString:@" fileGraphicView_0"]];
	[initialDefaults setObject:[NSNumber numberWithInteger:ProjectionModePerspective]	forKey:[LDRAW_GL_VIEW_PROJECTION	stringByAppendingString:@" fileGraphicView_0"]];
	
	[initialDefaults setObject:[NSNumber numberWithInteger:ViewOrientationFront]		forKey:[LDRAW_GL_VIEW_ANGLE			stringByAppendingString:@" fileGraphicView_1"]];
	[initialDefaults setObject:[NSNumber numberWithInteger:ProjectionModeOrthographic]	forKey:[LDRAW_GL_VIEW_PROJECTION	stringByAppendingString:@" fileGraphicView_1"]];
	
	[initialDefaults setObject:[NSNumber numberWithInteger:ViewOrientationLeft]			forKey:[LDRAW_GL_VIEW_ANGLE			stringByAppendingString:@" fileGraphicView_2"]];
	[initialDefaults setObject:[NSNumber numberWithInteger:ProjectionModeOrthographic]	forKey:[LDRAW_GL_VIEW_PROJECTION	stringByAppendingString:@" fileGraphicView_2"]];

	[initialDefaults setObject:[NSNumber numberWithInteger:ViewOrientationTop]			forKey:[LDRAW_GL_VIEW_ANGLE			stringByAppendingString:@" fileGraphicView_3"]];
	[initialDefaults setObject:[NSNumber numberWithInteger:ProjectionModeOrthographic]	forKey:[LDRAW_GL_VIEW_PROJECTION	stringByAppendingString:@" fileGraphicView_3"]];
	
	//
	// Part Browser
	//
	[initialDefaults setObject:[NSNumber numberWithInteger:SearchModeAllCategories] forKey:PART_BROWSER_SEARCH_MODE];
	[initialDefaults setObject:NSLocalizedString(@"Brick", nil)						forKey:PART_BROWSER_PREVIOUS_CATEGORY];
	[initialDefaults setObject:[NSNumber numberWithInteger:0]						forKey:PART_BROWSER_PREVIOUS_SELECTED_ROW];
	[initialDefaults setObject:[NSArray array]										forKey:FAVORITE_PARTS_KEY];
	
	//
	// Tool Palette
	//
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:TOOL_PALETTE_HIDDEN];
	
	//
	// Minifigure Generator
	//
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_HAT];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_HEAD];
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:MINIFIGURE_HAS_NECK];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_TORSO];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_ARM_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_ARM_LEFT];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_HAND_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:MINIFIGURE_HAS_HAND_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_HAND_LEFT];
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:MINIFIGURE_HAS_HAND_LEFT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_HIPS];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_LEG_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:MINIFIGURE_HAS_LEG_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithBool:YES]			forKey:MINIFIGURE_HAS_LEG_LEFT];
	[initialDefaults setObject:[NSNumber numberWithBool:NO]				forKey:MINIFIGURE_HAS_LEG_LEFT_ACCESSORY];
	
	[initialDefaults setObject:@"4485.dat"								forKey:MINIFIGURE_PARTNAME_HAT];					//Minifig Cap
	[initialDefaults setObject:@"3626bp01.dat"							forKey:MINIFIGURE_PARTNAME_HEAD];					//Minifig Head with Standard Grin pattern
	[initialDefaults setObject:@"3838.dat"								forKey:MINIFIGURE_PARTNAME_NECK];					//Minifig Airtanks
	[initialDefaults setObject:@"973p1b.dat"							forKey:MINIFIGURE_PARTNAME_TORSO];					//Minifig Torso with Blue Dungarees Pattern
	[initialDefaults setObject:@"982.dat"								forKey:MINIFIGURE_PARTNAME_ARM_RIGHT];				//Minifig Arm Right
	[initialDefaults setObject:@"981.dat"								forKey:MINIFIGURE_PARTNAME_ARM_LEFT];				//Minifig Arm Left
	[initialDefaults setObject:@"983.dat"								forKey:MINIFIGURE_PARTNAME_HAND_RIGHT];				//Minifig Hand
	[initialDefaults setObject:@"3837.dat"								forKey:MINIFIGURE_PARTNAME_HAND_RIGHT_ACCESSORY];	//Minifig Shovel
	[initialDefaults setObject:@"983.dat"								forKey:MINIFIGURE_PARTNAME_HAND_LEFT];				//Minifig Hand
	[initialDefaults setObject:@"4006.dat"								forKey:MINIFIGURE_PARTNAME_HAND_LEFT_ACCESSORY];	//Minifig Tool Spanner/Screwdriver
	[initialDefaults setObject:@"970.dat"								forKey:MINIFIGURE_PARTNAME_HIPS];					//Minifig Hips
	[initialDefaults setObject:@"971.dat"								forKey:MINIFIGURE_PARTNAME_LEG_RIGHT];				//Minifig Leg Right
	[initialDefaults setObject:@"6120.dat"								forKey:MINIFIGURE_PARTNAME_LEG_RIGHT_ACCESSORY];	//Minifig Ski
	[initialDefaults setObject:@"972.dat"								forKey:MINIFIGURE_PARTNAME_LEG_LEFT];				//Minifig Lef Left
	[initialDefaults setObject:@"6120.dat"								forKey:MINIFIGURE_PARTNAME_LEG_LEFT_ACCESSORY];		//Minifig Ski

	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HAT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HEAD];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_NECK];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_TORSO];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_ARM_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_ARM_LEFT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HAND_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HAND_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HAND_LEFT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HAND_LEFT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_HIPS];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_LEG_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_LEG_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_LEG_LEFT];
	[initialDefaults setObject:[NSNumber numberWithFloat:0]				forKey:MINIFIGURE_ANGLE_LEG_LEFT_ACCESSORY];

	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlue]		forKey:MINIFIGURE_COLOR_HAT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawYellow]		forKey:MINIFIGURE_COLOR_HEAD];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlack]		forKey:MINIFIGURE_COLOR_NECK];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawWhite]		forKey:MINIFIGURE_COLOR_TORSO];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawWhite]		forKey:MINIFIGURE_COLOR_ARM_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawWhite]		forKey:MINIFIGURE_COLOR_ARM_LEFT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawYellow]		forKey:MINIFIGURE_COLOR_HAND_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlack]		forKey:MINIFIGURE_COLOR_HAND_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawYellow]		forKey:MINIFIGURE_COLOR_HAND_LEFT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlack]		forKey:MINIFIGURE_COLOR_HAND_LEFT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlue]		forKey:MINIFIGURE_COLOR_HIPS];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlue]		forKey:MINIFIGURE_COLOR_LEG_RIGHT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlack]		forKey:MINIFIGURE_COLOR_LEG_RIGHT_ACCESSORY];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlue]		forKey:MINIFIGURE_COLOR_LEG_LEFT];
	[initialDefaults setObject:[NSNumber numberWithInt:LDrawBlack]		forKey:MINIFIGURE_COLOR_LEG_LEFT_ACCESSORY];
	
	[initialDefaults setObject:[NSNumber numberWithFloat:4.0]			forKey:MINIFIGURE_HEAD_ELEVATION];
	
	//OpenGL viewer settings -- see -restoreConfiguration in LDrawGLView.
	[initialDefaults setObject:[NSNumber numberWithInteger:ViewOrientationFront]		forKey:[LDRAW_GL_VIEW_ANGLE			stringByAppendingString:@" MinifigureGeneratorView"]];
	[initialDefaults setObject:[NSNumber numberWithInteger:ProjectionModeOrthographic]	forKey:[LDRAW_GL_VIEW_PROJECTION	stringByAppendingString:@" MinifigureGeneratorView"]];
	[initialDefaults setObject:(id)kCFBooleanFalse										forKey:@"UseThreads"];
	
	//
	// COMMIT!
	//
	[userDefaults registerDefaults:initialDefaults];
	
}//end ensureDefaults


//========== changeLDrawFolderPath: ============================================
//
// Purpose:		A new folder path has been chose as the LDraw folder. We need to 
//				check it out and reload the parts from it.
//
//==============================================================================
- (void) changeLDrawFolderPath:(NSString *) folderPath
{
	PartLibraryController   *libraryController  = [LDrawApplication sharedPartLibraryController];
	NSUserDefaults          *userDefaults       = [NSUserDefaults standardUserDefaults];
	
	[LDrawPathTextField setStringValue:folderPath];
	
	// Record this new folder in preferences whether it's right or not. We'll 
	// let them sink their own ship here. 
	[userDefaults setObject:folderPath forKey:LDRAW_PATH_KEY];
	[[LDrawPaths sharedPaths] setPreferredLDrawPath:folderPath];
	
	if([libraryController validateLDrawFolderWithMessage:folderPath] == YES)
	{
		[self reloadParts:self];
	}
	//else we displayed an error message already.
	
}//end changeLDrawFolderPath:


//========== selectPanelWithIdentifier: ========================================
//
// Purpose:		Changes the the preferences dialog to display the panel/tab 
//				represented by itemIdentifier.
//
//==============================================================================
- (void) selectPanelWithIdentifier:(NSString *)itemIdentifier
{
	NSView		*newContentView	= nil;
	NSRect		 newFrameRect	= NSZeroRect;
	
	//Make sure the corresponding toolbar tab is selected too.
	[[preferencesWindow toolbar] setSelectedItemIdentifier:itemIdentifier];
	
	if([itemIdentifier isEqualToString:PREFS_GENERAL_TAB_IDENTIFIER])
		newContentView = self->generalTabContentView;
	
	else if([itemIdentifier isEqualToString:PREFS_LDRAW_TAB_IDENTFIER])
		newContentView = ldrawContentView;
	
	else if([itemIdentifier isEqualToString:PREFS_STYLE_TAB_IDENTFIER])
		newContentView = stylesContentView;
	
	//need content rect in screen coordinates
	//Need find window frame with new content view.
	newFrameRect = [preferencesWindow frameRectForContentSize:[newContentView frame].size];
	
	//Do a smooth transition to the new panel.
	[preferencesWindow setContentView:blankContent]; //so we don't see artifacts during resize.
	[preferencesWindow setFrame:newFrameRect
						display:YES
						animate:YES ];
	[preferencesWindow setContentView:newContentView];
	
}//end selectPanelWithIdentifier


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		It's time to get fitted for a halo.
//
//==============================================================================
- (void) dealloc
{
	[generalTabContentView	release];
	[preferencesWindow		release];
	[blankContent			release];
	
	//clear out our global preferences controller. 
	// It will be reinitialized when needed.
	preferencesDialog = nil;
	
	[super dealloc];
	
}//end dealloc


@end
