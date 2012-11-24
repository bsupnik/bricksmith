//==============================================================================
//
// File:		RotationPanelController.m
//
// Purpose:		Advanced rotation controls for doing relative rotations on 
//				groups of parts. This is not meant to provide absolute rotations 
//				for individual parts. It simply works on the current selection, 
//				whatever that may be.
//
//  Created by Allen Smith on 8/27/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "RotationPanelController.h"


@implementation RotationPanelController

RotationPanelController *sharedRotationPanel = nil;

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
		sharedRotationPanel = [[RotationPanelController alloc] init];
		
	return sharedRotationPanel;
	
}//end rotationPanel


//========== init ==============================================================
//
// Purpose:		Initialize the object.
//
//==============================================================================
- (id) init
{
	self = [super initWithWindowNibName:@"RotationPanel"];
	
	return self;
}


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

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
	// Validate, and guarantee that Undo points to the document and not some 
	// typed-in text field. 
	if([[self window] makeFirstResponder:nil])
	{
		[NSApp sendAction:@selector(panelRotateParts:) to:nil from:self];
	}

}//end rotateButtonClicked:


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//========== windowWillClose: ==================================================
//
// Purpose:		Window is closing; clean up.
//
//==============================================================================
- (void) windowWillClose:(NSNotification *)notification
{
	//The object controller apparently retains its content. We must break that 
	// cycle in order to fully deallocate.
	[objectController setContent:nil];
	
	[self autorelease];
	sharedRotationPanel = nil;
}


//========== windowWillReturnUndoManager: ======================================
//
// Purpose:		Defer undo to the document. This seems reasonable, as the 
//				rotation panel affects the document so intimately it's much more 
//				likely the user wants to undo the document than changes to 
//				rotation text fields. 
//
//==============================================================================
- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)window
{
	NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	
	return [currentDocument undoManager];
}


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
	[super dealloc];

}//end dealloc


@end
