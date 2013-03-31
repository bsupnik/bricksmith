//
//  LSynthConfiguration.m
//  Bricksmith
//
//  Created by Robin Macharg on 24/09/2012.

#import "LSynthConfiguration.h"
#import "LDrawUtilities.h"
#import "MacLDraw.h"
#import "LDrawPart.h"
#import "LDrawLSynth.h"

@implementation LSynthConfiguration

#pragma mark -
#pragma mark CLASS CONSTANTS
#pragma mark -

//========== Class constants ===================================================
//
// Purpose:		Class Constants
//
// TODO: make configurable preferences
//
//==============================================================================

static NSString *DEFAULT_HOSE_CONSTRAINT = @"LS01.DAT";
static NSString *DEFAULT_BAND_CONSTRAINT = @"3648a.dat";
static NSString *DEFAULT_HOSE_TYPE = @"TECHNIC_PNEUMATIC_HOSE";
static NSString *DEFAULT_BAND_TYPE = @"TECHNIC_CHAIN_LINK";

//========== defaultHoseConstraint =============================================
//
// Purpose: Return the default hose constraint
//
//==============================================================================
+(NSString *) defaultHoseConstraint
{
    return DEFAULT_HOSE_CONSTRAINT;
}//end defaultHoseConstraint

//========== defaultBandConstraint =============================================
//
// Purpose: Return the default band constraint
//
//==============================================================================
+(NSString *) defaultBandConstraint
{
    return DEFAULT_BAND_CONSTRAINT;
}//end defaultBandConstraint

//========== defaultHoseType ===================================================
//
// Purpose: Return the default hose type
//
//==============================================================================
+(NSString *) defaultHoseType
{
    return DEFAULT_HOSE_TYPE;
}//end defaultHoseType

//========== defaultBandCType ==================================================
//
// Purpose: Return the default band type
//
//==============================================================================
+(NSString *) defaultBandType
{
    return DEFAULT_BAND_TYPE;
}//end defaultBandType

#pragma mark -
#pragma mark SINGLETON
#pragma mark -

// Container for our singleton instance
static LSynthConfiguration* instance = nil;

//========== sharedInstance ====================================================
//
// Purpose: Return the singleton LSynthConfiguration instance.
//
//==============================================================================
+(LSynthConfiguration *) sharedInstance
{
    @synchronized(self)
    {
        if(instance == nil) {
            instance = [[LSynthConfiguration alloc] init];
        }
        return instance;
    }
}

//========== init ==============================================================
//
// Purpose:		initialize the LSynthConfiguration instance.
//
//==============================================================================
-(id)init
{
	self = [super init];
    if (self)
	{
        parts                   = [[NSMutableArray alloc] init];
        hose_constraints        = [[NSMutableArray alloc] init];
        hose_types              = [[NSMutableArray alloc] init];
        band_constraints        = [[NSMutableArray alloc] init];
        band_types              = [[NSMutableArray alloc] init];

        quickRefBands           = [[NSMutableArray alloc] init];
        quickRefHoses           = [[NSMutableArray alloc] init];
        quickRefParts           = [[NSMutableArray alloc] init];
        quickRefBandConstraints = [[NSMutableArray alloc] init];
        quickRefHoseConstraints = [[NSMutableArray alloc] init];
    }
    return self;
}

