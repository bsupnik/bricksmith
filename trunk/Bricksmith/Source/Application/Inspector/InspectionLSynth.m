//==============================================================================
//
// File:		InspectionLSynth.m
//
// Purpose:		Inspector Controller for an LDraw LSynth block.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Robin Macharg
//  Copyright 2012. All rights reserved.
//==============================================================================
#import "InspectionLSynth.h"

#import "LDrawLSynth.h"
#import "LSynthConfiguration.h"
#import "LDrawApplication.h"
#import "LDrawPart.h"
#import "PartLibrary.h"
#import "LDrawGLView.h"

@implementation InspectionLSynth

//@synthesize typePopup;


//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorLSynth" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorLSynth.xib");
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
    LDrawLSynth	*representedObject	= [self object];

    // Update the object
	LSynthClassT	classType	= [[lsynthClassChooserMatrix selectedCell] tag];
	NSArray 		*types		= [self typesForLSynthClass:classType];

    [representedObject setLsynthClass:[[lsynthClassChooserMatrix selectedCell] tag]];
    [representedObject setLsynthType:[[types objectAtIndex:[typePopup indexOfSelectedItem]] valueForKey:@"LSYNTH_TYPE"]];

    // Change all constraints to the default one
    for (LDrawDirective *directive in [representedObject subdirectives]) {
        if ([directive isKindOfClass:[LDrawPart class]]) {
            if ([[sender selectedCell] tag] == LSYNTH_BAND) {
                [(LDrawPart *)directive setDisplayName:[LSynthConfiguration defaultBandConstraint]];
            }
            else if ([[sender selectedCell] tag] == LSYNTH_HOSE) {
                [(LDrawPart *)directive setDisplayName:[LSynthConfiguration defaultHoseConstraint]];
            }

            // Maybe update the constraint icons (e.g. if the part class has changed)
            [directive setIconName:[representedObject determineIconName:directive]];
        }
    }

    // We've made a change so resynthesis is probably required.
    [representedObject invalCache:ContainerInvalid];

	[super commitChanges:sender];
}//end commitChanges:

//========== setObject: ========================================================
//
// Purpose:		Called as part of the palette initialisation, after we know which
//              object we refer to.
//
//==============================================================================
- (void) setObject:(id)newObject
{
    [super setObject:newObject];

//    // At this point in the inspector initialization we have the object in question
//    // so our delegate and datasource protocol methods can answer questions sensibly
//    [constraintTable setDelegate:self];
//    [constraintTable setDataSource:self];
}


//========== revert ============================================================
//
// Purpose:		Restores the palette to reflect the state of the object.
//				This method is called automatically when the object to inspect
//				is set.
//
//==============================================================================
- (IBAction) revert:(id)sender
{
    LDrawLSynth *representedObject = [self object];
    
    // Set the part label
    [lsynthPartLabel setStringValue:[representedObject browsingDescription]];
    
    // Set the synthesized part count
    [synthesizedPartCount setStringValue:[NSString stringWithFormat:@"(approx. %i pieces)", [representedObject synthesizedPartsCount]]];
    
    // Set the Type label
    [self updateSynthTypeLabel:[representedObject lsynthClass]];

    // The class selection radio buttons are tagged with values matching the
    // LSynthConfiguration class enumeration - Part=1, Hose=2 and Band=3
    [lsynthClassChooserMatrix selectCellWithTag:[representedObject lsynthClass]];

    // Set the color well
    [colorWell setLDrawColor:[representedObject LDrawColor]];

    // Fill the type dropdown
    [self populateTypes:[representedObject lsynthClass]];

    // Fill the default constraints dropdown
    [self populateDefaultConstraint:[representedObject lsynthClass]];

	[super revert:sender];
}//end revert:

#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== populateTypes: ====================================================
//
// Purpose:		Populate the Types dropdown
//
//==============================================================================
- (void) populateTypes:(int)classTag
{
    NSArray *types = [self typesForLSynthClass:classTag];

    // Populate the dropdown
    [typePopup removeAllItems];
    if (types != nil) {
        int index = 0;
        for (NSDictionary *type in types) {

            // Add each entry
            [typePopup addItemWithTitle:[type valueForKey:@"title"]];
            [[typePopup itemAtIndex:index] setTag:index];

            // Select our current type
            if ([[[self object] lsynthType] isEqualToString:[type valueForKey:@"LSYNTH_TYPE"]]) {
                [typePopup selectItemWithTitle:[type valueForKey:@"title"]];
            }
            index++;
        }
    }
}

//========== populateDefaultConstraint: ========================================
//
// Purpose:		Populate the default-contraint dropdown
//
//==============================================================================

