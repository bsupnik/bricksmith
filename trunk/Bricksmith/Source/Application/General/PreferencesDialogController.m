//==============================================================================
//
// File:		PreferencesDialogController.m
//
// Purpose:		Handles the user interface between the application and its 
//				preferences file.
//
// Notes:
//
// To add a new Preferences pane the following steps are required:
//
// Preferences.xib
//   - Add a skeleton NSView, named appropriately.  Change the Document Label for
//     the view and set its dimensions to e.g. 486 x height
// 
// Create an appropriate .tiff icon for the preference panel 'tab' in e.g.
// Resources/Icon
// 
// PreferencesDialogController.h:
//   - #define a constant for the new panel
//   - Add an IBOutlet for the new view and connect it to the view.
//   - Add a declaration for a new -(void)setNewPanelTabValues method.
//
// PreferencesDialogController.m:
//   - In -(void)setDialogValues add setNewPanelTabValues
//   - Add the -(void)setNewPanelTabValues method
//   - Update -(NSArray *)toolbarAllowedItemIdentifiers:
//   - Update -(void)selectPanelWithIdentifier:
//   - Update -(NSToolbarItem *)toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
//
// Add pref panel title to Resources/Localizable.strings in the Preferences section.
//
// Run it up and check it's there.  Hopefully you're good to go.  So, flesh out your .xib:
//   - Add controls
//   - Hook up Actions and Outlets in PreferencesDialogController.h as you build up your .xib
//   - Flesh-out the Actions defined in the header in PreferencesDialogController.m
//   - Add preference key #defines to MacLDraw.h
//   - Make sure that your controls have sensible initial defaults set in
//     PreferencesDialogController.m/+(void)ensureDefaults
//
// File open dialogs:  Add code to e.g. a button action to open a file selection system
// dialog.  Search for 'folderChooser' for examples.  You'll also need to update
// Localizable.strings.  Accessory views can be added to the .xib to inform the user.  These
// need to be linked up as outlets.
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
#import "LSynthConfiguration.h"
#import "UserDefaultsCategory.h"
#import "WindowCategory.h"
#import "RegexKitLite.h"

@interface PreferencesDialogController ()

// General Tab
@property (nonatomic, weak) IBOutlet NSTextField*			gridSpacingFineField;
@property (nonatomic, weak) IBOutlet NSTextField*			gridSpacingMediumField;
@property (nonatomic, weak) IBOutlet NSTextField*			gridSpacingCoarseField;


@end


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
	blankContent = [preferencesWindow contentView];

	NSToolbar *tabToolbar = [[NSToolbar alloc] initWithIdentifier:@"Preferences"];
	[tabToolbar setDelegate:self];
	[preferencesWindow setToolbar:tabToolbar];
	
	//Restore the last-seen tab.
	NSUserDefaults	*userDefaults = [NSUserDefaults standardUserDefaults];
	NSString		*lastIdentifier = [userDefaults stringForKey:PREFERENCES_LAST_TAB_DISPLAYED];
	if(lastIdentifier == nil)
		lastIdentifier = PREFS_LDRAW_TAB_IDENTIFIER;
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
    [self setLSynthTabValues];
	
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
	[_gridSpacingFineField setFloatValue:gridFine];
	[_gridSpacingMediumField setFloatValue:gridMedium];
	[_gridSpacingCoarseField setFloatValue:gridCoarse];
	
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

