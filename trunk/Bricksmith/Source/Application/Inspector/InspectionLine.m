//==============================================================================
//
// File:		InspectionLine.m
//
// Purpose:		Inspector Controller for an LDrawLine.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionLine.h"

#import "LDrawColorWell.h"
#import "LDrawLine.h"
#import "LDrawModel.h"

@interface InspectionLine ()

@property (nonatomic, weak) IBOutlet	LDrawColorWell*	colorWell;
	
@property (nonatomic, weak) IBOutlet	NSTextField*	startPointXField;
@property (nonatomic, weak) IBOutlet	NSTextField*	startPointYField;
@property (nonatomic, weak) IBOutlet	NSTextField*	startPointZField;

@property (nonatomic, weak) IBOutlet	NSTextField*	endPointXField;
@property (nonatomic, weak) IBOutlet	NSTextField*	endPointYField;
@property (nonatomic, weak) IBOutlet	NSTextField*	endPointZField;

@end


@implementation InspectionLine

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorLine" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorLine.nib");
    }
    return self;
	
}//end init


// MARK: - ACCESSORS -

//========== startPointFields ==================================================
///
/// @abstract	Text fields for the start point coordinate
///
//==============================================================================
- (NSArray<NSTextField*>*) startPointFields
{
	return @[_startPointXField, _startPointYField, _startPointZField];
}

//========== endPointFields ====================================================
///
/// @abstract	Text fields for the end point coordinate
///
//==============================================================================
- (NSArray<NSTextField*>*) endPointFields
{
	return @[_endPointXField, _endPointYField, _endPointZField];
}

#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== finishedEditing: ==================================================
//
// Purpose:		Called in response to the conclusion of editing in the palette.
//
//==============================================================================
- (void) commitChanges:(id)sender
{
	LDrawLine *representedObject = [self object];
	
	Point3 vertex1 = [self coordinateValueFromFields:[self startPointFields]];
	Point3 vertex2 = [self coordinateValueFromFields:[self endPointFields]];
	
	[representedObject setVertex1:vertex1];
	[representedObject setVertex2:vertex2];
	
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
	LDrawLine *representedObject = [self object];

	[_colorWell setLDrawColor:[representedObject LDrawColor]];

	Point3 vertex1 = [representedObject vertex1];
	Point3 vertex2 = [representedObject vertex2];
	
	[self setCoordinateValue:vertex1 onFields:[self startPointFields]];
	[self setCoordinateValue:vertex2 onFields:[self endPointFields]];
	
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== startPointEndedEditing: ===========================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) startPointEndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self startPointFields]];
	Point3 vertex1		= [[self object] vertex1];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex1) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end startPointEndedEditing:


//========== endPointEndedEditing: =============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) endPointEndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self endPointFields]];
	Point3 vertex2		= [[self object] vertex2];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex2) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end endPointEndedEditing:


@end
