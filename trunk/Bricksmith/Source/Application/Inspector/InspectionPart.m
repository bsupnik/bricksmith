//==============================================================================
//
// File:		InspectionPart.m
//
// Purpose:		Inspector Controller for an LDrawPart.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionPart.h"

#import "FormCategory.h"
#import "LDrawApplication.h"
#import "LDrawDocument.h"
#import "LDrawFile.h"
#import "LDrawPart.h"
#import "MacLDraw.h"
#import "PartLibrary.h"


@implementation InspectionPart

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorPart" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorPart.nib");
    }
	
    return self;
	
}//end init


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== commitChanges: ====================================================
//
// Purpose:		Called in response to the conclusion of editing in the palette.
//
//==============================================================================
- (void) commitChanges:(id)sender
{
	LDrawPart			*representedObject	= [self object];
	TransformComponents	 oldComponents		= [representedObject transformComponents];
	TransformComponents	 components			= IdentityComponents;
	Point3				 position			= [self->locationForm coordinateValue];
	Vector3				 scaling			= [self->scalingForm coordinateValue];
	Tuple3				 shear				= [self->shearForm coordinateValue];
	
	[representedObject setDisplayName:[partNameField stringValue]];
	
	//Fill the components structure.
 	components.scale.x		= scaling.x / 100.0; //convert from percentage
 	components.scale.y		= scaling.y / 100.0;
 	components.scale.z		= scaling.z / 100.0;
 	components.shear_XY		= shear.x;
 	components.shear_XZ		= shear.y;
 	components.shear_YZ		= shear.z;
 	components.rotate.x		= oldComponents.rotate.x; //rotation is handled elsewhere.
 	components.rotate.y		= oldComponents.rotate.y;
 	components.rotate.z		= oldComponents.rotate.z;
 	components.translate	= position;
	
	[representedObject setTransformComponents:components];
	
	[representedObject optimizeOpenGL];
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
	LDrawPart			*representedObject	= [self object];
	TransformComponents	 components			= [representedObject transformComponents];
	NSString			*description		= [[PartLibrary sharedPartLibrary] descriptionForPart:representedObject];
	Point3				 position			= ZeroPoint3;
	Vector3				 scaling			= ZeroPoint3;
	Tuple3				 shear				= ZeroPoint3;
	
	
	[partDescriptionField setStringValue:description];
	[partDescriptionField setToolTip:description]; //in case it overflows the field.
	[partNameField setStringValue:[representedObject displayName]];
	
	[colorWell setLDrawColor:[representedObject LDrawColor]];

	position	= components.translate;
	
	scaling.x	= components.scale.x * 100.0; //convert to percentage.
	scaling.y	= components.scale.y * 100.0; //convert to percentage.
	scaling.z	= components.scale.z * 100.0; //convert to percentage.
	
	//stuff the shear into the structure, despite the bad name mismatches.
	shear.x = components.shear_XY;
	shear.y = components.shear_XZ;
	shear.z = components.shear_YZ;
	
	[locationForm setCoordinateValue:position];
	[scalingForm setCoordinateValue:scaling];
	[shearForm setCoordinateValue:shear];
	
	//Rotation is a bit trickier since we have two different modes for the data 
	// entered. An absolute rotation means that the actual rotation angles for 
	// the part are displayed and edited. A relative rotation means that what-
	// ever we enter in is added to the current angles.
 	[self setRotationAngles];
	
	[representedObject optimizeOpenGL];
	[super revert:sender];
	
}//end revert:


//========== setRotationAngles =================================================
//
// Purpose:		Fills in the rotation angles based on the data-entry mode:
//				absolute or relative.
//
//				An absolute rotation means that the actual rotation angles for 
//				the part are displayed and edited. A relative rotation means 
//				that whatever we enter in is *added to* the current angles.
//
//
//==============================================================================
- (void) setRotationAngles
{
	LDrawPart			*representedObject	= [self object];
	TransformComponents	 components			= [representedObject transformComponents];
	RotationT			 rotationType		= [[rotationTypePopUp selectedItem] tag];
	
	if(rotationType == rotationRelative)
	{
		//Rotations entered will be additive.
		[rotationXField setDoubleValue:0.0];
		[rotationYField setDoubleValue:0.0];
		[rotationZField setDoubleValue:0.0];
	}
	else
	{
		//Absolute rotation; fill in the real rotation angles.
		[rotationXField setDoubleValue:degrees(components.rotate.x)];
		[rotationYField setDoubleValue:degrees(components.rotate.y)];
		[rotationZField setDoubleValue:degrees(components.rotate.z)];
		
	}
}//end setRotationAngles