//========== setLDrawTabValues =================================================
//
// Purpose:		Updates the data in the LSynth tab to match what is on the disk.
//
//==============================================================================
- (void) setLSynthTabValues
{
    // Get preference values
    NSUserDefaults *userDefaults          = [NSUserDefaults standardUserDefaults];
    NSString       *executablePath        = [userDefaults stringForKey:LSYNTH_EXECUTABLE_PATH_KEY];
    NSString       *configurationPath     = [userDefaults stringForKey:LSYNTH_CONFIGURATION_PATH_KEY];
    int             selectionTransparency = [userDefaults integerForKey:LSYNTH_SELECTION_TRANSPARENCY_KEY]; // Stored as an int but interpreted as a percentage
    NSColor        *selectionColor        = [userDefaults colorForKey:LSYNTH_SELECTION_COLOR_KEY];
    BOOL            saveSynthesizedParts  = [userDefaults boolForKey:LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY];
    BOOL            showBasicPartsList    = [userDefaults boolForKey:LSYNTH_SHOW_BASIC_PARTS_LIST_KEY];
    LSynthSelectionModeT selectionMode    = [userDefaults integerForKey:LSYNTH_SELECTION_MODE_KEY];

    // Set control values
    [lsynthExecutablePath       setStringValue:executablePath];
    [lsynthConfigurationPath    setStringValue:configurationPath];
    [lsynthSelectionModeMatrix  selectCellWithTag:selectionMode];
    [lsynthSelectionColorWell   setColor:selectionColor];
    [lsynthTransparencySlider   setIntegerValue:selectionTransparency];
    [lsynthTransparencyText     setStringValue:[NSString stringWithFormat:@"%i", selectionTransparency]];
    [lsynthSaveSynthesizedParts setState:saveSynthesizedParts];
    [lsynthShowBasicPartsList   setState:showBasicPartsList];
    
    // Enable the correct bits of the selection section
    if (selectionMode == TransparentSelection) {
        [lsynthTransparencySlider setEnabled:YES];
        [lsynthTransparencyText setEnabled:YES];
        [lsynthSelectionColorWell setEnabled:NO];
    }
    else if (selectionMode == ColoredSelection) {
        [lsynthTransparencySlider setEnabled:NO];
        [lsynthTransparencyText setEnabled:NO];
        [lsynthSelectionColorWell setEnabled:YES];
    }
    else if (selectionMode == TransparentColoredSelection) {
        [lsynthTransparencySlider setEnabled:YES];
        [lsynthTransparencyText setEnabled:YES];
        [lsynthSelectionColorWell setEnabled:YES];
    }
}

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
	float gridFine		= [_gridSpacingFineField floatValue];
	float gridMedium	= [_gridSpacingMediumField floatValue];
	float gridCoarse	= [_gridSpacingCoarseField floatValue];
	
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
	if([folderChooser runModal] == NSModalResponseOK)
	{
		// Get the folder selected.
		NSURL	*folderURL	= [[folderChooser URLs] objectAtIndex:0];
		
		if([folderURL isFileURL])
			[self changeLDrawFolderPath:[folderURL path]];
		else
			NSBeep(); // sanity check
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
	
	[libraryController reloadPartCatalog:^(BOOL success) {}];
	
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
#pragma mark LSynth Tab

//========== lsynthChooseExecutable: ==========================================
//
// Purpose:		The user wishes to choose their own LSynth executable.
//
//==============================================================================
- (IBAction)lsynthChooseExecutable:(id)sender
{
    //Create a standard "Choose" dialog.
    NSOpenPanel *lsynthExecutableChooser = [NSOpenPanel openPanel];
    [lsynthExecutableChooser setCanChooseFiles:YES];
    [lsynthExecutableChooser setCanChooseDirectories:NO];

    //Tell the poor user what this dialog does!
    [lsynthExecutableChooser setTitle:NSLocalizedString(@"Choose an LSynth executable", nil)];
    [lsynthExecutableChooser setMessage:NSLocalizedString(@"lsynthExecutableChooserMessage", nil)];
    [lsynthExecutableChooser setAccessoryView:lsynthExecutableChooserAccessoryView];
    [lsynthExecutableChooser setPrompt:NSLocalizedString(@"Choose", nil)];

    //Run the dialog.
    if([lsynthExecutableChooser runModal] == NSModalResponseOK)
    {
        // Get the file selected.
        NSURL	*lsynthExecutableURL = [[lsynthExecutableChooser URLs] objectAtIndex:0];

        // TODO: validation?
        if([lsynthExecutableURL isFileURL]) {
            [lsynthExecutablePath setStringValue:[lsynthExecutableURL path]];
            NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
            [userDefaults setObject:[lsynthExecutableURL path] forKey:LSYNTH_EXECUTABLE_PATH_KEY];
        }
        else
            NSBeep(); // sanity check
    }
} // end lsynthChooseExecutable:

//========== lsynthChooseConfiguration: ==========================================
//
// Purpose:		The user wishes to choose their own LSynth configuration file.
//
//==============================================================================
- (IBAction)lsynthChooseConfiguration:(id)sender
{
    NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
    NSString *currentConfiguration  = [userDefaults stringForKey:LSYNTH_CONFIGURATION_PATH_KEY];
    
    //Create a standard "Choose" dialog.
    NSOpenPanel *lsynthConfigurationChooser = [NSOpenPanel openPanel];
    [lsynthConfigurationChooser setCanChooseFiles:YES];
    [lsynthConfigurationChooser setCanChooseDirectories:NO];
    
    //Tell the poor user what this dialog does!
    [lsynthConfigurationChooser setTitle:NSLocalizedString(@"Choose an LSynth configuration file", nil)];
    [lsynthConfigurationChooser setMessage:NSLocalizedString(@"lsynthConfigurationChooserMessage", nil)];
    [lsynthConfigurationChooser setAccessoryView:lsynthConfigurationChooserAccessoryView];
    [lsynthConfigurationChooser setPrompt:NSLocalizedString(@"Choose", nil)];
    
    //Run the dialog.
    if([lsynthConfigurationChooser runModal] == NSModalResponseOK)
    {
        // Get the file selected.
        NSURL	*lsynthConfigurationURL = [[lsynthConfigurationChooser URLs] objectAtIndex:0];
        
        // TODO: validation?
        if([lsynthConfigurationURL isFileURL]) {
            [lsynthConfigurationPath setStringValue:[lsynthConfigurationURL path]];
            [userDefaults setObject:[lsynthConfigurationURL path] forKey:LSYNTH_CONFIGURATION_PATH_KEY];

            // reload config if changed
            if ([currentConfiguration isEqualToString:[lsynthConfigurationURL path]]) {
                [[LSynthConfiguration sharedInstance] parseLsynthConfig:[lsynthConfigurationURL path]];
            }
        }
        else
            NSBeep(); // sanity check
    }
} // end lsynthChooseConfiguration:

//========== lsynthTransparencySliderChanged: ==================================
//
// Purpose:		The user has changed the LSynth selection transparency
//
//==============================================================================
- (IBAction)lsynthTransparencySliderChanged:(id)sender
{
    NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:[sender integerValue] forKey:LSYNTH_SELECTION_TRANSPARENCY_KEY];
    [lsynthTransparencyText setIntegerValue:[sender integerValue]];
    [self lsynthRequiresRedisplay];
} // end lsynthTransparencySliderChanged:

