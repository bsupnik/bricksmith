//==============================================================================
//
// File:		PartChooserPanel.m
//
// Purpose:		Presents a PartBrower in a dialog. It has a larger preview, so 
//				it isn't as cramped as the Parts drawer.
//
//  Created by Allen Smith on 4/3/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartChooserPanel.h"

#import <Carbon/Carbon.h>
#import "PartBrowserDataSource.h"

@implementation PartChooserPanel

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- partChooserPanel ----------------------------------------[static]--
//
// Purpose:		Returns a brand new part chooser ready to run.
//
//------------------------------------------------------------------------------
+ (PartChooserPanel *) partChooserPanel
{
	return [[[PartChooserPanel alloc] init] autorelease];
	
}//end partChooserPanel


//========== init ==============================================================
//
// Purpose:		Brings the LDraw part chooser panel to life.
//
//==============================================================================
- (id) init
{	
	[NSBundle loadNibNamed:@"PartChooser" owner:self];
	
	oldSelf = self;
	self = partChooserPanel; //this don't look good, but it works.
						//this takes the place of calling [super init]
						// Note that connections in the Nib file must be made 
						// to the partChooserPanel, not to the File's Owner!
	//[oldSelf autorelease];
			
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -


//========== selectedPartName ==================================================
//
// Purpose:		Returns the name of the selected part file.
//				i.e., "3001.dat"
//
//==============================================================================
- (NSString *) selectedPartName
{
	return [partsBrowser selectedPartName];
	
}//end selectedPartName


#pragma mark -
#pragma mark ACTIONS
#pragma mark -


//========== runModal ==========================================================
//
// Purpose:		Displays the dialog, returing NSOKButton or NSCancelButton as 
//				appropriate.
//
//==============================================================================
- (NSInteger) runModal
{
	NSInteger   returnCode  = NSCancelButton;
		
	//Run the dialog.
	returnCode = [NSApp runModalForWindow:self];
	
	if(returnCode == NSOKButton)
		[self->partsBrowser addPartClicked:nil];
	
	return returnCode;

}//end runModal



//========== insertPartClicked: ================================================
//
// Purpose:		The dialog has ended and the part should be inserted.
//
//==============================================================================
- (IBAction) insertPartClicked:(id)sender
{
	[NSApp stopModalWithCode:NSOKButton];
	
}//end insertPartClicked:


//========== cancelClicked: ====================================================
//
// Purpose:		The dialog has ended and the part should NOT be inserted.
//
//==============================================================================
- (IBAction) cancelClicked:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	
}//end cancelClicked:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're checking out of this fleabag hotel.
//
//==============================================================================
- (void) dealloc
{
	[oldSelf		release];
	[partsBrowser	release];
	
	[super dealloc];
	
}//end dealloc


@end
