//==============================================================================
//
// File:		MinifigureDialogController.m
//
// Purpose:		Handles the Minifigure Generator dialog.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "MatrixMath.h"

@class LDrawColorWell;
@class LDrawGLView;
@class LDrawMPDModel;
@class LDrawPart;
@class MLCadIni;

@interface MinifigureDialogController : NSObject
{
	MLCadIni		*iniFile;
	NSString		*minifigureName;
	LDrawMPDModel	*minifigure;
	
	BOOL		hasHat;
	BOOL		hasNeckAccessory;
	BOOL		hasHips;
	BOOL		hasRightArm;
	BOOL		hasRightHand;
	BOOL		hasRightHandAccessory;
	BOOL		hasRightLeg;
	BOOL		hasRightLegAccessory;
	BOOL		hasLeftArm;
	BOOL		hasLeftHand;
	BOOL		hasLeftHandAccessory;
	BOOL		hasLeftLeg;
	BOOL		hasLeftLegAccessory;
	
	float		headElevation;
	
	float		angleOfHat;
	float		angleOfHead;
	float		angleOfNeck;
	float		angleOfRightArm;
	float		angleOfRightHand;
	float		angleOfRightHandAccessory;
	float		angleOfRightLeg;
	float		angleOfRightLegAccessory;
	float		angleOfLeftArm;
	float		angleOfLeftHand;
	float		angleOfLeftHandAccessory;
	float		angleOfLeftLeg;
	float		angleOfLeftLegAccessory;
	
	//top-level objects
	
	IBOutlet NSArrayController	*hatsController;
	IBOutlet NSArrayController	*headsController;
	IBOutlet NSArrayController	*necksController;
	IBOutlet NSArrayController	*torsosController;
	IBOutlet NSArrayController	*rightArmsController;
	IBOutlet NSArrayController	*rightHandsController;
	IBOutlet NSArrayController	*rightHandAccessoriesController;
	IBOutlet NSArrayController	*leftArmsController;
	IBOutlet NSArrayController	*leftHandsController;
	IBOutlet NSArrayController	*leftHandAccessoriesController;
	IBOutlet NSArrayController	*hipsController;
	IBOutlet NSArrayController	*rightLegsController;
	IBOutlet NSArrayController	*rightLegAccessoriesController;
	IBOutlet NSArrayController	*leftLegsController;
	IBOutlet NSArrayController	*leftLegAccessoriesController;
	
	//Nib widgets
	
	IBOutlet NSPanel			*minifigureGeneratorPanel;
	IBOutlet LDrawGLView		*minifigurePreview;
	
	IBOutlet LDrawColorWell		*hatsColorWell;
	IBOutlet LDrawColorWell		*headsColorWell;
	IBOutlet LDrawColorWell		*necksColorWell;
	IBOutlet LDrawColorWell		*torsosColorWell;
	IBOutlet LDrawColorWell		*rightArmsColorWell;
	IBOutlet LDrawColorWell		*rightHandsColorWell;
	IBOutlet LDrawColorWell		*rightHandAccessoriesColorWell;
	IBOutlet LDrawColorWell		*leftArmsColorWell;
	IBOutlet LDrawColorWell		*leftHandsColorWell;
	IBOutlet LDrawColorWell		*leftHandAccessoriesColorWell;
	IBOutlet LDrawColorWell		*hipsColorWell;
	IBOutlet LDrawColorWell		*rightLegsColorWell;
	IBOutlet LDrawColorWell		*rightLegAccessoriesColorWell;
	IBOutlet LDrawColorWell		*leftLegsColorWell;
	IBOutlet LDrawColorWell		*leftLegAccessoriesColorWell;
	
}

+ (void) doMinifigureGenerator;

//Accessors
- (LDrawMPDModel *) minifigure;
- (void) setMinifigure:(LDrawMPDModel *)newMinifigure;
- (void) setHasHat:(BOOL)flag;
- (void) setHasNeckAccessory:(BOOL)flag;
- (void) setHasHips:(BOOL)flag;
- (void) setHasRightArm:(BOOL)flag;
- (void) setHasRightHand:(BOOL)flag;
- (void) setHasRightHandAccessory:(BOOL)flag;
- (void) setHasRightLeg:(BOOL)flag;
- (void) setHasRightLegAccessory:(BOOL)flag;
- (void) setHasLeftArm:(BOOL)flag;
- (void) setHasLeftHand:(BOOL)flag;
- (void) setHasLeftHandAccessory:(BOOL)flag;
- (void) setHasLeftLeg:(BOOL)flag;
- (void) setHasLeftLegAccessory:(BOOL)flag;

- (void) setHeadElevation:(float)newElevation;

- (void) setAngleOfHat:(float)angle;
- (void) setAngleOfHead:(float)angle;
- (void) setAngleOfNeck:(float)angle;
- (void) setAngleOfRightArm:(float)angle;
- (void) setAngleOfRightHand:(float)angle;
- (void) setAngleOfRightHandAccessory:(float)angle;
- (void) setAngleOfRightLeg:(float)angle;
- (void) setAngleOfRightLegAccessory:(float)angle;
- (void) setAngleOfLeftArm:(float)angle;
- (void) setAngleOfLeftHand:(float)angle;
- (void) setAngleOfLeftHandAccessory:(float)angle;
- (void) setAngleOfLeftLeg:(float)angle;
- (void) setAngleOfLeftLegAccessory:(float)angle;

- (void) setMinifigureName:(NSString *)newName;

//Actions
- (NSInteger) runModal;
- (IBAction) okButtonClicked:(id)sender;
- (IBAction) cancelButtonClicked:(id)sender;

- (IBAction) colorWellChanged:(id)sender;
- (IBAction) generateMinifigure:(id)sender;

//Utilities
- (void) moveBy:(Vector3)moveVector parts:(LDrawPart *)firstPart, ...;
- (void) rotateByDegrees:(Tuple3) degrees parts:(LDrawPart *)firstPart, ...;


//Persistence
- (void) restoreFromPreferences;
- (void) saveToPreferences;
- (void) selectPartWithName:(NSString *)name inController:(NSArrayController *)controller;
- (void) savePartControllerSelection:(NSArrayController *)controller underKey:(NSString *) key;

@end
