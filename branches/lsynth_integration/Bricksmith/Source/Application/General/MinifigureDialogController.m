//==============================================================================
//
// File:		MinifigureDialogController.m
//
// Purpose:		Handles the Minifigure Generator dialog.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "MinifigureDialogController.h"

#include <stdarg.h>

#import "ColorLibrary.h"
#import "LDrawColor.h"
#import "LDrawColorWell.h"
#import "LDrawGLView.h"
#import "LDrawMPDModel.h"
#import "LDrawPart.h"
#import "LDrawStep.h"
#import "MLCadIni.h"

#import "MacLDraw.h"
#import "MatrixMath.h"

@implementation MinifigureDialogController

//+ (void) initialize
//{
//	[self setKeys:[NSArray arrayWithObjects:@"", nil]
//	triggerChangeNotificationsForDependentKey:@"generateMinifigure"];
//	
//
//}

//========== awakeFromNib ======================================================
//
// Purpose:		Brings the Minifigure Generator dialog onscreen.
//
//==============================================================================
- (void) awakeFromNib
{
	[self->minifigurePreview setAcceptsFirstResponder:NO];
	[self->minifigurePreview setZoomPercentage:180];
	
	[minifigurePreview	setAutosaveName:@"MinifigureGeneratorView"];
	[minifigurePreview	restoreConfiguration];
	
}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== doMinifigureGenerator =============================================
//
// Purpose:		Brings the Minifigure Generator dialog onscreen.
//
//==============================================================================
+ (void) doMinifigureGenerator
{
	MinifigureDialogController *dialog = [[MinifigureDialogController alloc] init];
	
	[dialog runModal];
	
	[dialog release];
	
}//end doMinifigureGenerator


//========== init ==============================================================
//
// Purpose:		Creates the Minifigure Generator dialog.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	iniFile = [[MLCadIni iniFile] retain];
	[self setMinifigureName:NSLocalizedString(@"UntitledMinifigure", nil)];
	
	//we'll call -generateMinifigure: when the dialog is ready and loaded with 
	// all its values.
	
	[NSBundle loadNibNamed:@"MinifigureGenerator" owner:self];
	
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -
//this is all to appease bindings. Hey, at least I wrote the code with grep!

//========== minifigure ========================================================
//
// Purpose:		Returns the minifigure we generated!
//
//==============================================================================
- (LDrawMPDModel *) minifigure
{
	return minifigure;
	
}//end minifigure


//========== setMinifigure: ====================================================
//
// Purpose:		Updates the generated minifigure and redisplays him.
//
//==============================================================================
- (void) setMinifigure:(LDrawMPDModel *)newMinifigure
{
	[newMinifigure		retain];
	[self->minifigure	release];
	
	self->minifigure = newMinifigure;
	
	[self->minifigurePreview setLDrawDirective:newMinifigure];
	
}//end setMinifigure:


//========== setHas<PartX> =====================================================
//
// Purpose:		Set accessors for whether the given part is included in the 
//				minifigure.
//
//==============================================================================
- (void) setHasHat:(BOOL)flag						{hasHat = flag;						}
- (void) setHasNeckAccessory:(BOOL)flag				{hasNeckAccessory = flag;			}
- (void) setHasHips:(BOOL)flag						{hasHips = flag;					}
- (void) setHasRightArm:(BOOL)flag					{hasRightArm = flag;				}
- (void) setHasRightHand:(BOOL)flag					{hasRightHand = flag;				}
- (void) setHasRightHandAccessory:(BOOL)flag		{hasRightHandAccessory = flag;		}
- (void) setHasRightLeg:(BOOL)flag					{hasRightLeg = flag;				}
- (void) setHasRightLegAccessory:(BOOL)flag			{hasRightLegAccessory = flag;		}
- (void) setHasLeftArm:(BOOL)flag					{hasLeftArm = flag;					}
- (void) setHasLeftHand:(BOOL)flag					{hasLeftHand = flag;				}
- (void) setHasLeftHandAccessory:(BOOL)flag			{hasLeftHandAccessory = flag;		}
- (void) setHasLeftLeg:(BOOL)flag					{hasLeftLeg = flag;					}
- (void) setHasLeftLegAccessory:(BOOL)flag			{hasLeftLegAccessory = flag;		}

//========== setHeadElevation: =================================================
//
// Purpose:		Whether the neck piece causes the head to be elevated a few 
//				units.
//
//==============================================================================
- (void) setHeadElevation:(float)newElevation		{headElevation = newElevation;		}