//========== lsynthTransparencyTextChanged: ====================================
//
// Purpose:		The user has changed the LSynth selection transparency
//
//==============================================================================
- (IBAction)lsynthTransparencyTextChanged:(id)sender
{
    NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:[sender integerValue] forKey:LSYNTH_SELECTION_TRANSPARENCY_KEY];
    [lsynthTransparencySlider setIntegerValue:[sender integerValue]];
    [self lsynthRequiresRedisplay];
} // end lsynthTransparencyTextChanged:

//========== lsynthSelectionColorWellClicked: ==================================
//
// Purpose:		The user has changed the LSynth selection color
//
//==============================================================================
- (IBAction)lsynthSelectionColorWellClicked:(id)sender
{
    NSColor			*newColor		= [sender color];
    NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];

    [userDefaults setColor:newColor forKey:LSYNTH_SELECTION_COLOR_KEY];
    [self lsynthRequiresRedisplay];
} // end lsynthSelectionColorWellClicked:

//========== lsynthSelectionModeChanged: =======================================
//
// Purpose:		User has chosen between transparency, color or both
//
//==============================================================================
- (IBAction)lsynthSelectionModeChanged:(id)sender
{
    NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];

    [userDefaults setInteger:[[sender selectedCell] tag] forKey:LSYNTH_SELECTION_MODE_KEY];

    [self setLSynthTabValues];
    [self lsynthRequiresRedisplay];
} // end lsynthSelectionModeChanged:

//========== lsynthSaveSynthesizedPartsChanged: ================================
//
// Purpose:		User has toggled the 'Save synthesized parts' checkbox
//
//==============================================================================
- (IBAction)lsynthSaveSynthesizedPartsChanged:(id)sender {
    NSUserDefaults	*userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:[lsynthSaveSynthesizedParts state] forKey:LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY];
} // end lsynthSaveSynthesizedPartsChanged:

