//==============================================================================
//
// File:		PartBrowserPanelController.m
//
// Purpose:		Presents a PartBrower in a dialog. It has a larger preview, so 
//				it isn't as cramped as the Parts drawer.
//
//  Created by Allen Smith on 4/3/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartBrowserPanelController.h"

#import "PartBrowserDataSource.h"
#import "ExtendedSplitView.h"

@implementation PartBrowserPanelController

static PartBrowserPanelController *sharedPartBrowserPanel = nil;


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


//========== windowDidLoad =====================================================
//==============================================================================
- (void)windowDidLoad
{
	[self->partsBrowser scrollSelectedCategoryToCenter];

}

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- sharedPartBrowserPanel ----------------------------------[static]--
//
// Purpose:		Returns the application-wide instance of the PartBrowserPanel.
//
//------------------------------------------------------------------------------
+ (PartBrowserPanelController *) sharedPartBrowserPanel
{
	if(sharedPartBrowserPanel == nil)
		sharedPartBrowserPanel = [[PartBrowserPanelController alloc] init];

	return sharedPartBrowserPanel;
	
}//end sharedPartBrowserPanel


//========== init ==============================================================
//
// Purpose:		Brings the LDraw part chooser panel to life.
//
//==============================================================================
- (id) init
{	
	self = [super initWithWindowNibName:@"PartBrowser"];
	
	return self;
	
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
#pragma mark DELEGATES
#pragma mark -

//**** NSWindow ****
//========== windowWillClose: ==================================================
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
- (void)windowWillClose:(NSNotification *)notification
{
	//Make sure our memory is all released.
	sharedPartBrowserPanel = nil;
	[self autorelease];
	
}//end windowWillClose:


//**** NSWindow ****
//========== windowWillReturnUndoManager: ======================================
//
// Purpose:		Allows Undo to keep working transparently through this window by 
//				allowing the undo request to forward on to the active document.
//
//==============================================================================
- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	
	return [currentDocument undoManager];
	
}//end windowWillReturnUndoManager:


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
	// no need to release top-level nib objects, as this is an NSWindowController

	[super dealloc];
	
}//end dealloc


@end
