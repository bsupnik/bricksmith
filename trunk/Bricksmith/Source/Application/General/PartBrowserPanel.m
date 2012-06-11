//==============================================================================
//
// File:		PartBrowserPanel.m
//
// Purpose:		Presents a PartBrower in a dialog. It has a larger preview, so 
//				it isn't as cramped as the Parts drawer.
//
//  Created by Allen Smith on 4/3/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartBrowserPanel.h"

#import "PartBrowserDataSource.h"
#import "ExtendedSplitView.h"

@implementation PartBrowserPanel

static PartBrowserPanel *sharedPartBrowserPanel = nil;


//========== awakeFromNib ======================================================
//
// Purpose:		Finish object setup.
//
//==============================================================================
- (void) awakeFromNib
{
	[self->splitView setAutosaveName:@"PartBrowserPanelSplitView"];
	[self->splitView restoreConfiguration];

}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- sharedPartBrowserPanel ----------------------------------[static]--
//
// Purpose:		Returns the application-wide instance of the PartBrowserPanel.
//
//------------------------------------------------------------------------------
+ (PartBrowserPanel *) sharedPartBrowserPanel
{
	if(sharedPartBrowserPanel == nil)
		sharedPartBrowserPanel = [[PartBrowserPanel alloc] init];

	return sharedPartBrowserPanel;
	
}//end sharedPartBrowserPanel


//========== init ==============================================================
//
// Purpose:		Brings the LDraw part chooser panel to life.
//
//==============================================================================
- (id) init
{	
	// I don't believe we want *anything* from the old "self" of this object. 
	// Everything is coming from the Nib file. 
//	self = [super init];
	
	[NSBundle loadNibNamed:@"PartBrowser" owner:self];
	id newself = partBrowserPanel;

	[self release];
	
	return newself;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== partBrowser =======================================================
//
// Purpose:		Returns the Part Browser for the panel. It contains handy 
//			    information such as the currently-selected part. 
//
//==============================================================================
- (PartBrowserDataSource *) partBrowser
{
	return self->partsBrowser;
	
}//end partBrowser


#pragma mark -
#pragma mark WINDOW
#pragma mark -

//========== close =============================================================
//
// Purpose:		There is a known bug in NSOpenGLView whereby a GLView will 
//				destroy its graphics context when its enclosing window is 
//			    closed. The trouble is, if that window is repopened again, the 
//			    GL context won't regenerate.
//
//				As a workaround, we release the entire window each time it is 
//			    closed. If reopened, the window will be reallocated from 
//			    scratch. 
//
//==============================================================================
- (void)close
{
	//Make sure our memory is all released.
	sharedPartBrowserPanel = nil;
	[self autorelease];
	
	[super close];

}//end windowWillClose:


//========== splitView:constrainMinCoordinate:ofSubviewAt: =====================
//
// Purpose:		Don't allow the view portions to shrink too much.
//
//==============================================================================
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return 96;
	
}//end splitView:constrainMinCoordinate:ofSubviewAt:


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
	[partsBrowser	release];
	
	[super dealloc];
	
}//end dealloc


@end