//========== lsynthShowBasicPartsListChanged: ==================================
//
// Purpose:		User has toggled the 'Show simple parts list' checkbox
//
//==============================================================================
- (IBAction)lsynthShowBasicPartsListChanged:(id)sender
{
    NSUserDefaults	*userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:[lsynthShowBasicPartsList state] forKey:LSYNTH_SHOW_BASIC_PARTS_LIST_KEY];

    // Regenerate LSynth part menus
    [[LDrawApplication shared] populateLSynthModelMenus];
} // end lsynthShowBasicPartsListChanged:

//========== lsynthRequiresRedisplay ===========================================
//
// Purpose:		Convenience method to notify LSynth parts that they may need
//              redisplay if the selection highlighting has changed, or executable
//              or config files have changed.
//
//==============================================================================
- (void) lsynthRequiresRedisplay
{
    [[NSNotificationCenter defaultCenter]
            postNotificationName:LSynthSelectionDisplayDidChangeNotification
                          object:NSApp ];
} // end lsynthRequiresRedisplay

//========== lsynthRequiresResynthesis =========================================
//
// Purpose:		Convenience method to notify LSynth parts that they need to
//              resyntheisze if the  executable or config files have changed.
//
//==============================================================================
- (void) lsynthRequiresResynthesis
{
    [[NSNotificationCenter defaultCenter]
            postNotificationName:LSynthResynthesisRequiredNotification
                          object:NSApp ];
} // end lsynthRequiresResynthesis

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
						PREFS_LDRAW_TAB_IDENTIFIER,
						PREFS_STYLE_TAB_IDENTIFIER,
                        PREFS_LSYNTH_TAB_IDENTIFIER,
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
	
	else if([itemIdentifier isEqualToString:PREFS_LDRAW_TAB_IDENTIFIER])
		[newItem setImage:[NSImage imageNamed:@"LDrawLogo"]];
	
	else if([itemIdentifier isEqualToString:PREFS_STYLE_TAB_IDENTIFIER])
		[newItem setImage:[NSImage imageNamed:@"SyntaxColoring"]];
    
    else if([itemIdentifier isEqualToString:PREFS_LSYNTH_TAB_IDENTIFIER])
		[newItem setImage:[NSImage imageNamed:@"LSynthIcon"]];
	
	[newItem setTarget:self];
	[newItem setAction:@selector(changeTab:)];
	
	return newItem;
	
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
	
	NSColor				*backgroundColor	= [NSColor controlBackgroundColor];
	NSColor				*modelsColor		= [NSColor textColor];
	NSColor				*stepsColor			= [NSColor textColor];
	NSColor				*partsColor			= [NSColor textColor];
	NSColor				*primitivesColor	= [NSColor systemBlueColor];
	// On macOS 10.13 or later this could be systemTealColor, but there is no easy system equivalent currently.
	NSColor				*colorsColor		= [NSColor colorWithDeviceRed:  0./ 255
																    green:128./ 255
																	 blue:128./ 255
																    alpha:1.0 ];
	NSColor				*commentsColor		= [NSColor systemGreenColor];
	NSColor				*unknownColor		= [NSColor systemGrayColor];
	
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
    // LSynth Palette
    //
    NSColor *lsynthSelectionColor = [NSColor systemRedColor];
    [initialDefaults setObject:@"" forKey:LSYNTH_EXECUTABLE_PATH_KEY];
    [initialDefaults setObject:@"" forKey:LSYNTH_CONFIGURATION_PATH_KEY];
    [initialDefaults setObject:[NSNumber numberWithInt:20] forKey:LSYNTH_SELECTION_TRANSPARENCY_KEY];
    [initialDefaults setObject:[NSNumber numberWithInt:0] forKey:LSYNTH_SELECTION_MODE_KEY];
    [initialDefaults setObject:[NSArchiver archivedDataWithRootObject:lsynthSelectionColor] forKey:LSYNTH_SELECTION_COLOR_KEY];
    [initialDefaults setObject:[NSNumber numberWithBool:YES] forKey:LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY];
    [initialDefaults setObject:[NSNumber numberWithBool:YES] forKey:LSYNTH_SHOW_BASIC_PARTS_LIST_KEY];

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
	
	else if([itemIdentifier isEqualToString:PREFS_LDRAW_TAB_IDENTIFIER])
		newContentView = ldrawContentView;
	
	else if([itemIdentifier isEqualToString:PREFS_STYLE_TAB_IDENTIFIER])
		newContentView = stylesContentView;

    else if([itemIdentifier isEqualToString:PREFS_LSYNTH_TAB_IDENTIFIER])
		newContentView = lsynthContentView;
    
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
#pragma mark <NSTextFieldDelegate>
#pragma mark -

