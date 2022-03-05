//==============================================================================
//
// File:		InspectionLSynth.h
//
// Purpose:		Inspector Controller for an LDraw LSynth Block
//
//  Created by Robin Macharg, sometime in deepest, darkest 2012
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"
#import "LSynthConfiguration.h"
#import "LDrawColorWell.h"

@interface InspectionLSynth : ObjectInspectionController <NSTableViewDelegate, NSTableViewDataSource>
{
	__weak IBOutlet NSTextField    *lsynthPartLabel;
	__weak IBOutlet NSTextField    *synthesizedPartCount;
	__weak IBOutlet NSMatrix       *lsynthClassChooserMatrix;
	__weak IBOutlet NSTextField    *SynthTypeLabel;
	__weak IBOutlet NSPopUpButton  *typePopup;
	__weak IBOutlet NSPopUpButton  *constraintDefaultPopup;
	__weak IBOutlet NSPopUpButton  *defaultConstraints;
	__weak IBOutlet LDrawColorWell *colorWell;
}

//@property(nonatomic, retain) NSPopUpButton *typePopup;


//Actions
- (IBAction)                partTypeChanged:(id)sender;
- (IBAction)               partClassChanged:(id)sender;
- (IBAction) makeConstraintsDefaultForClass:(id)sender;

- (void) populateTypes:(int)lsynthClass;
- (void) populateDefaultConstraint:(int)class;

// Utilities
- (NSArray *) typesForLSynthClass:(LSynthClassT)classTag;
- (void) updateSynthTypeLabel:(LSynthClassT)tag;

@end
