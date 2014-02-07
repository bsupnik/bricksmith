//==============================================================================
//
// File:		ObjectInspectionController.m
//
// Purpose:		Base class for all LDraw inspectors. Each inspector subclass 
//				should load an associated Nib file containing a window with the 
//				inspection controls for that class, and should implement the 
//				methods -finishedEditing: and -revert:.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "ObjectInspectionController.h"

#import "LDrawDirective.h"
#import "LDrawDocument.h"
#import "MacLDraw.h"


@implementation ObjectInspectionController

//========== init ==============================================================
//
// Purpose:		Subclass implementations should load a Nib file containing their 
//				inspector.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	//Subclasses need to do something like this:
//	if(window == nil){
//		if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO) {
//			NSLog(@"Can't load Inspector nib file");
//		}
//		
//	}
//	
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== object ============================================================
//
// Purpose:		Returns the object this inspector is editing.
//
//==============================================================================
- (id) object
{
	return editingObject;
	
}//end object


//========== setObject =========================================================
//
// Purpose:		Sets up the object to edit. This is called when creating the 
//				class.
//
//==============================================================================
- (void) setObject:(id)newObject
{
	if(newObject != editingObject)
	{
		//De-register any possible notification observer for the previous editing 
		// object. In normal circumstances, there never is a previous object, so 
		// this method is pointless. It is only here as a safeguard.
		[[NSNotificationCenter defaultCenter]
				removeObserver:self
						  name:LDrawDirectiveDidChangeNotification
						object:nil ];
		
		//Retain-release in preparation for changing the instance variable.
		[newObject retain];
		[editingObject release];
		
		//Update the the object being edited.
		editingObject = newObject;
		[self revert:self]; //calling revert should set the values of the palette.
		
		//We want to know when our object changes out from under us.
		[[NSNotificationCenter defaultCenter]
				addObserver:self
				   selector:@selector(directiveDidChange:)
					   name:LDrawDirectiveDidChangeNotification
					 object:newObject ];
	}
	
}//end setObject:


//========== window ============================================================
//
// Purpose:		Returns the window in the Nib file that contains the inspection 
//				palette. Upon instantiation, this window will be eviscerated of 
//				its inspector palette, which will be transplanted into the 
//				shared inspector panel.
//
//==============================================================================
- (NSWindow *) window
{
	return window;
	
}//end window


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== commitChanges: ====================================================
//
// Purpose:		Implemented by subclasses to apply the attributes in the 
//				inspector panel to their represented object.
//
//				NEVER CALL THIS METHOD DIRECTLY. It is automatically called by 
//				-finishedEditing:.
//
// Parameters:	sender:	the object passed to -finishedEditing:.
//
//==============================================================================
- (void) commitChanges:(id)sender
{
	//Subclasses should implement this method to update their editing objects.

}//end commitChanges:


//========== finishedEditing: ==================================================
//
// Purpose:		Called in response to the conclusion of editing in the palette.
//
//==============================================================================
- (IBAction)finishedEditing:(id)sender
{
	LDrawDirective  *representedObject  = [self object];
	LDrawDocument   *currentDocument    = [[NSDocumentController sharedDocumentController] currentDocument];
	
	// Note: This code is tightly coupled to the LDrawDocument to support 
	//		 registering undo actions and providing a persistent target for 
	//		 receiving invertible redo actions. 
	//
	//		 Apple's Interface Builder 2.0 palette model (upon which this was 
	//		 based) had a magic method called 
	//		 -noteAttributesWillChangeForObject:. Somehow, it just *knew* how to 
	//		 record state changes for undo. I have absolutely no idea how that 
	//		 worked. 
	
	//prepare: do undo stuff and thread safety.
	[currentDocument preserveDirectiveState:representedObject];
	[representedObject lockForEditing];
	
	//let the subclass have a go at it.
	[self commitChanges:sender];
	
	//done editing; clean up
	[representedObject unlockEditor];
	
	[representedObject noteNeedsDisplay];

    // Someone else might care that the part has changed
    [representedObject sendMessageToObservers:MessageObservedChanged];

}//end finishedEditing:


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
	//does nothing, yet.
	
}//end revert:


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== directiveDidChange: ===============================================
//
// Purpose:		Called when the directive we are inspecting is modified by 
//				some external action (like undo/redo).
//
//==============================================================================
- (void) directiveDidChange:(NSNotification *)notification
{
	//Update our state so we are not stale.
	[self revert:self];
	
}//end directiveDidChange:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're booking a one-way cruise on Charon's ferry.
//
//==============================================================================
- (void) dealloc
{
	//Cancel notification registration
	[[NSNotificationCenter defaultCenter] removeObserver:self ];
	
	//Release top-level nib objects and instance variables.
	[window			release];
	[editingObject	release];
	
	[super dealloc];
	
}//end dealloc


@end