//========== parseLsynthConfig: ================================================
//
// Purpose:		Parse an LSynth lsynth.mpd configuration file in order that we
//              can a) validate incoming ldraw files if required and b) populate
//              parts menus appropriately.  We only need to parse the file enough
//              to satisfy these requirements; LSynth has a better understanding
//              of this config file.
//
// TODO: do we need to parse in as much detail?  Surely we just need
//       description + part + type
//==============================================================================
-(void) parseLsynthConfig:(NSString *)lsynthConfigurationPath
{
    // Read the file in
   	NSString   *fileContents = [LDrawUtilities stringFromFile:lsynthConfigurationPath];
    NSArray    *lines        = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // General parsing variables
    NSUInteger  lineIndex    = 0;
    NSRange     range        = {0, [lines count]};
    NSString   *currentLine  = nil;
    NSString   *previousLine = nil;
    
    // LSynth sscanf()-specific line scanning variables
    char        product[126],
                title[128],
                method[128],
                type[128],
                stretch[128],
                fill[128];
    int         d,             // diameter
                st;            // stiffness
    float       t,             // twist
                scale,
                thresh;
    NSMutableArray *tmp_parts = [[NSMutableArray alloc] init];

    while(lineIndex < NSMaxRange(range)) {
        currentLine = [lines objectAtIndex:lineIndex];
        if([currentLine length] > 0) {
            
            // HOSE CONSTRAINTS, e.g.
            //
            // 0 // LSynth Constraint Part - Type 1 - "Hose"
            // 1 0 0 0 0 1 0 0 0 1 0 0 0 1 LS01.dat
            
            if ([[lines objectAtIndex:lineIndex] isEqualToString:@"0 SYNTH BEGIN DEFINE HOSE CONSTRAINTS"]) {
                lineIndex++;
                
                // Local block line-parsing variables.  TODO: move to top 
                int flip;
                float offset[3];
                float orient[3][3];
                char type[128];
                
                while (! [[lines objectAtIndex:lineIndex] isEqualToString:@"0 SYNTH END"]) {
                    if (sscanf([[lines objectAtIndex:lineIndex] UTF8String],"1 %d %f %f %f %f %f %f %f %f %f %f %f %f %s",
                               &flip,
                               &offset[0],    &offset[1],    &offset[2],
                               &orient[0][0], &orient[0][1], &orient[0][2],
                               &orient[1][0], &orient[1][1], &orient[1][2],
                               &orient[2][0], &orient[2][1], &orient[2][2],
                               type) == 14) {
                        
                        // Extract description
                        // Big assumption: that we have useful contents in the previous line
                        // TODO: harden
                        NSString *desc = [[previousLine componentsSeparatedByString:@"- Type "] objectAtIndex:1];
                        
                        NSDictionary *hose_constraint = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:

                                // flip
                                [NSNumber numberWithInt:flip],

                                // offset
                                [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat:offset[0]],
                                    [NSNumber numberWithFloat:offset[1]],
                                    [NSNumber numberWithFloat:offset[2]],
                                    nil],

                                // orient
                                [NSArray arrayWithObjects:
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[0][0]],
                                        [NSNumber numberWithFloat:orient[0][1]],
                                        [NSNumber numberWithFloat:orient[0][2]],
                                        nil],
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[1][0]],
                                        [NSNumber numberWithFloat:orient[1][1]],
                                        [NSNumber numberWithFloat:orient[1][2]],
                                        nil],
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[2][0]],
                                        [NSNumber numberWithFloat:orient[2][1]],
                                        [NSNumber numberWithFloat:orient[2][2]],
                                        nil],
                                     nil],

                                // partName
                                [NSString stringWithUTF8String:type],
                                                                                             
                                // description
                                desc,

                                // LSYNTH_CONSTRAINT_CLASS
                                [NSNumber numberWithInt:LSYNTH_HOSE],

                                nil
                            ]

                            forKeys:[NSArray arrayWithObjects:@"flip", @"offset", @"orient", @"partName", @"description", @"LSYNTH_CONSTRAINT_CLASS", nil]
                        ]; // end hose_constraint

                        [hose_constraints addObject:hose_constraint];
                        [quickRefHoseConstraints addObject:[[NSString stringWithCString:type encoding:NSUTF8StringEncoding] lowercaseString]];
                    }
                    
                    // The description precedes the constraint definition so save it for the next time round
                    else if ([[lines objectAtIndex:(lineIndex)] length] > 0) {
                        previousLine = [[NSString alloc] initWithString:[lines objectAtIndex:(lineIndex)]];
                    }
                
                    lineIndex++;
                }
            } // END HOSE CONSTRAINTS
            
            
            // BAND CONSTRAINTS, e.g.
            //
            // 0 // Technic Axle 2 Notched
            // 1 8 0 0 0 0 0 1 0 1 0 -1 0 0 32062.DAT
            
            else if ([[lines objectAtIndex:lineIndex] isEqualToString:@"0 SYNTH BEGIN DEFINE BAND CONSTRAINTS"]) {
                lineIndex++;
                
                // Local block line-parsing variables.  TODO: move to top 
                int radius;
                float offset[3];
                float orient[3][3];
                char type[128];
                
                while (! [[lines objectAtIndex:lineIndex] isEqualToString:@"0 SYNTH END"]) {
                    if (sscanf([[lines objectAtIndex:lineIndex] UTF8String],"1 %d %f %f %f %f %f %f %f %f %f %f %f %f %s",
                               &radius,
                               &offset[0],    &offset[1],    &offset[2],
                               &orient[0][0], &orient[0][1], &orient[0][2],
                               &orient[1][0], &orient[1][1], &orient[1][2],
                               &orient[2][0], &orient[2][1], &orient[2][2],
                               type) == 14) {
                        
                        // Extract description
                        // Big assumption: that we have useful contents in the previous line
                        // TODO: harden
                        NSString *desc = [[previousLine componentsSeparatedByString:@"// "] objectAtIndex:1];
                        
                        NSDictionary *band_constraint = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:

                                // radius
                                [NSNumber numberWithInt:radius],

                                // offset
                                [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat:offset[0]],
                                    [NSNumber numberWithFloat:offset[1]],
                                    [NSNumber numberWithFloat:offset[2]],
                                    nil],

                                // orient
                                [NSArray arrayWithObjects:
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[0][0]],
                                        [NSNumber numberWithFloat:orient[0][1]],
                                        [NSNumber numberWithFloat:orient[0][2]],
                                        nil],
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[1][0]],
                                        [NSNumber numberWithFloat:orient[1][1]],
                                        [NSNumber numberWithFloat:orient[1][2]],
                                        nil],
                                    [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:orient[2][0]],
                                        [NSNumber numberWithFloat:orient[2][1]],
                                        [NSNumber numberWithFloat:orient[2][2]],
                                        nil],
                                    nil],

                                // partName
                                [NSString stringWithUTF8String:type],

                                // description
                                desc,

                                // LSYNTH_CONSTRAINT_CLASS
                                [NSNumber numberWithInt:LSYNTH_BAND],

                                nil
                        ]

                        forKeys:[NSArray arrayWithObjects:@"radius", @"offset", @"orient", @"partName", @"description", @"LSYNTH_CONSTRAINT_CLASS", nil]
                        ]; // end band_constraint

                        [band_constraints addObject:band_constraint];
                        [quickRefBandConstraints addObject:[[NSString stringWithCString:type encoding:NSUTF8StringEncoding] lowercaseString]];
                    }
                    
                    // The description precedes the constraint definition so save it for the next time round
                    else if ([[lines objectAtIndex:(lineIndex)] length] > 0) {
                        previousLine = [lines objectAtIndex:(lineIndex)];
                    }
                    
                    lineIndex++;
                }
            } // END BAND CONSTRAINTS

            // SYNTH PART lines, e.g.
            //
            // 0 SYNTH PART 4297187.dat PLI_ELECTRIC_NXT_CABLE_20CM   ELECTRIC_NXT_CABLE

            else if (sscanf([currentLine UTF8String],"0 SYNTH PART %s %s %s\n", product, title, type) == 3) {
                NSMutableDictionary *part = [NSMutableDictionary
                        dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:product encoding:NSUTF8StringEncoding],
                                        [[[NSString stringWithCString:title encoding:NSUTF8StringEncoding]
                                                stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString],
                                                                        [NSString stringWithCString:type encoding:NSUTF8StringEncoding],
                                                                        [NSString stringWithCString:title encoding:NSUTF8StringEncoding],
                                                                        @"",
                                                                        nil]
                                      forKeys:[NSArray arrayWithObjects:@"product", @"title", @"method", @"LSYNTH_TYPE", @"LSYNTH_CLASS", nil]];


                [tmp_parts addObject:part];
                // This (& the two below) feel a little hacky.  Better to have them as class methods on the config.
                [quickRefParts addObject:[NSString stringWithCString:title encoding:NSUTF8StringEncoding]];

            } // END PART

            // HOSE DEFINITIONS, e.g.
            //
            // 0 SYNTH BEGIN DEFINE BRICK_ARC HOSE FIXED 1 100 0
            //
            // We don't care about the rest of the definition (LSynth does)
            
            else if (sscanf([[lines objectAtIndex:lineIndex] UTF8String], "0 SYNTH BEGIN DEFINE %s HOSE %s %d %d %f", type, stretch, &d, &st, &t) == 5) {
                NSDictionary *hose_def = [NSDictionary
                    dictionaryWithObjects:[NSArray arrayWithObjects:
                        [[[NSString stringWithCString:type encoding:NSUTF8StringEncoding]
                            stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString],
                        [NSString stringWithCString:type encoding:NSUTF8StringEncoding],
                        [NSNumber numberWithInt:LSYNTH_HOSE],
                        nil]
                    forKeys:[NSArray arrayWithObjects:@"title", @"LSYNTH_TYPE", @"LSYNTH_CLASS", nil]];

                [hose_types addObject:hose_def];
                [quickRefHoses addObject:[NSString stringWithCString:type encoding:NSUTF8StringEncoding]];
            }
            
            // BAND DEFINITIONS, e.g.
            //
            // 0 SYNTH BEGIN DEFINE CHAIN BAND FIXED 0.0625 8
            //
            // We don't care about the rest of the definition (LSynth does)
            
            else if (sscanf([[lines objectAtIndex:lineIndex] UTF8String], "0 SYNTH BEGIN DEFINE %s BAND %s %f %f", type, fill, &scale, &thresh) == 4) {
                NSDictionary *band_def = [NSDictionary
                    dictionaryWithObjects:[NSArray arrayWithObjects:
                        [[[NSString stringWithCString:type encoding:NSUTF8StringEncoding]
                            stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString],
                        [NSString stringWithCString:type encoding:NSUTF8StringEncoding],
                        [NSNumber numberWithInt:LSYNTH_BAND],
                        nil]
                    forKeys:[NSArray arrayWithObjects:@"title", @"LSYNTH_TYPE", @"LSYNTH_CLASS", nil]];

                [band_types addObject:band_def];
                [quickRefBands addObject:[NSString stringWithCString:type encoding:NSUTF8StringEncoding]];
            }
        }
        lineIndex++;
    }

    // Now we've read in all the config we can go back over our SYNTH PARTs and apply the correct class to them,
    // based on a matching band or hose type.  Not performant, but run only once at startup.

    for (NSMutableDictionary *part in tmp_parts) {
        if ([[self getQuickRefBands] containsObject:[part objectForKey:@"method"]]) {
            [part setValue:[NSNumber numberWithInt:LSYNTH_BAND] forKey:@"LSYNTH_CLASS"];
        }
        else if ([[self getQuickRefHoses] containsObject:[part objectForKey:@"method"]]) {
            [part setValue:[NSNumber numberWithInt:LSYNTH_HOSE] forKey:@"LSYNTH_CLASS"];
        }
        [parts addObject:part];
    }
}

