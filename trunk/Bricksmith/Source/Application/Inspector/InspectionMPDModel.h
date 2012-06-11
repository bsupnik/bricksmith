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

@interface InspectionMPDModel : ObjectInspectionController {

	IBOutlet	NSTextField		*modelNameField;
	IBOutlet	NSTextField		*descriptionField;
	IBOutlet	NSTextField		*authorField;
	
	IBOutlet	NSPopUpButton	*ldrawDotOrgPopUp;
	
	IBOutlet	NSTextField		*numberStepsField;
	IBOutlet	NSTextField		*numberElementsField;
	
}

//Actions
- (IBAction) modelNameFieldChanged:(id)sender;
- (IBAction) descriptionFieldChanged:(id)sender;
- (IBAction) authorFieldChanged:(id)sender;
- (IBAction) ldrawDotOrgPopUpClicked:(id)sender;

@end
