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
#define PREFS_LDRAW_TAB_IDENTIFIER		@"PreferencesTabLDraw"
#define PREFS_STYLE_TAB_IDENTIFIER		@"PreferencesTabStyles"
#define PREFS_LSYNTH_TAB_IDENTIFIER     @"PreferencesTabLSynth"

// The different LSynth selection modes
typedef enum {
    TransparentSelection        = 0,
    ColoredSelection		    = 1,
    TransparentColoredSelection = 2
} LSynthSelectionModeT;


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
    IBOutlet NSView         *lsynthContentView;
	
	// General Tab
	IBOutlet NSForm			*gridSpacingForm;
	IBOutlet NSMatrix		*mouseDraggingRadioButtons;
	
	IBOutlet NSMatrix		*rotateModeRadioButtons;
	IBOutlet NSMatrix		*rightButtonRadioButtons;
	IBOutlet NSMatrix		*mouseWheelRadioButtons;

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
	
    // LSynth Tab
    IBOutlet NSTextField    *lsynthExecutablePath;
    IBOutlet NSTextField    *lsynthConfigurationPath;
    IBOutlet NSMatrix       *lsynthSelectionModeMatrix;
    IBOutlet NSSlider       *lsynthTransparencySlider;
    IBOutlet NSTextField    *lsynthTransparencyText;
    IBOutlet NSColorWell    *lsynthSelectionColorWell;
    
	// Miscellaneous
	IBOutlet NSView			*folderChooserAccessoryView;
    IBOutlet NSView         *lsynthExecutableChooserAccessoryView;
    NSTextField             *lsynthTransparencyNumberChanged;
}
//Initialization
+ (void) doPreferences;
- (void) showPreferencesWindow;

- (void) setDialogValues;
- (void) setGeneralTabValues;
- (void) setStylesTabValues;
- (void) setLDrawTabValues;
- (void) setLSynthTabValues;

//Actions
- (void)changeTab:(id)sender;

// - General Tab
- (IBAction) gridSpacingChanged:(id)sender;
- (IBAction) mouseDraggingChanged:(id)sender;
- (IBAction) rightButtonChanged:(id)sender;
- (IBAction) rotateModeChanged:(id)sender;
- (IBAction) mouseWheelChanged:(id)sender;

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

// - LSynth Tab
- (IBAction)lsynthChooseExecutable:(id)sender;
- (IBAction)lsynthTransparencySliderChanged:(id)sender;
- (IBAction)lsynthTransparencyTextChanged:(id)sender;
- (IBAction)lsynthSelectionColorWellClicked:(id)sender;
- (IBAction)lsynthSelectionModeChanged:(id)sender;



//Utilities
+ (void) ensureDefaults;
- (void) changeLDrawFolderPath:(NSString *) folderPath;
- (void)selectPanelWithIdentifier:(NSString *)itemIdentifier;

@end