//========== setAngleOf<PartX>: ================================================
//
// Purpose:		Set the angle of the given part.
//
//==============================================================================
- (void) setAngleOfHat:(float)angle					{angleOfHat					= angle; }
- (void) setAngleOfHead:(float)angle				{angleOfHead				= angle; }
- (void) setAngleOfNeck:(float)angle				{angleOfNeck				= angle; }
- (void) setAngleOfRightArm:(float)angle			{angleOfRightArm			= angle; }
- (void) setAngleOfRightHand:(float)angle			{angleOfRightHand			= angle; }
- (void) setAngleOfRightHandAccessory:(float)angle	{angleOfRightHandAccessory	= angle; }
- (void) setAngleOfRightLeg:(float)angle			{angleOfRightLeg			= angle; }
- (void) setAngleOfRightLegAccessory:(float)angle	{angleOfRightLegAccessory	= angle; }
- (void) setAngleOfLeftArm:(float)angle				{angleOfLeftArm				= angle; }
- (void) setAngleOfLeftHand:(float)angle			{angleOfLeftHand			= angle; }
- (void) setAngleOfLeftHandAccessory:(float)angle	{angleOfLeftHandAccessory	= angle; }
- (void) setAngleOfLeftLeg:(float)angle				{angleOfLeftLeg				= angle; }
- (void) setAngleOfLeftLegAccessory:(float)angle	{angleOfLeftLegAccessory	= angle; }


//========== setMinifigureName: ================================================
//
// Purpose:		Sets the name which will be given to the new minifigure model.
//
//==============================================================================
- (void) setMinifigureName:(NSString *)newName
{
	[newName retain];
	[self->minifigureName release];
	
	minifigureName = newName;
	
	[self->minifigure setModelDisplayName:newName];
	
}//end setMinifigureName:


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
	NSInteger		returnCode	= NSCancelButton;
	
	//set the values
	[self restoreFromPreferences];
	[self generateMinifigure:self];
	
	//Run the dialog.
	returnCode = [NSApp runModalForWindow:minifigureGeneratorPanel];
	return returnCode;
	
}//end runModal


//========== okButtonClicked ===================================================
//
// Purpose:		OK clicked, dismiss dialog.
//
//==============================================================================
- (IBAction) okButtonClicked:(id)sender
{
	[NSApp stopModalWithCode:NSOKButton];
	[minifigureGeneratorPanel close];
}//end okButtonClicked


//========== cancelButtonClicked ===============================================
//
// Purpose:		Cancel clicked, dismiss the dialog.
//
//==============================================================================
- (IBAction) cancelButtonClicked:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	[minifigureGeneratorPanel close];
}//end cancelButtonClicked


#pragma mark -

//========== colorWellChanged: =================================================
//
// Purpose:		One of the color wells controlling part colors has changed. We 
//				need to regenerate the minifigure.
//
// Notes:		Since the LDrawColorWell is a custom widget, I haven't bothered 
//				implementing bindings on it. Sigh...
//
//==============================================================================
- (IBAction) colorWellChanged:(id)sender
{
	[self generateMinifigure:sender];
	
}//end colorWellChanged:


//========== generateMinifigure ================================================
//
// Purpose:		This is it! It's time to manufacure the minifigure!
//
//==============================================================================
- (IBAction) generateMinifigure:(id)sender
{
	LDrawMPDModel	*newMinifigure	= [LDrawMPDModel model];
	LDrawStep		*firstStep		= [[newMinifigure steps] objectAtIndex:0];
	
	[newMinifigure setModelDisplayName:self->minifigureName];
	
	//create the parts based on the current selections
	LDrawPart	*hat				= [[[hatsController					selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*head				= [[[headsController				selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*neck				= [[[necksController				selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*torso				= [[[torsosController				selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*leftArm			= [[[leftArmsController				selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*leftHand			= [[[leftHandsController			selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*leftHandAccessory	= [[[leftHandAccessoriesController	selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*rightArm			= [[[rightArmsController			selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*rightHand			= [[[rightHandsController			selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*rightHandAccessory	= [[[rightHandAccessoriesController	selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*hips				= [[[hipsController					selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*leftLeg			= [[[leftLegsController				selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*leftLegAccessory	= [[[leftLegAccessoriesController	selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*rightLeg			= [[[rightLegsController			selectedObjects] objectAtIndex:0] copy];
	LDrawPart	*rightLegAccessory	= [[[rightLegAccessoriesController	selectedObjects] objectAtIndex:0] copy];
	
	//Assign the colors
	[hat				setLDrawColor:[self->hatsColorWell					LDrawColor]];
	[head				setLDrawColor:[self->headsColorWell					LDrawColor]];
	[neck				setLDrawColor:[self->necksColorWell					LDrawColor]];
	[torso				setLDrawColor:[self->torsosColorWell				LDrawColor]];
	[leftArm			setLDrawColor:[self->leftArmsColorWell				LDrawColor]];
	[leftHand			setLDrawColor:[self->leftHandsColorWell				LDrawColor]];
	[leftHandAccessory	setLDrawColor:[self->leftHandAccessoriesColorWell	LDrawColor]];
	[rightArm			setLDrawColor:[self->rightArmsColorWell				LDrawColor]];
	[rightHand			setLDrawColor:[self->rightHandsColorWell			LDrawColor]];
	[rightHandAccessory	setLDrawColor:[self->rightHandAccessoriesColorWell	LDrawColor]];
	[hips				setLDrawColor:[self->hipsColorWell					LDrawColor]];
	[leftLeg			setLDrawColor:[self->leftLegsColorWell				LDrawColor]];
	[leftLegAccessory	setLDrawColor:[self->leftLegAccessoriesColorWell	LDrawColor]];
	[rightLeg			setLDrawColor:[self->rightLegsColorWell				LDrawColor]];
	[rightLegAccessory	setLDrawColor:[self->rightLegAccessoriesColorWell	LDrawColor]];
	
	//other values
	float		armAngle			= [self->iniFile armAngleForTorsoName:[torso referenceName]];
	
	///////////////////////////////////////
	//
	//	Do Positioning
	//
	///////////////////////////////////////

	//---------- head pieces ---------------------------------------------------
	
	// * hat
	[self rotateByDegrees:V3Make(0, angleOfHat, 0)	parts:hat, nil];
	
	// * head
	[self rotateByDegrees:V3Make(0, angleOfHead, 0)	parts:hat, head, nil];
	[self moveBy:V3Make(  0, -24,   0)				parts:hat, head, nil];
	
	// * neck accessory
	[self rotateByDegrees:V3Make(0, angleOfNeck, 0)	parts:neck, nil];
	
	//move up for neck accessory
	if(hasNeckAccessory == YES)
	{
		[self moveBy:V3Make(  0, -headElevation, 0)	parts:hat, head, nil];
	}
	
	//---------- right arm pieces ----------------------------------------------
	
	// * position the right accessory in the hand
	
	[self rotateByDegrees:V3Make(0, angleOfRightHandAccessory, 0)
					parts:rightHandAccessory, nil];
	if(hasRightHand == YES)
	{
		// 15 degrees to fit the hand at 0 degrees
		[self rotateByDegrees:V3Make(15, 0, 0)
						parts:rightHandAccessory, nil];
		[self moveBy:V3Make(  0,   0, -10) parts:rightHandAccessory, nil];
	}
	else
	{
		//fit skeleton arm
		[self moveBy:V3Make( -6,   0, -29.5) parts:rightHandAccessory, nil];
	}
	
	
	// * position the right hand in the right arm
	if(hasRightHand == YES)	//don't do this if using the skeleton arm.
	{
		//		- apply hand rotation
		[self rotateByDegrees:V3Make(0, 0, angleOfRightHand)
						parts:rightHand, rightHandAccessory, nil];
		
		//		-- rotate hand to match arm socket
		[self rotateByDegrees:V3Make(45, 0, 0)
						parts:rightHand, rightHandAccessory, nil];
		
		//		-- move hand into arm
		[self moveBy:V3Make( -5,  19, -10) parts:rightHand, rightHandAccessory, nil];
	}
	
	
	// * position the right arm in the torso
	
	//		-- apply arm rotation
	//			negative so it matches how the circular slider looks.
	[self rotateByDegrees:V3Make(-angleOfRightArm, 0, 0)
					parts:rightArm, rightHand, rightHandAccessory, nil];
	
	//		-- rotate arm to match torso
	//			this value is derived from a little trig on the torso surface.
	[self rotateByDegrees:V3Make(0, 0, armAngle)
					parts:rightArm, rightHand, rightHandAccessory, nil];
	
	//		-- move arm into torso
	[self moveBy:V3Make(-15.4,  8, 0) parts:rightArm, rightHand, rightHandAccessory, nil];
	
	
	//---------- left arm pieces -----------------------------------------------
	
	// * position the left accessory in the hand
	
	[self rotateByDegrees:V3Make(0, angleOfLeftHandAccessory, 0)
					parts:leftHandAccessory, nil];
	if(hasLeftHand == YES)
	{
		// 15 degrees to fit the hand at 0 degrees
		[self rotateByDegrees:V3Make(15, 0, 0)
						parts:leftHandAccessory, nil];
		[self moveBy:V3Make(  0,   0, -10) parts:leftHandAccessory, nil];
	}
	else
	{
		//fit skeleton arm
		[self moveBy:V3Make(  6,   0, -29.5) parts:leftHandAccessory, nil];
	}
	
	
	// * position the left hand in the left arm
	if(hasLeftHand == YES)	//don't do this if using the skeleton arm.
	{
		//		- apply hand rotation
		[self rotateByDegrees:V3Make(0, 0, angleOfLeftHand)
						parts:leftHand, leftHandAccessory, nil];
		
		//		-- rotate hand to match arm socket
		[self rotateByDegrees:V3Make(45, 0, 0)
						parts:leftHand, leftHandAccessory, nil];

		//		-- move hand into arm
		[self moveBy:V3Make(  5,  19, -10) parts:leftHand, leftHandAccessory, nil];
	}
	

	// * position the left arm in the torso
	
	//		-- apply arm rotation
	//			negative so it matches how the circular slider looks.
	[self rotateByDegrees:V3Make(-angleOfLeftArm, 0, 0)
					parts:leftArm, leftHand, leftHandAccessory, nil];
					
	//		-- rotate arm to match torso
	//			this value is derived from a little trig on the torso surface.
	[self rotateByDegrees:V3Make(0, 0, -armAngle)
					parts:leftArm, leftHand, leftHandAccessory, nil];
					
	//		-- move arm into torso
	[self moveBy:V3Make(15.4,  8, 0) parts:leftArm, leftHand, leftHandAccessory, nil];
	
	
	//---------- Legs ----------------------------------------------------------
	
	[hips				moveBy:V3Make(  0,  32,   0)];
	
	//---------- right leg pieces ----------------------------------------------
	
	// * position the right accessory on the foot
	
	// leg accessories' origins take them to their inserted position, which is 
	// counter to the behavior of the rest of MLCad.ini, where the parts' origins
	// are the rotation centerpoint of the part.
//	[rightLegAccessory	moveBy:V3Make(  0,  0,   -1)];
	[rightLegAccessory rotateByDegrees:V3Make(0, angleOfRightLegAccessory, 0)
						   centerPoint:V3Make(-10, 28, -1) ]; //center of the foot.
	
	// * position the right leg on the hips
	[self rotateByDegrees:V3Make(-angleOfRightLeg, 0, 0)	parts:rightLegAccessory, rightLeg, nil];
	[self moveBy:V3Make(  0,  44,   0)					parts:rightLegAccessory, rightLeg, nil];
	
	//---------- left leg pieces ----------------------------------------------
	
	// * position the left accessory on the foot
	
	// leg accessories' origins take them to their inserted position, which is 
	// counter to the behavior of the rest of MLCad.ini, where the parts' origins
	// are the rotation centerpoint of the part.
//	[leftLegAccessory	moveBy:V3Make(  0,  0,   -1)];
	[leftLegAccessory rotateByDegrees:V3Make(0, angleOfLeftLegAccessory, 0)
						   centerPoint:V3Make(10, 28, -1) ]; //center of the foot.
	
	// * position the left leg on the hips
	[self rotateByDegrees:V3Make(-angleOfLeftLeg, 0, 0)	parts:leftLegAccessory, leftLeg, nil];
	[self moveBy:V3Make(  0,  44,   0)					parts:leftLegAccessory, leftLeg, nil];
	
	
	
	
	///////////////////////////////////////
	//
	//	Create the Model
	//
	///////////////////////////////////////
	
	
	if(hasHat == YES)
		[firstStep addDirective:hat];
	
//	if(hasYES == YES)
		[firstStep addDirective:head];
	
	if(hasNeckAccessory == YES)
		[firstStep addDirective:neck];
	
//	if(hasTorso == YES)
		[firstStep addDirective:torso];
		
	if(hasLeftArm == YES)
		[firstStep addDirective:leftArm];
		
	if(hasLeftHand == YES)
		[firstStep addDirective:leftHand];
	
	if(hasLeftHandAccessory == YES)
		[firstStep addDirective:leftHandAccessory];
	if(hasRightArm == YES)
		[firstStep addDirective:rightArm];
		
	if(hasRightHand == YES)
		[firstStep addDirective:rightHand];
	
	if(hasRightHandAccessory == YES)
		[firstStep addDirective:rightHandAccessory];
	
	if(hasHips == YES)
		[firstStep addDirective:hips];
	
	if(hasLeftLeg == YES)
		[firstStep addDirective:leftLeg];
	
	if(hasLeftLegAccessory == YES)
		[firstStep addDirective:leftLegAccessory];
	
	if(hasRightLeg == YES)
		[firstStep addDirective:rightLeg];
	
	if(hasRightLegAccessory == YES)
		[firstStep addDirective:rightLegAccessory];
	
	//this is it! We've got a minifigure!
	[newMinifigure optimizeOpenGL];
	[self setMinifigure:newMinifigure];
	
	
	//Free memory
	[hat				release];
	[head				release];
	[neck				release];
	[torso				release];
	[leftArm			release];
	[leftHand			release];
	[leftHandAccessory	release];
	[rightArm			release];
	[rightHand			release];
	[rightHandAccessory	release];
	[hips				release];
	[leftLeg			release];
	[leftLegAccessory	release];
	[rightLeg			release];
	[rightLegAccessory	release];

}//end generateMinifigure


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//========== windowWillClose: ==================================================
//
// Purpose:		Dialog is closing; save valuse.
//
//==============================================================================
- (void)windowWillClose:(NSNotification *)aNotification
{
	[self saveToPreferences];
	
}//end windowWillClose:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== moveBy:parts: =====================================================
//
// Purpose:		Moves the given nil-terminated list of parts.
//
//==============================================================================
- (void) moveBy:(Vector3)moveVector
		  parts:(LDrawPart *)firstPart, ...
{
	LDrawPart	*currentObject	= nil;
	va_list		 parts;
	
	va_start(parts, firstPart);
	
	currentObject = firstPart;
	while(currentObject != nil)
	{
		[currentObject moveBy:moveVector];
		
		currentObject = va_arg(parts, LDrawPart *);
	}
	
	va_end(parts);
	
}//end rotateParts:byDegrees:


//========== rotateParts:byDegrees: ============================================
//
// Purpose:		Rotates the given nil-terminated list of parts around the point 
//				(0,0,0).
//
// Notes:		This is the first variadic function I ever wrote.
//
//==============================================================================
- (void) rotateByDegrees:(Tuple3) degrees
				   parts:(LDrawPart *)firstPart, ...
{
	Point3		 theOrigin		= V3Make(0,0,0);
	LDrawPart	*currentObject	= nil;
	va_list		 parts;
	
	va_start(parts, firstPart);
	
	currentObject = firstPart;
	while(currentObject != nil)
	{
		[currentObject rotateByDegrees:degrees
						   centerPoint:theOrigin ];
						   
		currentObject = va_arg(parts, LDrawPart *);
	}
	
	va_end(parts);
	
}//end rotateParts:byDegrees:


#pragma mark -
#pragma mark PERSISTENCE
#pragma mark -

//========== restoreFromPreferences ============================================
//
// Purpose:		Reads previous values out of preferences.
//
// Notes:		Wow what a horrific method.
//
//==============================================================================
- (void) restoreFromPreferences
{
	NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
	ColorLibrary    *colorLibrary   = [ColorLibrary sharedColorLibrary];
	
	[self setHasHat:					[userDefaults boolForKey:MINIFIGURE_HAS_HAT]];
	[self setHasNeckAccessory:			[userDefaults boolForKey:MINIFIGURE_HAS_NECK]];
	[self setHasHips:					[userDefaults boolForKey:MINIFIGURE_HAS_HIPS]];
	[self setHasRightArm:				[userDefaults boolForKey:MINIFIGURE_HAS_ARM_RIGHT]];
	[self setHasRightHand:				[userDefaults boolForKey:MINIFIGURE_HAS_HAND_RIGHT]];
	[self setHasRightHandAccessory:		[userDefaults boolForKey:MINIFIGURE_HAS_HAND_RIGHT_ACCESSORY]];
	[self setHasLeftArm:				[userDefaults boolForKey:MINIFIGURE_HAS_ARM_LEFT]];
	[self setHasLeftHand:				[userDefaults boolForKey:MINIFIGURE_HAS_HAND_LEFT]];
	[self setHasLeftHandAccessory:		[userDefaults boolForKey:MINIFIGURE_HAS_HAND_LEFT_ACCESSORY]];
	[self setHasRightLeg:				[userDefaults boolForKey:MINIFIGURE_HAS_LEG_RIGHT]];
	[self setHasRightLegAccessory:		[userDefaults boolForKey:MINIFIGURE_HAS_LEG_RIGHT_ACCESSORY]];
	[self setHasLeftLeg:				[userDefaults boolForKey:MINIFIGURE_HAS_LEG_LEFT]];
	[self setHasLeftLegAccessory:		[userDefaults boolForKey:MINIFIGURE_HAS_LEG_LEFT_ACCESSORY]];
	
	[self setHeadElevation:				[userDefaults floatForKey:MINIFIGURE_HEAD_ELEVATION]];
	
	[self setAngleOfHat:				[userDefaults floatForKey:MINIFIGURE_ANGLE_HAT]];
	[self setAngleOfHead:				[userDefaults floatForKey:MINIFIGURE_ANGLE_HEAD]];
	[self setAngleOfNeck:				[userDefaults floatForKey:MINIFIGURE_ANGLE_NECK]];
	[self setAngleOfLeftArm:			[userDefaults floatForKey:MINIFIGURE_ANGLE_ARM_LEFT]];
	[self setAngleOfRightArm:			[userDefaults floatForKey:MINIFIGURE_ANGLE_ARM_RIGHT]];
	[self setAngleOfLeftHand:			[userDefaults floatForKey:MINIFIGURE_ANGLE_HAND_LEFT]];
	[self setAngleOfLeftHandAccessory:	[userDefaults floatForKey:MINIFIGURE_ANGLE_HAND_LEFT_ACCESSORY]];
	[self setAngleOfRightHand:			[userDefaults floatForKey:MINIFIGURE_ANGLE_HAND_RIGHT]];
	[self setAngleOfRightHandAccessory:	[userDefaults floatForKey:MINIFIGURE_ANGLE_HAND_RIGHT_ACCESSORY]];
	[self setAngleOfLeftLeg:			[userDefaults floatForKey:MINIFIGURE_ANGLE_LEG_LEFT]];
	[self setAngleOfLeftLegAccessory:	[userDefaults floatForKey:MINIFIGURE_ANGLE_LEG_LEFT_ACCESSORY]];
	[self setAngleOfRightLeg:			[userDefaults floatForKey:MINIFIGURE_ANGLE_LEG_RIGHT]];
	[self setAngleOfRightLegAccessory:	[userDefaults floatForKey:MINIFIGURE_ANGLE_LEG_RIGHT_ACCESSORY]];
	
	[hatsColorWell					setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HAT]]];
	[headsColorWell					setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HEAD]]];
	[necksColorWell					setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_NECK]]];
	[torsosColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_TORSO]]];
	[rightArmsColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_ARM_RIGHT]]];
	[rightHandsColorWell			setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HAND_RIGHT]]];
	[rightHandAccessoriesColorWell	setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HAND_RIGHT_ACCESSORY]]];
	[leftArmsColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_ARM_LEFT]]];
	[leftHandsColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HAND_LEFT]]];
	[leftHandAccessoriesColorWell	setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HAND_LEFT_ACCESSORY]]];
	[hipsColorWell					setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_HIPS]]];
	[rightLegsColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_LEG_RIGHT]]];
	[rightLegAccessoriesColorWell	setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_LEG_RIGHT_ACCESSORY]]];
	[leftLegsColorWell				setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_LEG_LEFT]]];
	[leftLegAccessoriesColorWell	setLDrawColor:[colorLibrary colorForCode:[userDefaults integerForKey:MINIFIGURE_COLOR_LEG_LEFT_ACCESSORY]]];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HAT]
				inController:hatsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HEAD]
				inController:headsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_NECK]
				inController:necksController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_TORSO]
				inController:torsosController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_ARM_RIGHT]
				inController:rightArmsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HAND_RIGHT]
				inController:rightHandsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HAND_RIGHT_ACCESSORY]
				inController:rightHandAccessoriesController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_ARM_LEFT]
				inController:leftArmsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HAND_LEFT]
				inController:leftHandsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HAND_LEFT_ACCESSORY]
				inController:leftHandAccessoriesController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_HIPS]
				inController:hipsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_LEG_RIGHT]
				inController:rightLegsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_LEG_RIGHT_ACCESSORY]
				inController:rightLegAccessoriesController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_LEG_LEFT]
				inController:leftLegsController];
	
	[self selectPartWithName:[userDefaults stringForKey:MINIFIGURE_PARTNAME_LEG_LEFT_ACCESSORY]
				inController:leftLegAccessoriesController];
	
}//end restoreFromPreferences