- (void) populateDefaultConstraint:(int)classTag
{
    NSMutableArray *constraints = nil;
    NSString *defaultConstraint;

    // Get the default constraint, dependent on class
    if (classTag == LSYNTH_BAND) {
        constraints = [[LSynthConfiguration sharedInstance] getBandConstraints];
        defaultConstraint = [LSynthConfiguration defaultBandConstraint];
    }
    else if (classTag == LSYNTH_HOSE) {
        constraints = [[LSynthConfiguration sharedInstance] getHoseConstraints];
        defaultConstraint = [LSynthConfiguration defaultHoseConstraint];
    }

    // For a complete Part the constraints depend on the part class.  Handily we worked this
    // out when we read in the LSynth config.
    else if (classTag == LSYNTH_PART) {
        NSArray *types = [self typesForLSynthClass:classTag];
        LSynthClassT partClass = [[[types objectAtIndex:[typePopup indexOfSelectedItem]] valueForKey:@"LSYNTH_CLASS"] integerValue];
        if (partClass == LSYNTH_BAND) {
            constraints = [[LSynthConfiguration sharedInstance] getBandConstraints];
            defaultConstraint = [LSynthConfiguration defaultBandConstraint];
        }
        else if (partClass == LSYNTH_HOSE) {
            constraints = [[LSynthConfiguration sharedInstance] getHoseConstraints];
            defaultConstraint = [LSynthConfiguration defaultHoseConstraint];
        }
    }

    [constraintDefaultPopup removeAllItems];

    if (constraints != nil) {
        int index = 0;
        for (NSDictionary *constraint in constraints) {

            // Add each entry...
            [constraintDefaultPopup addItemWithTitle:[constraint valueForKey:@"description"]];
            NSMenuItem *menuItem = [constraintDefaultPopup itemAtIndex:([constraintDefaultPopup numberOfItems]-1)];
            // Store the constraint details. Used in makeConstraintsDefaultForClass
            [menuItem setRepresentedObject:constraint];

            // ... selecting the default one
            if ([[[constraint valueForKey:@"partName"] uppercaseString] isEqualToString:[defaultConstraint uppercaseString]]) {
                [constraintDefaultPopup selectItemAtIndex:index];
            }
            index++;
        }
    }
}


////========== selectType:fromTypes: =============================================
////
//// Purpose:		Select a specific type
////
////==============================================================================
//-(void) selectType:(NSString *)lsynthType
//{
////    [typePopup selectItemWithTitle:lsynthType];
//}

#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== partClassChanged: =================================================
//
// Purpose:		The user has changed the class of the part.  We only change values
//              in the UI.  The commitChanges method takes care of applying these
//              to the part.
//
//==============================================================================
- (IBAction)partClassChanged:(id)sender
{
    LDrawLSynth *representedObject = [self object];

    // Check that we're actually selecting a different class of synthesized part
    if ([[sender selectedCell] tag] != [representedObject lsynthClass]) {
        
        [self updateSynthTypeLabel:[[sender selectedCell] tag]];

        // Populate the types dropdown correctly
        [self populateTypes:[[sender selectedCell] tag]];

        // Select the default type for the class
        NSDictionary *type = nil;
        if ([[sender selectedCell] tag] == LSYNTH_BAND) {
            type = [[LSynthConfiguration sharedInstance] typeForTypeName:[LSynthConfiguration defaultBandType]];
        }
        else if ([[sender selectedCell] tag] == LSYNTH_HOSE) {
            type = [[LSynthConfiguration sharedInstance] typeForTypeName:[LSynthConfiguration defaultHoseType]];
        }

        if (type != nil) {
            [typePopup selectItemWithTitle:[type valueForKey:@"title"]];
        }
        else {
            [typePopup selectItemAtIndex:0];
        }

        // Populate the constraints dropdown and select the default
        [self populateDefaultConstraint:[[sender selectedCell] tag]];

        // Finish and invoke redisplay
        [self finishedEditing:sender];
    }
}

//========== makeConstraintsDefaultForClass: ===================================
//
// Purpose:		If the synth class has changed convert the constraints to an
//              appropriate default.  Hoses only work with hose constraints,
//              bands similarly.
//
//              TODO: Our defaults are arbitrary but could be preferences
//
//==============================================================================
- (IBAction)makeConstraintsDefaultForClass:(id)sender {
    LDrawLSynth *representedObject = [self object];

    for (LDrawDirective *directive in [representedObject subdirectives]) {
        if ([directive isKindOfClass:[LDrawPart class]]) {
            [(LDrawPart *)directive setDisplayName:[[[constraintDefaultPopup selectedItem] representedObject] valueForKey:@"partName"]];
        }
    }

    // Finish and invoke redisplay
    [self finishedEditing:sender];
    [self revert:sender];
}

//========== partTypeChanged: ==================================================
//
// Purpose:		The user has changed the part type in the dropdown.
//
//==============================================================================
- (IBAction)partTypeChanged:(id)sender
{
    // Finish and invoke redisplay
    [self finishedEditing:sender];
    [self revert:sender];
}

#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== typesForLSynthClass: ==============================================
//
// Purpose:		Convenience method to return types for a synth class
//
//==============================================================================
- (NSArray *)typesForLSynthClass:(LSynthClassT)classTag
{
    LSynthConfiguration *lsynthConfig = [[NSApp delegate] lsynthConfiguration];

    // Parts
    if (classTag == LSYNTH_PART) {
        //types = [lsynthConfig getParts];  // TODO: enable this
        return [lsynthConfig getParts];
    }

    // Hoses
    else if (classTag == LSYNTH_HOSE) {
        return [lsynthConfig getHoseTypes];
    }

    // Bands
    else if (classTag == LSYNTH_BAND) {
        return [lsynthConfig getBandTypes];
    }
    
    return nil;
}//end typesForLSynthClass:


//========== updateSynthTypeLabel: =============================================
//
// Purpose:		Show the label type.
//
//==============================================================================
- (void) updateSynthTypeLabel:(LSynthClassT)tag
{
    // Update the type title according to our class of synthesized part
    if (tag == LSYNTH_PART) {
        [SynthTypeLabel setStringValue:@"Part Type:"];
    }
    else if (tag == LSYNTH_HOSE) {
        [SynthTypeLabel setStringValue:@"Hose Type:"];
    }
    else if (tag == LSYNTH_BAND) {
        [SynthTypeLabel setStringValue:@"Band Type:"];
    }
}


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Cockle warming for larger ladies
//
//==============================================================================
- (void)dealloc {
   // [typePopup release];
    [super dealloc];
}//end dealloc

@end
