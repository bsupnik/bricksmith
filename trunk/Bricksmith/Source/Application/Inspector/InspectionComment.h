//==============================================================================
//
// File:		InspectionComment.h
//
// Purpose:		Inspector Controller for an LDrawComment.
//
//  Created by Allen Smith on 3/13/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"

@interface InspectionComment : ObjectInspectionController {

	IBOutlet	NSTextField		*commandField;
	
}

//Actions
- (IBAction) commandFieldChanged:(id)sender;

@end
