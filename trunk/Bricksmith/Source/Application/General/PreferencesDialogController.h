//==============================================================================
//
// File:		PreferencesDialogController.h
//
// Purpose:		Handles the user interface between the application and its 
//				preferences file.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

//Toolbar Tab Identifiers
#define PREFS_GENERAL_TAB_IDENTIFIER	@"PreferencesTabGeneral"
#define PREFS_LDRAW_TAB_IDENTFIER		@"PreferencesTabLDraw"
#define PREFS_STYLE_TAB_IDENTFIER		@"PreferencesTabStyles"


////////////////////////////////////////////////////////////////////////////////
//
// class PreferencesDialogController
//
////////////////////////////////////////////////////////////////////////////////
@interface PreferencesDialogController : NSObject <NSToolbarDelegate>
{
    IBOutlet NSWindow		*preferencesWindow;
	
			 NSView			*blankContent; //the initial, empty content of the window in the Nib.
	IBOutlet NSView			*generalTabContentView;
	IBOutlet NSView			*stylesContentView;
	IBOutlet NSView			*ldrawContentView;
	
	// General Tab
	IBOutlet NSForm			*gridSpacingForm;
	IBOutlet NSMatrix		*mouseDraggingRadioButtons;

	// Parts Tab
    IBOutlet NSTextField	*LDrawPathTextField;
    IBOutlet NSMatrix		*partBrowserStyleRadioButtons;
	
	// Style Tab
	IBOutlet NSColorWell	*backgroundColorWell;
	
	IBOutlet NSColorWell	*modelsColorWell;
	IBOutlet NSColorWell	*stepsColorWell;
	IBOutlet NSColorWell	*partsColorWell;
	IBOutlet NSColorWell	*primitivesColorWell;
	IBOutlet NSColorWell	*colorsColorWell;
	IBOutlet NSColorWell	*commentsColorWell;
	IBOutlet NSColorWell	*unknownColorWell;
	
	// Miscellaneous
	IBOutlet NSView			*folderChooserAccessoryView;
	
}
//Initialization
+ (void) doPreferences;
- (void) showPreferencesWindow;

- (void) setDialogValues;
- (void) setGeneralTabValues;
- (void) setStylesTabValues;
- (void) setLDrawTabValues;

//Actions
- (void)changeTab:(id)sender;

// - General Tab
- (IBAction) gridSpacingChanged:(id)sender;
- (IBAction) mouseDraggingChanged:(id)sender;

// - Styles Tab
- (IBAction) backgroundColorWellChanged:(id)sender;
- (IBAction) modelsColorWellChanged:(id)sender;
- (IBAction) stepsColorWellChanged:(id)sender;
- (IBAction) partsColorWellChanged:(id)sender;
- (IBAction) primitivesColorWellChanged:(id)sender;
- (IBAction) colorsColorWellChanged:(id)sender;
- (IBAction) commentsColorWellChanged:(id)sender;
- (IBAction) unknownColorWellChanged:(id)sender;

// - LDraw Tab
- (IBAction) chooseLDrawFolder:(id)sender;
- (IBAction) pathTextFieldChanged:(id)sender;
- (IBAction) reloadParts:(id)sender;
- (IBAction) partBrowserStyleChanged:(id)sender;

//Utilities
+ (void) ensureDefaults;
- (void) changeLDrawFolderPath:(NSString *) folderPath;
- (void)selectPanelWithIdentifier:(NSString *)itemIdentifier;

@end
