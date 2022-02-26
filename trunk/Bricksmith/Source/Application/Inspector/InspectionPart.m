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

#import "LDrawApplication.h"
#import "LDrawColorWell.h"
#import "LDrawDocument.h"
#import "LDrawFile.h"
#import "LDrawPart.h"
#import "MacLDraw.h"
#import "PartLibrary.h"

// Data Types

typedef enum
{
	rotationAbsolute = 0,
	rotationRelative = 1
	
} RotationT;


@interface InspectionPart ()

// Top-level objects
@property (nonatomic, strong) IBOutlet				NSNumberFormatter*	formatterBasic;
@property (nonatomic, strong) IBOutlet				NSNumberFormatter*	formatterAngle;
@property (nonatomic, strong) IBOutlet				NSNumberFormatter*	formatterScale;

// Window widgets

@property (nonatomic, weak) IBOutlet	NSTextField*		partDescriptionField;
@property (nonatomic, weak) IBOutlet	NSTextField*		partNameField;
@property (nonatomic, weak) IBOutlet	LDrawColorWell*		colorWell;
@property (nonatomic, weak) IBOutlet	NSPopUpButton*		rotationTypePopUp;

@property (nonatomic, weak) IBOutlet	NSTextField*		locationXField;
@property (nonatomic, weak) IBOutlet	NSTextField*		locationYField;
@property (nonatomic, weak) IBOutlet	NSTextField*		locationZField;

@property (nonatomic, weak) IBOutlet	NSTextField*		rotationXField;
@property (nonatomic, weak) IBOutlet	NSTextField*		rotationYField;
@property (nonatomic, weak) IBOutlet	NSTextField*		rotationZField;

@property (nonatomic, weak) IBOutlet	NSTextField*		scaleXField;
@property (nonatomic, weak) IBOutlet	NSTextField*		scaleYField;
@property (nonatomic, weak) IBOutlet	NSTextField*		scaleZField;

@property (nonatomic, weak) IBOutlet	NSTextField*		shearXYField;
@property (nonatomic, weak) IBOutlet	NSTextField*		shearXZField;
@property (nonatomic, weak) IBOutlet	NSTextField*		shearYZField;

@end

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


//========== awakeFromNib ======================================================
//==============================================================================
- (void) awakeFromNib
{
	[super awakeFromNib];
}


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
	Point3				 position			= [self coordinateValueFromFields:@[_locationXField, _locationYField, _locationZField]];
	Vector3				 scaling			= [self coordinateValueFromFields:@[_scaleXField, _scaleYField, _scaleZField]];
	Tuple3				 shear				= [self coordinateValueFromFields:@[_shearXYField, _shearXZField, _shearYZField]];
	
	[representedObject setDisplayName:[_partNameField stringValue]];
	
	//Fill the components structure.
 	components.scale		= V3MulScalar(scaling, 0.01); //convert from percentage
 	components.shear_XY		= shear.x;
 	components.shear_XZ		= shear.y;
 	components.shear_YZ		= shear.z;
 	components.rotate		= oldComponents.rotate; //rotation is handled by the Apply button.
 	components.translate	= position;
	
	[representedObject setTransformComponents:components];
	
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
	
	
	[_partDescriptionField setStringValue:description];
	[_partDescriptionField setToolTip:description]; //in case it overflows the field.
	[_partNameField setStringValue:[representedObject displayName]];
	
	[_colorWell setLDrawColor:[representedObject LDrawColor]];

	position	= components.translate;
	
	scaling.x	= components.scale.x * 100.0; //convert to percentage.
	scaling.y	= components.scale.y * 100.0; //convert to percentage.
	scaling.z	= components.scale.z * 100.0; //convert to percentage.
	
	//stuff the shear into the structure, despite the bad name mismatches.
	shear.x = components.shear_XY;
	shear.y = components.shear_XZ;
	shear.z = components.shear_YZ;
	
	[self setCoordinateValue:position onFields:@[_locationXField, _locationYField, _locationZField]];
	[self setCoordinateValue:scaling onFields:@[_scaleXField, _scaleYField, _scaleZField]];
	[self setCoordinateValue:shear onFields:@[_shearXYField, _shearXZField, _shearYZField]];
	
	//Rotation is a bit trickier since we have two different modes for the data 
	// entered. An absolute rotation means that the actual rotation angles for 
	// the part are displayed and edited. A relative rotation means that what-
	// ever we enter in is added to the current angles.
 	[self setRotationAngles];
	
	[super revert:sender];

    // Someone else might care that the part's changed
    [representedObject sendMessageToObservers:MessageObservedChanged];
	
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
	RotationT			 rotationType		= [[_rotationTypePopUp selectedItem] tag];
	
	if(rotationType == rotationRelative)
	{
		//Rotations entered will be additive.
		[_rotationXField setDoubleValue:0.0];
		[_rotationYField setDoubleValue:0.0];
		[_rotationZField setDoubleValue:0.0];
	}
	else
	{
		//Absolute rotation; fill in the real rotation angles.
		[_rotationXField setDoubleValue:degrees(components.rotate.x)];
		[_rotationYField setDoubleValue:degrees(components.rotate.y)];
		[_rotationZField setDoubleValue:degrees(components.rotate.z)];
		
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
	RotationT       rotationType        = [[_rotationTypePopUp selectedItem] tag];
	
	//Save out the current state.
	[currentDocument preserveDirectiveState:representedObject];
	
	if(rotationType == rotationRelative)
	{
		Tuple3 additiveRotation;
		
		additiveRotation.x = [_rotationXField doubleValue];
		additiveRotation.y = [_rotationYField doubleValue];
		additiveRotation.z = [_rotationZField doubleValue];
		
		[representedObject rotateByDegrees:additiveRotation];
	}
	//An absolute rotation.
	else{
		TransformComponents components = [[self object] transformComponents];
		
		components.rotate.x = radians([_rotationXField doubleValue]); //convert from degrees
		components.rotate.y = radians([_rotationYField doubleValue]);
		components.rotate.z = radians([_rotationZField doubleValue]);
		
		[representedObject setTransformComponents:components];
	}
	
	//Note that the part has changed.
	[representedObject noteNeedsDisplay];
	
	//For a relative rotation, prepare for the next additive rotation by 
	// resetting the rotations values to zero
	if(rotationType == rotationRelative)
	{
		[_rotationXField setDoubleValue:0.0];
		[_rotationYField setDoubleValue:0.0];
		[_rotationZField setDoubleValue:0.0];
	}

    // Someone else might care that the part's orientation has changed
    [representedObject sendMessageToObservers:MessageObservedChanged];
	
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
	Point3				formContents	= [self coordinateValueFromFields:@[_locationXField, _locationYField, _locationZField]];
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
	NSString *newName = [_partNameField stringValue];
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
	Vector3				formContents	= [self coordinateValueFromFields:@[_scaleXField, _scaleYField, _scaleZField]];
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
	Vector3				formContents	= [self coordinateValueFromFields:@[_shearXYField, _shearXZField, _shearYZField]];
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


@end
