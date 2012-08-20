//==============================================================================
//
// File:		InspectionMPDModel.m
//
// Purpose:		Inspector Controller for an LDrawMPDModel.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/13/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionMPDModel.h"

#import "LDrawFile.h"
#import "LDrawMPDModel.h"
#import "LDrawUtilities.h"

@implementation InspectionMPDModel

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorMPDModel" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorMPDModel.nib");
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
	LDrawMPDModel	*representedObject	= [self object];
	LDrawFile		*enclosingFile		= [representedObject enclosingFile];
	
	NSString				*oldName		= [representedObject modelName];
	NSString				*newName		= [modelNameField	stringValue];
	NSString				*newDescription	= [descriptionField	stringValue];
	NSString				*newAuthor		= [authorField		stringValue];
	
	// For the sake of simplicity, we group these similar fields of the MPD and 
	// regular model together.
	[representedObject setFileName:newName];
	
	[representedObject setModelDescription:newDescription];
	[representedObject setAuthor:newAuthor];
	
	// When renaming the model, also update all references to this submodel 
	// within the entire file (in an undo-friendly way). 
	if([oldName isEqualToString:newName] == NO)
	{
		// The file object is the one responsible for coordinating model 
		// renames, because it has to update references in other submodels. 
		[enclosingFile renameModel:representedObject toName:newName];
	}
	
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
	LDrawMPDModel *representedObject = [self object];

	[modelNameField			setStringValue:[representedObject modelName]		];
	[descriptionField		setStringValue:[representedObject modelDescription]	];
	[authorField			setStringValue:[representedObject author]			];
	
	[numberElementsField setIntegerValue:[representedObject numberElements]];
	[numberStepsField setIntegerValue:[[representedObject steps] count]];
	
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== modelNameFieldChanged: ============================================
//
// Purpose:		The user has changed the model name.
//
//				They may have tried to do something un-kosher with their 
//				modelname too. Beware! 
//
//==============================================================================
- (IBAction) modelNameFieldChanged:(id)sender
{
	NSString *newValue			= [sender stringValue];
	NSString *oldValue			= [[self object] modelName];
	NSString *compliantValue	= [LDrawMPDModel ldrawCompliantNameForName:newValue];
	
	//---------- Error Checking ------------------------------------------------
	
	// They may have entered a name the spec claims is invalid. #@$!@%!
	// But life goes on, we will fix it for them.
	if([newValue isEqualToString:compliantValue] == NO)
	{
		// Use the compliant name, show it in the UI and beep to complain. (I'm 
		// too lazy to write a dialog here.) 
		newValue = compliantValue;
		[self->modelNameField setStringValue:newValue];
		NSBeep();
	}
	
	// Duplicate model names are not allowed, because they cause nasty things to 
	// happen when automatically renaming references to them. 
	if(		[newValue caseInsensitiveCompare:oldValue] != NSOrderedSame				// actually changed the name!
		&&	[[[self object] enclosingFile] modelWithName:newValue] != nil) // is a duplicate!
	{
		NSAlert		*alert		= [[NSAlert alloc] init];
		NSString	*message	= nil;
		
		message = [NSString stringWithFormat:NSLocalizedString(@"DuplicateModelnameMessage", nil), newValue];
		
		[alert setMessageText:message];
		[alert setInformativeText:NSLocalizedString(@"DuplicateModelnameInformative", nil)];
		
		[alert runModal];
		
		// Revert the change; it's not very nice to throw out the user's 
		// changes, but that's what the Finder does! (And it's easy.)
		newValue = oldValue;
		[self->modelNameField setStringValue:newValue];
		
		[alert release];
	}
	
	
	//---------- Apply Change --------------------------------------------------
	
	// If the values really *did* change, then update.
	if([newValue isEqualToString:oldValue] == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end modelNameFieldChanged:


//========== descriptionFieldChanged: ==========================================
//
// Purpose:		The user has changed the model description.
//
//==============================================================================
- (IBAction) descriptionFieldChanged:(id)sender
{
	NSString *newValue	= [sender stringValue];
	NSString *oldValue	= [[self object] modelDescription];
	
	//If the values really did change, then update.
	if([newValue isEqualToString:oldValue] == NO)
		[self finishedEditing:sender];
		
}//end descriptionFieldChanged:


//========== authorFieldChanged: ===============================================
//
// Purpose:		The user has changed the author name.
//
//==============================================================================
- (IBAction) authorFieldChanged:(id)sender
{
	NSString *newValue	= [sender stringValue];
	NSString *oldValue	= [[self object] author];
	
	//If the values really did change, then update.
	if([newValue isEqualToString:oldValue] == NO)
		[self finishedEditing:sender];
		
}//end authorFieldChanged:


@end
