//==============================================================================
//
// File:		InspectionUnknownCommand.m
//
// Purpose:		Inspector Controller for an LDrawMetaCommand.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionUnknownCommand.h"

#import "LDrawMetaCommand.h"

@implementation InspectionUnknownCommand

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorUnknownCommand" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorUnknownCommand.nib");
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
	LDrawMetaCommand *representedObject = [self object];
	
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
	LDrawMetaCommand *representedObject = [self object];

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
	NSString *newCommand	= [commandField stringValue];
	NSString *oldCommand	= [[self object] stringValue];
	
	//If the values really did change, then update.
	if([newCommand isEqualToString:oldCommand] == NO)
		[self finishedEditing:sender];
		
}//end commandFieldChanged:


@end
