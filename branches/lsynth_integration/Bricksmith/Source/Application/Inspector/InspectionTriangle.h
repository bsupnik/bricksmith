//==============================================================================
//
// File:		InspectionTriangle.h
//
// Purpose:		Inspector Controller for an LDrawTriangle.
//
//  Created by Allen Smith on 3/9/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LDrawColorWell.h"

@interface InspectionTriangle : ObjectInspectionController {

	IBOutlet	LDrawColorWell	*colorWell;
	IBOutlet	NSForm			*vertex1Form;
	IBOutlet	NSForm			*vertex2Form;
	IBOutlet	NSForm			*vertex3Form;
	
}

//Actions
- (IBAction) vertex1EndedEditing:(id)sender;
- (IBAction) vertex2EndedEditing:(id)sender;
- (IBAction) vertex3EndedEditing:(id)sender;

@end


//Simple class that draws a triangle shape.
// Used as a graphic in the inspector.
@interface TriangleView : NSView {
}
@end
