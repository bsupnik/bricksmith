//==============================================================================
//
// File:		InspectionMPDModel.h
//
// Purpose:		Inspector Controller for an LDrawMPDModel.
//
//  Created by Allen Smith on 3/13/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"

@interface InspectionMPDModel : ObjectInspectionController
{
	__weak IBOutlet	NSTextField		*modelNameField;
	__weak IBOutlet	NSTextField		*descriptionField;
	__weak IBOutlet	NSTextField		*authorField;
	
	__weak IBOutlet	NSTextField		*numberStepsField;
	__weak IBOutlet	NSTextField		*numberElementsField;
}

//Actions
- (IBAction) modelNameFieldChanged:(id)sender;
- (IBAction) descriptionFieldChanged:(id)sender;
- (IBAction) authorFieldChanged:(id)sender;

@end