#pragma mark -

//========== applyRotationClicked: =============================================
//
// Purpose:		The user has entered new rotation values and now wants them to 
//				take effect. I set up this apply mechanism because it seemed 
//				like it would be odd for the rotations to take effect instantly.
//
//				This method is something like an alternate form of 
//				-finishedEditing: which modifies a different set of values.
//
//==============================================================================
- (IBAction) applyRotationClicked:(id)sender
{
	LDrawPart       *representedObject  = [self object];
	LDrawDocument   *currentDocument    = [[NSDocumentController sharedDocumentController] currentDocument];
	RotationT       rotationType        = [[rotationTypePopUp selectedItem] tag];
	
	//Save out the current state.
	[currentDocument preserveDirectiveState:representedObject];
	[representedObject lockForEditing];
	
	if(rotationType == rotationRelative)
	{
		Tuple3 additiveRotation;
		
		additiveRotation.x = [rotationXField doubleValue];
		additiveRotation.y = [rotationYField doubleValue];
		additiveRotation.z = [rotationZField doubleValue];
		
		[representedObject rotateByDegrees:additiveRotation];
	}
	//An absolute rotation.
	else{
		TransformComponents components = [[self object] transformComponents];
		
		components.rotate.x = radians([rotationXField doubleValue]); //convert from degrees
		components.rotate.y = radians([rotationYField doubleValue]);
		components.rotate.z = radians([rotationZField doubleValue]);
		
		[representedObject setTransformComponents:components];
	}
	
	//Note that the part has changed.
	[representedObject unlockEditor];
	[representedObject noteNeedsDisplay];
	
	//For a relative rotation, prepare for the next additive rotation by 
	// resetting the rotations values to zero
	if(rotationType == rotationRelative)
	{
		[rotationXField setDoubleValue:0.0];
		[rotationYField setDoubleValue:0.0];
		[rotationZField setDoubleValue:0.0];
	}
	
}//end applyRotationClicked:


//========== locationEndedEditing: =============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) locationEndedEditing:(id)sender
{
	Point3				formContents	= [locationForm coordinateValue];
	TransformComponents	components		= [[self object] transformComponents];
	
	//If the values really did change, then update.
	if( V3EqualPoints(formContents, components.translate) == NO )
	{
		[self finishedEditing:sender];
	}
	
}//end locationEndedEditing:


//========== partNameEndedEditing: =============================================
//
// Purpose:		The user had been editing the part name; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) partNameEndedEditing:(id)sender
{
	NSString *newName = [partNameField stringValue];
	NSString *oldName = [[self object] displayName];
	
	if([oldName isEqualToString:newName] == NO){
		[self finishedEditing:sender];
		[self revert:sender];
	}
	
}//end partNameEndedEditing:


//========== rotationTypeChanged: ==============================================
//
// Purpose:		The pop-up menu specifying the rotation type has changed.
//
//==============================================================================
- (IBAction) rotationTypeChanged:(id)sender
{
	
	[self setRotationAngles];
		
}//end rotationTypeChanged:


//========== scalingEndedEditing: ==============================================
//
// Purpose:		The user had been editing the scaling percentages; now he has 
//				stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) scalingEndedEditing:(id)sender
{
	Vector3				formContents	= [scalingForm coordinateValue];
	TransformComponents	components		= [[self object] transformComponents];

	//If the values really did change, then update.
	if(		formContents.x != components.scale.x * 100.0
	   ||	formContents.y != components.scale.y * 100.0
	   ||	formContents.z != components.scale.z * 100.0
	   )
	{
		[self finishedEditing:sender];
	}
		
}//end scalingEndedEditing:


//========== shearEndedEditing: ================================================
//
// Purpose:		The user had been editing the scaling percentages; now he has 
//				stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) shearEndedEditing:(id)sender
{
	Vector3				formContents	= [shearForm coordinateValue];
	TransformComponents	components		= [[self object] transformComponents];
	
	//If the values really did change, then update.
	// (please disregard the meaningless x, y, and z tags in the formContents.)
	if(		formContents.x != components.shear_XY
		||	formContents.y != components.shear_XZ
		||	formContents.z != components.shear_YZ
	  )
	{
		[self finishedEditing:sender];
	}
		
}//end shearEndedEditing:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Abandon all hope ye who enter here.
//
//==============================================================================
- (void) dealloc
{
	//Top level nib objects:
	[formatterBasic release];
	[formatterAngle release];
	[formatterScale release];
	
	[super dealloc];
	
}//end dealloc


@end
