//==============================================================================
//
// File:		RotationPanel.m
//
// Purpose:		Advanced rotation controls for doing relative rotations on 
//				groups of parts. This is not meant to provide absolute rotations 
//				for individual parts. It simply works on the current selection, 
//				whatever that may be.
//
//  Created by Allen Smith on 8/27/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "RotationPanel.h"


@implementation RotationPanel

RotationPanel *sharedRotationPanel = nil;

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- rotationPanel -------------------------------------------[static]--
//
// Purpose:		Returns a rotation panel to open.
//
//------------------------------------------------------------------------------
+ (id) rotationPanel
{
	if(sharedRotationPanel == nil)
		sharedRotationPanel = [[RotationPanel alloc] init];
		
	return sharedRotationPanel;
	
}//end rotationPanel


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== panelNibName ======================================================
//
// Purpose:		Identifies to our superclass the nib to load.
//
//==============================================================================
- (NSString *) panelNibName
{
	return @"RotationPanel";

}//end panelNibName


//========== enableFixedPointCoordinates =======================================
//
// Purpose:		Identifies to our superclass the nib to load.
//
//==============================================================================
- (BOOL) enableFixedPointCoordinates
{
	return (self->rotationMode == RotateAroundFixedPoint);
	
}//end enableFixedPointCoordinates


//========== angles ============================================================
//
// Purpose:		Returns the number of degrees around x, y, and z by which the 
//				selection should be rotated.
//
//==============================================================================
- (Tuple3) angles
{
	return V3Make(angleX, angleY, angleZ);

}//end angles


//========== fixedPoint ========================================================
//
// Purpose:		Returns the center of rotation.
//
// Note:		This value is only valid if the rotation mode is 
//				RotateAroundFixedPoint.
//
//==============================================================================
- (Point3) fixedPoint
{
	return V3Make(fixedPointX, fixedPointY, fixedPointZ);

}//end fixedPoint


//========== rotationMode ======================================================
//
// Purpose:		Returns the current rotation behavior.
//
//==============================================================================
- (RotationModeT) rotationMode
{
	return self->rotationMode;
	
}//end rotationMode


//---------- keyPathsForValuesAffectingValueForKey: ------------------[static]--
//
// Purpose:		Register bindings stuff.
//
//------------------------------------------------------------------------------
+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *triggerKeys = nil;

	if([key isEqualToString:@"enableFixedPointCoordinates"])
	{
		triggerKeys = [NSSet setWithObject:@"rotationMode"];
	}
	else
	{
		triggerKeys = [super keyPathsForValuesAffectingValueForKey:key];
	}
	
	return triggerKeys;

}//end keyPathsForValuesAffectingValueForKey:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== rotateButtonClicked: ==============================================
//
// Purpose:		Translates the button action into the standard rotate panel 
//				action and sets the sender to the RotationPanel itself.
//
//==============================================================================
- (IBAction) rotateButtonClicked:(id)sender
{
	[NSApp sendAction:@selector(panelRotateParts:) to:nil from:self];

}//end rotateButtonClicked:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		For everything there is a season/(turn, turn, turn)/a time for 
//				every purpose under heaven/(turn, turn, turn)/a time be born, 
//				a time to DIE!!!/(turn, turn, turn)/...
//
//==============================================================================
- (void) dealloc
{
	[formatterAngles	release];
	[formatterPoints	release];
	
	[super dealloc];

}//end dealloc


@end
