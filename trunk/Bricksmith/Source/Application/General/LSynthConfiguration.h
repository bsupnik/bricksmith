//
//  LSynthConfiguration.h
//  Bricksmith
//
//  Created by Robin Macharg on 24/09/2012.
//
//

#import <Foundation/Foundation.h>

@class LDrawPart;

// The class of a synthesis object
typedef enum
{
    LSYNTH_PART = 1,
    LSYNTH_HOSE = 2,
    LSYNTH_BAND = 3,
    LSYNTH_CLASSES_COUNT
} LSynthClassT;

@interface LSynthConfiguration : NSObject
{
    NSMutableArray *parts;
    NSMutableArray *hose_constraints;
    NSMutableArray *band_constraints;
    NSMutableArray *hose_types;
    NSMutableArray *band_types;

    NSMutableArray *quickRefHoses;
    NSMutableArray *quickRefBands;
    NSMutableArray *quickRefParts;
    NSMutableArray *quickRefHoseConstraints;
    NSMutableArray *quickRefBandConstraints;
}

#pragma mark -
#pragma mark Class Methods
#pragma mark -

+(LSynthConfiguration*) sharedInstance;

#pragma mark -
#pragma mark Instance Methods
#pragma mark -

-(void) parseLsynthConfig:(NSString *)lsynthConfigurationPath;
-(BOOL) isLSynthConstraint:(LDrawPart *)part;

#pragma mark -
#pragma mark CONSTANT ACCESSORS
#pragma mark -

+(NSString *) defaultHoseConstraint;
+(NSString *) defaultBandConstraint;
+(NSString *) defaultHoseType;
+(NSString *) defaultBandType;

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

-(NSMutableArray *) getParts;
-(NSMutableArray *) getHoseTypes;
-(NSMutableArray *) getBandTypes;
-(NSMutableArray *) getHoseConstraints;
-(NSMutableArray *) getBandConstraints;
-(NSMutableArray *) getQuickRefBands;
-(NSMutableArray *) getQuickRefHoses;
-(NSMutableArray *) getQuickRefParts;
-(NSMutableArray *) getQuickRefBandContstraints;
-(NSMutableArray *) getQuickRefHoseConstraints;
-(NSDictionary *)   constraintDefinitionForPart:(LDrawPart *)directive;
-(NSDictionary *)   typeForTypeName:(NSString *)typeName;

@end
