//==============================================================================
//
// File:		InspectionPart.h
//
// Purpose:		Inspector Controller for an LDrawPart.
//
//  Created by Allen Smith on 3/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LDrawColorWell.h"

////////////////////////////////////////////////////////////////////////////////
//
// Data Types
//
////////////////////////////////////////////////////////////////////////////////
typedef enum
{
	rotationAbsolute = 0,
	rotationRelative = 1
	
} RotationT;


////////////////////////////////////////////////////////////////////////////////
//
// class InspectionPart
//
////////////////////////////////////////////////////////////////////////////////
@interface InspectionPart : ObjectInspectionController
{
	IBOutlet	NSTextField			*partDescriptionField;
	IBOutlet	NSTextField			*partNameField;
	IBOutlet	LDrawColorWell		*colorWell;
	IBOutlet	NSForm				*locationForm;
	IBOutlet	NSPopUpButton		*rotationTypePopUp;
	IBOutlet	NSTextField			*rotationXField;
	IBOutlet	NSTextField			*rotationYField;
	IBOutlet	NSTextField			*rotationZField;
	IBOutlet	NSForm				*scalingForm;
	IBOutlet	NSForm				*shearForm;
	
	IBOutlet	NSNumberFormatter	*formatterBasic;
	IBOutlet	NSNumberFormatter	*formatterAngle;
	IBOutlet	NSNumberFormatter	*formatterScale;
	
}

- (void) setRotationAngles;

//Actions
- (IBAction) applyRotationClicked:(id)sender;
- (IBAction) locationEndedEditing:(id)sender;
- (IBAction) partNameEndedEditing:(id)sender;
- (IBAction) rotationTypeChanged:(id)sender;
- (IBAction) scalingEndedEditing:(id)sender;
- (IBAction) shearEndedEditing:(id)sender;

@end
