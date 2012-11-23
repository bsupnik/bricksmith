//==============================================================================
//
// File:		RotationPanelController.h
//
// Purpose:		Advanced rotation controls for doing relative rotations on 
//				groups of parts.
//
//  Created by Allen Smith on 8/27/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "DialogPanel.h"
#import "MatrixMath.h"

typedef enum {
	
	RotateAroundSelectionCenter	= 0,
	RotateAroundPartPositions	= 1,
	RotateAroundFixedPoint		= 2
	
} RotationModeT;

@interface RotationPanelController : NSWindowController 
{
	RotationModeT	rotationMode;
	float			angleX;
	float			angleY;
	float			angleZ;
	float			fixedPointX;
	float			fixedPointY;
	float			fixedPointZ;
	
	IBOutlet NSObjectController	*objectController;
}

//initialization
+ (id) rotationPanel;

//accessors
- (BOOL) enableFixedPointCoordinates;
- (Tuple3) angles;
- (Point3) fixedPoint;
- (RotationModeT) rotationMode;

//Actions
- (IBAction) rotateButtonClicked:(id)sender;

@end
