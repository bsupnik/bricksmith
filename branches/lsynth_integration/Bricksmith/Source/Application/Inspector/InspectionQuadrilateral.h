//==============================================================================
//
// File:		InspectionQuadrilateral.h
//
// Purpose:		Inspector Controller for an LDrawQuadrilateral.
//
//  Created by Allen Smith on 3/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LDrawColorWell.h"

@interface InspectionQuadrilateral : ObjectInspectionController {

	IBOutlet	LDrawColorWell	*colorWell;
	IBOutlet	NSForm			*vertex1Form;
	IBOutlet	NSForm			*vertex2Form;
	IBOutlet	NSForm			*vertex3Form;
	IBOutlet	NSForm			*vertex4Form;
	
}

//Actions
- (IBAction) vertex1EndedEditing:(id)sender;
- (IBAction) vertex2EndedEditing:(id)sender;
- (IBAction) vertex3EndedEditing:(id)sender;
- (IBAction) vertex4EndedEditing:(id)sender;

@end


//Simple class that draws a quadrilateral shape.
// Used as a graphic in the inspector.
@interface QuadrilateralView : NSView {
}
@end
