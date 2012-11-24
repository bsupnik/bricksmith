//==============================================================================
//
// File:		InspectionConditionalLine.h
//
// Purpose:		Inspector Controller for an LDrawConditionalLine.
//
//  Created by Allen Smith on 3/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LDrawColorWell.h"

@interface InspectionConditionalLine : ObjectInspectionController {

	IBOutlet	LDrawColorWell	*colorWell;
	IBOutlet	NSForm			*vertex1Form;
	IBOutlet	NSForm			*vertex2Form;
	IBOutlet	NSForm			*conditionalVertex1Form;
	IBOutlet	NSForm			*conditionalVertex2Form;
	
}

//Actions
- (IBAction) vertex1EndedEditing:(id)sender;
- (IBAction) vertex2EndedEditing:(id)sender;
- (IBAction) conditionalVertex1EndedEditing:(id)sender;
- (IBAction) conditionalVertex2EndedEditing:(id)sender;

@end