//========== controlTextDidEndEditing: =========================================
//
// Purpose:		The user finished editing a text field.  Used specifically by
//              the LSynth pane to validate and resynthesize in a timely fashion.
//
//==============================================================================
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    NSTextField *textField          = [aNotification object];
    NSUserDefaults *userDefaults    = [NSUserDefaults standardUserDefaults];
    NSString *currentExecutable     = [userDefaults stringForKey:LSYNTH_EXECUTABLE_PATH_KEY];
    NSString *currentConfiguration  = [userDefaults stringForKey:LSYNTH_CONFIGURATION_PATH_KEY];

    // The user manually changed the LSynth executable path
    // TODO: run validating synthesis
    if (textField == lsynthExecutablePath) {
        NSURL *executablePathAsURL = [NSURL fileURLWithPath:[lsynthExecutablePath stringValue]];
        if([executablePathAsURL isFileURL] && ![currentExecutable isEqualToString:[executablePathAsURL path]]) {
            [userDefaults setObject:[executablePathAsURL path] forKey:LSYNTH_EXECUTABLE_PATH_KEY];
            [self lsynthRequiresResynthesis];
        }

        // No path - it's been deleted
        else if (([[executablePathAsURL path] length] == 0 || [[executablePathAsURL path] isMatchedByRegex:@"^\\s+$"])
                && executablePathAsURL
                && ![currentExecutable isEqualToString:[executablePathAsURL path]]) {
            [userDefaults setObject:@"" forKey:LSYNTH_EXECUTABLE_PATH_KEY];
            [self lsynthRequiresResynthesis];
        }

        else if (executablePathAsURL) {
            NSBeep(); // sanity check
        }
    }

    // The user manually changed the LSynth config path
    // TODO: run validating synthesis
    else if (textField == lsynthConfigurationPath) {
        NSURL *configPathAsURL = [NSURL fileURLWithPath:[lsynthConfigurationPath stringValue]];
        if([configPathAsURL isFileURL]) {
            [userDefaults setObject:[configPathAsURL path] forKey:LSYNTH_CONFIGURATION_PATH_KEY];
            
            // reload config if changed
            if (![currentConfiguration isEqualToString:[configPathAsURL path]])
			{
                [[LSynthConfiguration sharedInstance] parseLsynthConfig:[configPathAsURL path]];
                [[LDrawApplication shared] populateLSynthModelMenus];
                [self lsynthRequiresResynthesis];
            }
        }

        // No path - it's been deleted
        else if (!configPathAsURL || [[configPathAsURL path] length] == 0)
		{
            [userDefaults setObject:@"" forKey:LSYNTH_CONFIGURATION_PATH_KEY];
            [[LSynthConfiguration sharedInstance] parseLsynthConfig:[[LSynthConfiguration sharedInstance] defaultConfigPath]];
            [[LDrawApplication shared] populateLSynthModelMenus];
            [self lsynthRequiresResynthesis];
        }
        
        else {
            NSBeep(); // sanity check
        }
    }


    
    
    
    
//    NSView *nextKeyView = [textField nextKeyView];
//    NSUInteger whyEnd = [[[aNotification userInfo] objectForKey:@"NSTextMovement"] unsignedIntValue];
//    BOOL returnKeyPressed = (whyEnd == NSReturnTextMovement);
//    BOOL tabOrBacktabToSelf = ((whyEnd == NSTabTextMovement || whyEnd == NSBacktabTextMovement) && (nextKeyView == nil || nextKeyView == textField));
//    if (returnKeyPressed || tabOrBacktabToSelf)
//        NSLog(@"focus stays");
//    else
//        NSLog(@"focus leaves");
}

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
	CFRelease((__bridge CFTypeRef)(preferencesDialog));
	
	//clear out our global preferences controller. 
	// It will be reinitialized when needed.
	preferencesDialog = nil;
	
}//end dealloc

@end
