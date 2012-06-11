//==============================================================================
//
// File:		InspectionTriangle.m
//
// Purpose:		Inspector Controller for an LDrawTriangle.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/9/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionTriangle.h"

#import "LDrawModel.h"
#import "LDrawTriangle.h"
#import "FormCategory.h"

@implementation TriangleView

//========== drawRect: =========================================================
//
// Purpose:		Draw a triangle outline.
//
//==============================================================================
- (void)drawRect:(NSRect)rect
{
	NSBezierPath	*trianglePath	= [NSBezierPath bezierPath];
	NSRect			frame			= NSInsetRect([self bounds], 2, 2);
	
	[trianglePath moveToPoint:NSMakePoint( NSMinX(frame), NSMinY(frame) )];
	[trianglePath lineToPoint:NSMakePoint( NSMaxX(frame), NSMinY(frame) )];
	[trianglePath lineToPoint:NSMakePoint( NSMidX(frame), NSMaxY(frame) )];
	[trianglePath closePath];
	
	[[NSColor grayColor] set];
	[trianglePath setLineWidth:1.5];
	[trianglePath stroke];
	
}//end drawRect:


@end


@implementation InspectionTriangle

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorTriangle" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorTriangle.nib");
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
	LDrawTriangle *representedObject = [self object];
	
	Point3 vertex1 = [vertex1Form coordinateValue];
	Point3 vertex2 = [vertex2Form coordinateValue];
	Point3 vertex3 = [vertex3Form coordinateValue];
	
	[representedObject setVertex1:vertex1];
	[representedObject setVertex2:vertex2];
	[representedObject setVertex3:vertex3];
	
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
	LDrawTriangle *representedObject = [self object];

	[colorWell setLDrawColor:[representedObject LDrawColor]];

	Point3 vertex1 = [representedObject vertex1];
	Point3 vertex2 = [representedObject vertex2];
	Point3 vertex3 = [representedObject vertex3];
	
	[vertex1Form setCoordinateValue:vertex1];
	[vertex2Form setCoordinateValue:vertex2];
	[vertex3Form setCoordinateValue:vertex3];
	
	[[representedObject enclosingModel] optimizeVertexes];
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== vertex1EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex1EndedEditing:(id)sender
{
	Point3 formContents	= [vertex1Form coordinateValue];
	Point3 vertex1		= [[self object] vertex1];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex1) == NO)
		[self finishedEditing:sender];
		
}//end vertex1EndedEditing:


//========== vertex2EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex2EndedEditing:(id)sender
{
	Point3 formContents	= [vertex2Form coordinateValue];
	Point3 vertex2		= [[self object] vertex2];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex2) == NO)
		[self finishedEditing:sender];
		
}//end vertex2EndedEditing:


//========== vertex3EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex3EndedEditing:(id)sender
{
	Point3 formContents	= [vertex3Form coordinateValue];
	Point3 vertex3		= [[self object] vertex3];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex3) == NO)
		[self finishedEditing:sender];
		
}//end vertex3EndedEditing:


@end
