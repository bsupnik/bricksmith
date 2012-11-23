//==============================================================================
//
// File:		InspectionStep.m
//
// Purpose:		Inspector controller for LDrawSteps. Allows selection of a step 
//				rotatation angle (MLCad ROTSTEP). 
//
//				The UI is prettified to make ROTSTEP configuration easier. For 
//				each rotation type, we present a pop-up menu of common viewing 
//				angles appropriate for that rotation (such as Upside-down for 
//				Relative). In so doing, we aim to make it easier for users to 
//				select the correct rotation type for their viewing angle, which 
//				is traditionally very difficult for new users to figure out. 
//
//				If they don't want a preset, they can always choose custom. 
//				Under the hood, of course, everything is just an angle. But for 
//				"magic" recognized angles (like upside-down) we disable the 
//				custom fields and show the popup-menu item. 
//
// Modified:	9/7/08 Allen Smith. Creation date.
//
//==============================================================================
#import "InspectionStep.h"

#import "LDrawApplication.h"
#import "LDrawDocument.h"
#import "LDrawGLView.h"
#import "LDrawStep.h"
#import "LDrawUtilities.h"


@implementation InspectionStep

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorStep" owner:self] == NO)
	{
        NSLog(@"Couldn't load InspectorStep.nib");
    }
	
    return self;
	
}//end init


#pragma mark -
#pragma mark CONSTRAINTS
#pragma mark -

//========== updateConstraints =================================================
//
// Purpose:		Enables what should be enabled, and disables what should not be 
//				enabled. 
//
//==============================================================================
- (void) updateConstraints
{
	LDrawStep			*representedObject		= [self object];
	BOOL				enableAngleField		= NO;
	LDrawStepRotationT	stepRotationType		= [representedObject stepRotationType];
	BOOL				showViewAngleButton		= NO;
	
	// Enable manual angle entry?
	if(		stepRotationType == LDrawStepRotationRelative
	   &&	[self->relativeRotationPopUpMenu selectedTag] == InspectorRotationShortcutCustom)
	{
		enableAngleField	= YES;
	}
	else if(	stepRotationType == LDrawStepRotationAbsolute
			&&	[self->absoluteRotationPopUpMenu selectedTag] == InspectorRotationShortcutCustom)
	{
		enableAngleField	= YES;
		showViewAngleButton	= YES;
	}
	else if(stepRotationType == LDrawStepRotationAdditive)
	{
		enableAngleField	= YES;
	}
	
	[self->relativeRotationPopUpMenu	setEnabled:(stepRotationType == LDrawStepRotationRelative)];
	[self->absoluteRotationPopUpMenu	setEnabled:(stepRotationType == LDrawStepRotationAbsolute)];
	
	[self->rotationXField				setEnabled:enableAngleField];
	[self->rotationYField				setEnabled:enableAngleField];
	[self->rotationZField				setEnabled:enableAngleField];
	
	[self->useCurrentAngleButton		setHidden:(showViewAngleButton == NO)];
	
}//end updateConstraints


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
	LDrawStep *representedObject = [self object];
	
	LDrawStepRotationT	stepRotationType	= [[self->rotationTypeRadioButtons selectedCell] tag];
	Tuple3				rotationAngle		= ZeroPoint3;
	
	rotationAngle.x = [self->rotationXField doubleValue];
	rotationAngle.y = [self->rotationYField doubleValue];
	rotationAngle.z = [self->rotationZField doubleValue];
	
	[representedObject setStepRotationType:stepRotationType];
	[representedObject setRotationAngle:rotationAngle];
	
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
	LDrawStep			*representedObject	= [self object];
	
	LDrawStepRotationT	stepRotationType	= [representedObject stepRotationType];
	Tuple3				rotationAngle		= [representedObject rotationAngle];
	ViewOrientationT	viewOrientation		= ViewOrientation3D;
	
	[self->rotationTypeRadioButtons selectCellWithTag:stepRotationType];
	[self->rotationXField setDoubleValue:rotationAngle.x];
	[self->rotationYField setDoubleValue:rotationAngle.y];
	[self->rotationZField setDoubleValue:rotationAngle.z];
	
	// See if we recognize the angles as something we provide a shortcut for.
	if(		stepRotationType == LDrawStepRotationRelative
	   &&	[self->relativeRotationPopUpMenu selectedTag] != InspectorRotationShortcutCustom )
	{
		if( V3PointsWithinTolerance(rotationAngle, V3Make(0, 0, 180)) == YES )
			[self->relativeRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutUpsideDown];
		
		else if( V3PointsWithinTolerance(rotationAngle, V3Make(0, 90, 0)) == YES )
			[self->relativeRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutClockwise90];

		else if( V3PointsWithinTolerance(rotationAngle, V3Make(0, -90, 0)) == YES )
			[self->relativeRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutCounterClockwise90];
			
		else if(	V3PointsWithinTolerance(rotationAngle, V3Make(0, 180, 0)) == YES 
				||	V3PointsWithinTolerance(rotationAngle, V3Make(180, 0, 180)) == YES ) // an alternate decomposition that comes out of Bricksmith's math
			[self->relativeRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutBackside];
			
		else
			[self->relativeRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutCustom];
	}
	else if(	stepRotationType == LDrawStepRotationAbsolute
			&&	[self->absoluteRotationPopUpMenu selectedTag] != InspectorRotationShortcutCustom )
	{
		viewOrientation = [LDrawUtilities viewOrientationForAngle:rotationAngle];
		
		// If the angle is a known head-on view, select that, otherwise, call it "custom."
		if( viewOrientation != ViewOrientation3D)
			[self->absoluteRotationPopUpMenu selectItemWithTag:viewOrientation];
		else
			[self->absoluteRotationPopUpMenu selectItemWithTag:InspectorRotationShortcutCustom];
	}
	
	
	[super revert:sender];
	[self updateConstraints];
	
}//end revert:


