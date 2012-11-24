//==============================================================================
//
// File:		InspectionLine.h
//
// Purpose:		Inspector Controller for an LDrawLine.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LDrawColorWell.h"

@interface InspectionLine : ObjectInspectionController {

	IBOutlet	LDrawColorWell	*colorWell;
	IBOutlet	NSForm			*startPoint;
	IBOutlet	NSForm			*endPoint;
	
}

//Actions
- (IBAction) startPointEndedEditing:(id)sender;
- (IBAction) endPointEndedEditing:(id)sender;

@end
