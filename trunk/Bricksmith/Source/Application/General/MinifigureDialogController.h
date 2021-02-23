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
@class LDrawMPDModel;
@class LDrawPart;
@class MLCadIni;

@interface MinifigureDialogController : NSObject

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
