//==============================================================================
//
// File:		MovePanel.m
//
// Purpose:		Manual movement control.
//
//				Sends the nil-targeted action panelMoveParts:.
//
//  Created by Allen Smith on 8/27/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "MovePanel.h"


@implementation MovePanel

MovePanel *sharedMovePanel = nil;

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- movePanel -----------------------------------------------[static]--
//
// Purpose:		Returns a move panel to open.
//
//------------------------------------------------------------------------------
+ (id) movePanel
{
	if(sharedMovePanel == nil)
		sharedMovePanel = [[MovePanel alloc] init];
	
	return sharedMovePanel;
	
}//end movePanel


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
	return @"MovePanel";
	
}//end panelNibName


//========== movementVector ====================================================
//
// Purpose:		Returns the number of LDraw units to move along x, y, and z.
//
//==============================================================================
- (Vector3) movementVector
{
	return V3Make(movementX, movementY, movementZ);
	
}//end movementVector


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== moveButtonClicked: ================================================
//
// Purpose:		Translates the button action into the standard move panel action 
//				and sets the sender to the MovePanel itself.
//
//==============================================================================
- (IBAction) moveButtonClicked:(id)sender
{
	[NSApp sendAction:@selector(panelMoveParts:) to:nil from:self];
	
}//end moveButtonClicked:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Moving on to greener pastures.
//
//==============================================================================
- (void) dealloc
{
	[formatterPoints release];
	
	[super dealloc];
	
}//end dealloc


@end