//========== isLSynthConstraint: ===============================================
//
// Purpose:		Determine if a given part is an "official" LSynth constraint,
//              i.e. defined in lsynth.ldr, and parsed into the LSynthConfiguration
//              object.
//
//==============================================================================
-(BOOL) isLSynthConstraint:(LDrawPart *)part
{
    if ([quickRefBandConstraints containsObject:[part referenceName]] ||
        [quickRefHoseConstraints containsObject:[part referenceName]]) {
        return YES;
    }
    return NO;
}//end isLSynthConstraint:

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

// TODO: move to properties

- (NSMutableArray *) getParts
{
    return self->parts;
}

- (NSMutableArray *) getHoseTypes
{
    return self->hose_types;
}

- (NSMutableArray *) getHoseConstraints
{
    return self->hose_constraints;
}

- (NSMutableArray *) getBandTypes
{
    return self->band_types;
}

- (NSMutableArray *) getBandConstraints
{
    return self->band_constraints;
}

- (NSMutableArray *)getQuickRefBands
{
    return self->quickRefBands;
}

- (NSMutableArray *)getQuickRefHoses
{
    return self->quickRefHoses;
}

- (NSMutableArray *)getQuickRefParts
{
    return self->quickRefParts;
}
- (NSMutableArray *)getQuickRefBandContstraints
{
    return self->quickRefBandConstraints;
}