//========== saveToPreferences =================================================
//
// Purpose:		Writes current values out of preferences.
//
// Notes:		Wow what a horrific method.
//
//==============================================================================
- (void) saveToPreferences
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults setBool:self->hasHat						forKey:MINIFIGURE_HAS_HAT];
	[userDefaults setBool:self->hasNeckAccessory			forKey:MINIFIGURE_HAS_NECK];
	[userDefaults setBool:self->hasHips						forKey:MINIFIGURE_HAS_HIPS];
	[userDefaults setBool:self->hasRightArm					forKey:MINIFIGURE_HAS_ARM_RIGHT];
	[userDefaults setBool:self->hasRightHand				forKey:MINIFIGURE_HAS_HAND_RIGHT];
	[userDefaults setBool:self->hasRightHandAccessory		forKey:MINIFIGURE_HAS_HAND_RIGHT_ACCESSORY];
	[userDefaults setBool:self->hasLeftArm					forKey:MINIFIGURE_HAS_ARM_LEFT];
	[userDefaults setBool:self->hasLeftHand					forKey:MINIFIGURE_HAS_HAND_LEFT];
	[userDefaults setBool:self->hasLeftHandAccessory		forKey:MINIFIGURE_HAS_HAND_LEFT_ACCESSORY];
	[userDefaults setBool:self->hasRightLeg					forKey:MINIFIGURE_HAS_LEG_RIGHT];
	[userDefaults setBool:self->hasRightLegAccessory		forKey:MINIFIGURE_HAS_LEG_RIGHT_ACCESSORY];
	[userDefaults setBool:self->hasLeftLeg					forKey:MINIFIGURE_HAS_LEG_LEFT];
	[userDefaults setBool:self->hasLeftLegAccessory			forKey:MINIFIGURE_HAS_LEG_LEFT_ACCESSORY];
	
	[userDefaults setFloat:self->headElevation				forKey:MINIFIGURE_HEAD_ELEVATION];
	
	[userDefaults setFloat:self->angleOfHat					forKey:MINIFIGURE_ANGLE_HAT];
	[userDefaults setFloat:self->angleOfHead				forKey:MINIFIGURE_ANGLE_HEAD];
	[userDefaults setFloat:self->angleOfNeck				forKey:MINIFIGURE_ANGLE_NECK];
	[userDefaults setFloat:self->angleOfLeftArm				forKey:MINIFIGURE_ANGLE_ARM_LEFT];
	[userDefaults setFloat:self->angleOfRightArm			forKey:MINIFIGURE_ANGLE_ARM_RIGHT];
	[userDefaults setFloat:self->angleOfLeftHand			forKey:MINIFIGURE_ANGLE_HAND_LEFT];
	[userDefaults setFloat:self->angleOfLeftHandAccessory	forKey:MINIFIGURE_ANGLE_HAND_LEFT_ACCESSORY];
	[userDefaults setFloat:self->angleOfRightHand			forKey:MINIFIGURE_ANGLE_HAND_RIGHT];
	[userDefaults setFloat:self->angleOfRightHandAccessory	forKey:MINIFIGURE_ANGLE_HAND_RIGHT_ACCESSORY];
	[userDefaults setFloat:self->angleOfLeftLeg				forKey:MINIFIGURE_ANGLE_LEG_LEFT];
	[userDefaults setFloat:self->angleOfLeftLegAccessory	forKey:MINIFIGURE_ANGLE_LEG_LEFT_ACCESSORY];
	[userDefaults setFloat:self->angleOfRightLeg			forKey:MINIFIGURE_ANGLE_LEG_RIGHT];
	[userDefaults setFloat:self->angleOfRightLegAccessory	forKey:MINIFIGURE_ANGLE_LEG_RIGHT_ACCESSORY];
	
	[userDefaults setInteger:[[hatsColorWell					LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HAT];
	[userDefaults setInteger:[[headsColorWell					LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HEAD];
	[userDefaults setInteger:[[necksColorWell					LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_NECK];
	[userDefaults setInteger:[[torsosColorWell					LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_TORSO];
	[userDefaults setInteger:[[rightArmsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_ARM_RIGHT];
	[userDefaults setInteger:[[rightHandsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HAND_RIGHT];
	[userDefaults setInteger:[[rightHandAccessoriesColorWell	LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HAND_RIGHT_ACCESSORY];
	[userDefaults setInteger:[[leftArmsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_ARM_LEFT];
	[userDefaults setInteger:[[leftHandsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HAND_LEFT];
	[userDefaults setInteger:[[leftHandAccessoriesColorWell		LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HAND_LEFT_ACCESSORY];
	[userDefaults setInteger:[[hipsColorWell					LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_HIPS];
	[userDefaults setInteger:[[rightLegsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_LEG_RIGHT];
	[userDefaults setInteger:[[rightLegAccessoriesColorWell		LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_LEG_RIGHT_ACCESSORY];
	[userDefaults setInteger:[[leftLegsColorWell				LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_LEG_LEFT];
	[userDefaults setInteger:[[leftLegAccessoriesColorWell		LDrawColor] colorCode]	forKey:MINIFIGURE_COLOR_LEG_LEFT_ACCESSORY];
	
	[self savePartControllerSelection:hatsController					underKey:MINIFIGURE_PARTNAME_HAT];
	[self savePartControllerSelection:headsController					underKey:MINIFIGURE_PARTNAME_HEAD];
	[self savePartControllerSelection:necksController					underKey:MINIFIGURE_PARTNAME_NECK];
	[self savePartControllerSelection:torsosController					underKey:MINIFIGURE_PARTNAME_TORSO];
	[self savePartControllerSelection:rightArmsController				underKey:MINIFIGURE_PARTNAME_ARM_RIGHT];
	[self savePartControllerSelection:rightHandsController				underKey:MINIFIGURE_PARTNAME_HAND_RIGHT];
	[self savePartControllerSelection:rightHandAccessoriesController	underKey:MINIFIGURE_PARTNAME_HAND_RIGHT_ACCESSORY];
	[self savePartControllerSelection:leftArmsController				underKey:MINIFIGURE_PARTNAME_ARM_LEFT];
	[self savePartControllerSelection:leftHandsController				underKey:MINIFIGURE_PARTNAME_HAND_LEFT];
	[self savePartControllerSelection:leftHandAccessoriesController		underKey:MINIFIGURE_PARTNAME_HAND_LEFT_ACCESSORY];
	[self savePartControllerSelection:hipsController					underKey:MINIFIGURE_PARTNAME_HIPS];
	[self savePartControllerSelection:rightLegsController				underKey:MINIFIGURE_PARTNAME_LEG_RIGHT];
	[self savePartControllerSelection:rightLegAccessoriesController		underKey:MINIFIGURE_PARTNAME_LEG_RIGHT_ACCESSORY];
	[self savePartControllerSelection:leftLegsController				underKey:MINIFIGURE_PARTNAME_LEG_LEFT];
	[self savePartControllerSelection:leftLegAccessoriesController		underKey:MINIFIGURE_PARTNAME_LEG_LEFT_ACCESSORY];
	
	//and write it out at last!
	[userDefaults synchronize];
	
}//end restoreFromPreferences


//========== selectPartWithName:inController: ==================================
//
// Purpose:		Parts are identified in user defaults by their reference name, 
//				such as "3001.dat". This method selects the actual part object 
//				based on the name.
//
//==============================================================================
- (void) selectPartWithName:(NSString *) name
			   inController:(NSArrayController *)controller
{
	NSArray     *parts          = [controller arrangedObjects];
	LDrawPart   *currentPart    = nil;
	NSUInteger  partCount       = [parts count];
	NSUInteger  counter         = 0;
	
	//just look for the right name.
	for(counter = 0; counter < partCount; counter++)
	{
		currentPart = [parts objectAtIndex:counter];
	
		if([[currentPart referenceName] isEqualToString:name])
		{
			[controller setSelectionIndex:counter];
			break;
		}
	}
	
}//end selectPartWithName:inController:


//========== savePartControllerSelection:underKey: =============================
//
// Purpose:		Parts are identified in user defaults by their reference name, 
//				such as "3001.dat". This method saves the reference name based 
//				on the currently-selected part object in the controller.
//
//==============================================================================
- (void) savePartControllerSelection:(NSArrayController *)controller
							underKey:(NSString *) key
{
	LDrawPart		*currentPart	= [[controller selectedObjects] objectAtIndex:0];
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	
	[userDefaults setObject:[currentPart referenceName] forKey:key];
	
}//end selectPartWithName:inController:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		
//
//==============================================================================
- (void) dealloc
{
	[iniFile			release];

	[headsController	release];

	[super dealloc];
	
}//end dealloc


@end