#pragma mark -

//========== rotationTypeRadioButtonsClicked: ==================================
//
// Purpose:		Master rotation type has changed.
//
//==============================================================================
- (void) rotationTypeRadioButtonsClicked:(id)sender
{
//	LDrawStepRotationT	stepRotationType	= [[self->rotationTypeRadioButtons selectedCell] tag];
	
	[self setAngleUIAccordingToPopUp];
	
	[self finishedEditing:sender];
	[self updateConstraints];
	
}//end rotationTypeRadioButtonsClicked:


//========== relativeRotationPopUpMenuChanged: =================================
//
// Purpose:		User has chosen a new shortcut from the relative rotation menu.
//
//==============================================================================
- (void) relativeRotationPopUpMenuChanged:(id)sender
{
	// set the angle values in the UI.
	[self setAngleUIAccordingToPopUp];
	
	[self finishedEditing:sender];
	[self updateConstraints];
	
}//end relativeRotationPopUpMenuChanged:


//========== absoluteRotationPopUpMenuChanged: =================================
//
// Purpose:		User has chosen a new shortcut from the relative rotation menu.
//
//==============================================================================
- (void) absoluteRotationPopUpMenuChanged:(id)sender
{
	// set the angle values in the UI.
	[self setAngleUIAccordingToPopUp];
	
	[self finishedEditing:sender];
	[self updateConstraints];
	
}//end absoluteRotationPopUpMenuChanged:


//========== useCurrentViewingAngleClicked: ====================================
//
// Purpose:		Grab the viewing angle of the currently-focused LDrawView and 
//				use that for the step's rotation angle. 
//
// Notes:		Only applicable to absolute rotations.
//
//==============================================================================
- (IBAction) useCurrentViewingAngleClicked:(id)sender
{
	LDrawDocument	*currentDocument	= [[NSDocumentController sharedDocumentController] currentDocument];
	Tuple3			viewingAngle		= [currentDocument viewingAngle];
	
	// I seem to be beset by -0. I don't want to display -0!
	viewingAngle.x = round(viewingAngle.x);
	viewingAngle.y = round(viewingAngle.y);
	viewingAngle.z = round(viewingAngle.z);
	
	// set the values in the UI.
	[self->rotationXField setDoubleValue:viewingAngle.x];
	[self->rotationYField setDoubleValue:viewingAngle.y];
	[self->rotationZField setDoubleValue:viewingAngle.z];
	
	[self finishedEditing:sender];
	
}//end useCurrentViewingAngleClicked:


//========== doHelp: ===========================================================
//
// Purpose:		Requests help for the Step inspector, and boy will my poor users 
//				need it. The help page will explicate in great detail just what 
//				in the heck all this stuff does. 
//
//==============================================================================
- (void) doHelp:(id)sender
{
	LDrawApplication *application = [[NSApplication sharedApplication] delegate];
	
	[application openHelpAnchor:@"Steps"];

}//end doHelp:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== setAngleUIAccordingToPopUp ========================================
//
// Purpose:		Sets the xyz values of the angle field according to the 
//				selection in the pop-up menu. 
//
//==============================================================================
- (void) setAngleUIAccordingToPopUp
{
	LDrawStepRotationT  stepRotationType    = [self->rotationTypeRadioButtons selectedTag];
	NSInteger           shortcut            = 0;
	Tuple3              newAngle            = ZeroPoint3;
	
	// Relative rotation?
	if(stepRotationType == LDrawStepRotationRelative)
	{
		shortcut	= [self->relativeRotationPopUpMenu selectedTag];
		
		switch(shortcut)
		{
			case InspectorRotationShortcutUpsideDown:
				newAngle = V3Make(0, 0, 180);
				break;
				
			case InspectorRotationShortcutClockwise90:
				newAngle = V3Make(0, 90, 0);
				break;
				
			case InspectorRotationShortcutCounterClockwise90:
				newAngle = V3Make(0, -90, 0);
				break;
				
			case InspectorRotationShortcutBackside:
				newAngle = V3Make(0, 180, 0);
				break;
				
			case InspectorRotationShortcutCustom:
				newAngle = V3Make(0, 0, 0);
				break;
		}
	}
	// Absolute Rotation?
	else if(stepRotationType == LDrawStepRotationAbsolute)
	{
		shortcut	= [self->absoluteRotationPopUpMenu selectedTag];
		
		switch(shortcut)
		{
			case InspectorRotationShortcutCustom:
				newAngle = V3Make(0, 0, 0);
				break;
				
			default:
				// This is one of the head-on views
				newAngle = [LDrawUtilities angleForViewOrientation:shortcut];
				break;
		}
	}
	
	// set the values in the UI.
	[self->rotationXField setDoubleValue:newAngle.x];
	[self->rotationYField setDoubleValue:newAngle.y];
	[self->rotationZField setDoubleValue:newAngle.z];
	
}//end setAngleUIAccordingToPopUp


@end