- (NSMutableArray *)getQuickRefHoseConstraints
{
    return self->quickRefHoseConstraints;
}

//========== constraintDefinitionForPart: ======================================
//
// Purpose:		Look up a constraint by part type.  Not especially performant.
//              Consider adding a dictionary for lookup?
//
//==============================================================================
-(NSDictionary *)constraintDefinitionForPart:(LDrawPart *)directive
{
    for (NSDictionary *constraint in self->hose_constraints) {
        if ([[[constraint objectForKey:@"partName"] lowercaseString] isEqualToString:[directive referenceName]]) {
            return constraint;
        }
    }

    for (NSDictionary *constraint in self->band_constraints) {
        if ([[[constraint objectForKey:@"partName"] lowercaseString] isEqualToString:[directive referenceName]]) {
            return constraint;
        }
    }

    return nil;
} //end constraintDefinitionForPart:

//========== typeForTypeName: ==================================================
//
// Purpose:		Look up a band or hose definition by name.  Used when the class
//              is changed.  Not especially performant.
//
//==============================================================================
-(NSDictionary *)typeForTypeName:(NSString *)typeName
{
    for (NSDictionary *type in band_types) {
        if ([[type valueForKey:@"LSYNTH_TYPE"] isEqualToString:typeName]) {
            return type;
        }
    }

    for (NSDictionary *type in hose_types) {
        if ([[type valueForKey:@"LSYNTH_TYPE"] isEqualToString:typeName]) {
            return type;
        }
    }
    return nil;
}//end typeForTypeName:

//========== setLSynthClassForDirective:withType: ==============================
//
// Purpose:		Set the class of an LSynthDirective based on the part type name
//
//==============================================================================
-(void) setLSynthClassForDirective:(LDrawLSynth *)directive withType:(NSString *)type
{
        // Determine the class - hose, band or part
        if ([[self getQuickRefHoses] containsObject:type]) {
            [directive setLsynthClass:LSYNTH_HOSE];
        }
        else if ([[self getQuickRefBands] containsObject:type]){
            [directive setLsynthClass:LSYNTH_BAND];
        }
        else if ([[self getQuickRefParts] containsObject:type]){
            [directive setLsynthClass:LSYNTH_PART];
        }
        else {
            NSLog(@"Unknown LSynth type");
        }
}

@end
