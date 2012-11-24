//==============================================================================
//
// File:		DialogPanel.m
//
// Purpose:		Abstract superclass which facilitates creating dialogs that 
//				extend NSPanel. This handles the weirdo memory management 
//				associated with doing that. We also provided memory management 
//				for an NSObjectController for bindings.
//
//				Subclasses must override -panelNibName.
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "DialogPanel.h"


@implementation DialogPanel

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Loads the panel from the Nib file specified by the subclass and 
//				returns it.
//
// Notes:		Subclasses MUST call this method by writing
//					self = [super init];
//				Because the object returned by this method will ALWAYS be 
//				different from the receiver.
//				
//				Yes, memory management is tricky here. The receiver is a 
//				throwaway object that exists soley to load a Nib file. We then 
//				junk the receiver and return a reference to the panel it loaded 
//				in the Nib. Tricky, huh?
//
//==============================================================================
- (id) init
{
	[NSBundle loadNibNamed:[self panelNibName] owner:self];
	
	//this don't look good, but it works.
	//this takes the place of calling [super init]
	// Note that connections in the Nib file must be made 
	// to the PieceCountPanel, not to the File's Owner!
	[self autorelease];
	
	return dialogPanel;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== panelNibName ======================================================
//
// Purpose:		Subclasses must override this method to return the name of the 
//				Nib which contains the desired panel.
//
// Notes:		The Nib should have this object as the File's Owner, but should 
//				also contain another instance of this class to which all other 
//				connections are made.
//
//==============================================================================
- (NSString *) panelNibName
{
	NSLog(@"No Nib name has been specified for this panel!");
	
	return nil;
	
}//end panelNibName


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== okButtonClicked: ==================================================
//
// Purpose:		End the sheet (we are the sheet--or at least we'd better be!)
//
//==============================================================================
- (IBAction) okButtonClicked:(id)sender
{
	[NSApp endSheet:self];
	[self close];
	
	//The object controller apparently retains its content. We must break that 
	// cycle in order to fully deallocate.
	[objectController setContent:nil];
	
}//end okButtonClicked:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Our goose is cooked.
//
//==============================================================================
- (void) dealloc
{
	[objectController	release];
	
	[super dealloc];
	
}//end dealloc


@end
