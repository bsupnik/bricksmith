//==============================================================================
//
// File:		MovePanel.h
//
// Purpose:		Manual movement control.
//
//  Created by Allen Smith on 8/27/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "DialogPanel.h"
#import "MatrixMath.h"

@interface MovePanel : DialogPanel
{
	float			movementX;
	float			movementY;
	float			movementZ;
	
	IBOutlet NSFormatter	*formatterPoints;
}

//initialization
+ (id) movePanel;

//accessors
- (Vector3) movementVector;

//actions
- (IBAction) moveButtonClicked:(id)sender;

@end
