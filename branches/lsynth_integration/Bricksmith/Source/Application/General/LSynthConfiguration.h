//
//  LSynthConfiguration.h
//  Bricksmith
//
//  Created by Robin Macharg on 24/09/2012.
//
//

#import <Foundation/Foundation.h>

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
}

#pragma mark -
#pragma mark Class Methods
#pragma mark -

//+(LSynthClassT) classForType:(NSString *)type;
+(LSynthConfiguration*) sharedInstance;


#pragma mark -
#pragma mark Instance Methods
#pragma mark -

-(void) parseLsynthConfig:(NSString *)lsynthConfigurationPath;

#pragma mark -
#pragma mark Accessors
#pragma mark -

-(NSMutableArray *)getParts;
-(NSMutableArray *)getHoseTypes;
-(NSMutableArray *)getBandTypes;
-(NSMutableArray *)getHoseConstraints;
-(NSMutableArray *)getBandConstraints;
-(NSMutableArray *)getQuickRefBands;
-(NSMutableArray *)getQuickRefHoses;

@end
