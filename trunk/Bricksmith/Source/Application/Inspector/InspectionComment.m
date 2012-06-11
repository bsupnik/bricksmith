//==============================================================================
//
// File:		InspectionComment.m
//
// Purpose:		Inspector Controller for an LDrawComment.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/13/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionComment.h"

#import "LDrawComment.h"

@implementation InspectionComment

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorComment" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorComment.nib");
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
	LDrawComment *representedObject = [self object];
	
	NSString *newCommand = [commandField stringValue];
	
	[representedObject setStringValue:newCommand];
	
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
	LDrawComment *representedObject = [self object];

	[commandField setStringValue:[representedObject stringValue]];
	
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== commandFieldChanged: ==============================================
//
// Purpose:		The user has changed the string that makes up this command.
//
//==============================================================================
- (IBAction) commandFieldChanged:(id)sender
{
	NSString *newComment	= [commandField stringValue];
	NSString *oldComment	= [[self object] stringValue];
	
	//If the values really did change, then update.
	if([newComment isEqualToString:oldComment] == NO)
		[self finishedEditing:sender];
		
}//end commandFieldChanged:


@end
