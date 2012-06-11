//==============================================================================
//
// File:		InspectionLine.m
//
// Purpose:		Inspector Controller for an LDrawLine.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionLine.h"

#import "LDrawLine.h"
#import "LDrawModel.h"
#import "FormCategory.h"

@implementation InspectionLine

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorLine" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorLine.nib");
    }
    return self;
	
}//end init


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== finishedEditing: ==================================================
//
// Purpose:		Called in response to the conclusion of editing in the palette.
//
//==============================================================================
- (void) commitChanges:(id)sender
{
	LDrawLine *representedObject = [self object];
	
	Point3 vertex1 = [startPoint coordinateValue];
	Point3 vertex2 = [endPoint coordinateValue];
	
	[representedObject setVertex1:vertex1];
	[representedObject setVertex2:vertex2];
	
	[[representedObject enclosingModel] optimizeVertexes];
	[super commitChanges:sender];
	
}//end commitChanges:


//========== revert ============================================================
//
// Purpose:		Restores the palette to reflect the state of the object.
//				This method is called automatically when the object to inspect 
//				is set. Subclasses should override this method to populate 
//				the data in their inspector palettes.
//
//==============================================================================
- (IBAction) revert:(id)sender
{
	LDrawLine *representedObject = [self object];

	[colorWell setLDrawColor:[representedObject LDrawColor]];

	Point3 vertex1 = [representedObject vertex1];
	Point3 vertex2 = [representedObject vertex2];
	
	[startPoint	setCoordinateValue:vertex1];
	[endPoint	setCoordinateValue:vertex2];
	
	[[representedObject enclosingModel] optimizeVertexes];
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== startPointEndedEditing: ===========================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) startPointEndedEditing:(id)sender
{
	Point3 formContents	= [startPoint coordinateValue];
	Point3 vertex1		= [[self object] vertex1];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex1) == NO)
		[self finishedEditing:sender];
		
}//end startPointEndedEditing:


//========== endPointEndedEditing: =================//==========================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) endPointEndedEditing:(id)sender
{
	Point3 formContents	= [endPoint coordinateValue];
	Point3 vertex2		= [[self object] vertex2];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex2) == NO)
		[self finishedEditing:sender];
		
}//end endPointEndedEditing:


@end
