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
@interface PreferencesDialogController : NSObject <NSToolbarDelegate, NSTextFieldDelegate>
{
		   IBOutlet NSWindow		*preferencesWindow;
	
	__weak          NSView			*blankContent; //the initial, empty content of the window in the Nib.
	__weak IBOutlet NSView			*generalTabContentView;
	__weak IBOutlet NSView			*stylesContentView;
	__weak IBOutlet NSView			*ldrawContentView;
	__weak IBOutlet NSView			*lsynthContentView;
	
	// General Tab
	__weak IBOutlet NSMatrix		*mouseDraggingRadioButtons;
	
	__weak IBOutlet NSMatrix		*rotateModeRadioButtons;
	__weak IBOutlet NSMatrix		*rightButtonRadioButtons;
	__weak IBOutlet NSMatrix		*mouseWheelRadioButtons;

	// Parts Tab
	__weak IBOutlet NSTextField		*LDrawPathTextField;
	__weak IBOutlet NSMatrix		*partBrowserStyleRadioButtons;
	
	// Style Tab
	__weak IBOutlet NSColorWell		*backgroundColorWell;
	
	__weak IBOutlet NSColorWell		*modelsColorWell;
	__weak IBOutlet NSColorWell		*stepsColorWell;
	__weak IBOutlet NSColorWell		*partsColorWell;
	__weak IBOutlet NSColorWell		*primitivesColorWell;
	__weak IBOutlet NSColorWell		*colorsColorWell;
	__weak IBOutlet NSColorWell		*commentsColorWell;
	__weak IBOutlet NSColorWell		*unknownColorWell;
	
    // LSynth Tab
	__weak IBOutlet NSTextField    	*lsynthExecutablePath;
	__weak IBOutlet NSTextField    	*lsynthConfigurationPath;
	__weak IBOutlet NSMatrix       	*lsynthSelectionModeMatrix;
	__weak IBOutlet NSSlider       	*lsynthTransparencySlider;
	__weak IBOutlet NSTextField    	*lsynthTransparencyText;
	__weak IBOutlet NSColorWell    	*lsynthSelectionColorWell;
	__weak IBOutlet NSButton       	*lsynthSaveSynthesizedParts;
	__weak IBOutlet NSView         	*lsynthExecutableChooserAccessoryView;
	__weak IBOutlet NSView         	*lsynthConfigurationChooserAccessoryView;
	__weak NSTextField             	*lsynthTransparencyNumberChanged;
	__weak IBOutlet NSButton       	*lsynthShowBasicPartsList;
    
    // Miscellaneous
	__weak IBOutlet NSView			*folderChooserAccessoryView;
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
- (IBAction) lsynthChooseExecutable:(id)sender;
- (IBAction) lsynthChooseConfiguration:(id)sender;
- (IBAction) lsynthTransparencySliderChanged:(id)sender;
- (IBAction) lsynthTransparencyTextChanged:(id)sender;
- (IBAction) lsynthSelectionColorWellClicked:(id)sender;
- (IBAction) lsynthSelectionModeChanged:(id)sender;
- (IBAction) lsynthSaveSynthesizedPartsChanged:(id)sender;
- (IBAction) lsynthShowBasicPartsListChanged:(id)sender;

//Utilities
+ (void) ensureDefaults;
- (void) changeLDrawFolderPath:(NSString *) folderPath;
- (void) selectPanelWithIdentifier:(NSString *)itemIdentifier;

@end
