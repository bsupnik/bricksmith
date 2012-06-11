//==============================================================================
//
// File:		InspectionStep.h
//
// Purpose:		Inspector controller for LDrawSteps.
//
// Modified:	9/7/08 Allen Smith. Creation date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"

typedef enum
{
	InspectorRotationShortcutCustom				= -1, // tag for both relative and absolute
	InspectorRotationShortcutUpsideDown			= 0,
	InspectorRotationShortcutClockwise90		= 1,
	InspectorRotationShortcutCounterClockwise90	= 2,
	InspectorRotationShortcutBackside			= 3
	// the rest of the tags match ViewOrientationT
	
} StepInspectorRotationShortcutT;


////////////////////////////////////////////////////////////////////////////////
//
// class InspectionStep
//
////////////////////////////////////////////////////////////////////////////////
@interface InspectionStep : ObjectInspectionController
{
	IBOutlet NSMatrix			*rotationTypeRadioButtons;

	IBOutlet NSPopUpButton		*relativeRotationPopUpMenu;
	IBOutlet NSPopUpButton		*absoluteRotationPopUpMenu;
	
	IBOutlet NSTextField		*rotationXField;
	IBOutlet NSTextField		*rotationYField;
	IBOutlet NSTextField		*rotationZField;
	IBOutlet NSButton			*useCurrentAngleButton;
}

// Constraints
- (void) updateConstraints;

// Actions
- (IBAction) rotationTypeRadioButtonsClicked:(id)sender;
- (IBAction) relativeRotationPopUpMenuChanged:(id)sender;
- (IBAction) absoluteRotationPopUpMenuChanged:(id)sender;
- (IBAction) useCurrentViewingAngleClicked:(id)sender;
- (IBAction) doHelp:(id)sender;

// Utilities
- (void) setAngleUIAccordingToPopUp;

@end
