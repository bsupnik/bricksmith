//==============================================================================
//
// File:		InspectionConditionalLine.m
//
// Purpose:		Inspector Controller for an LDrawConditionalLine.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionConditionalLine.h"

#import "LDrawColorWell.h"
#import "LDrawConditionalLine.h"

@interface InspectionConditionalLine ()

@property (nonatomic, unsafe_unretained) IBOutlet	LDrawColorWell*	colorWell;
	
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex1XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex1YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex1ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex2XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex2YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	conditionalVertex2ZField;

@end


@implementation InspectionConditionalLine

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorConditionalLine" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorConditionalLine.nib");
    }
	
    return self;
	
}//end init


// MARK: - ACCESSORS -

//========== vertex1Fields =====================================================
//==============================================================================
- (NSArray<NSTextField*>*) vertex1Fields
{
	return @[_vertex1XField, _vertex1YField, _vertex1ZField];
}

//========== vertex2Fields =====================================================
//==============================================================================
- (NSArray<NSTextField*>*) vertex2Fields
{
	return @[_vertex2XField, _vertex2YField, _vertex2ZField];
}

//========== conditionalVertex1Fields ==========================================
//==============================================================================
- (NSArray<NSTextField*>*) conditionalVertex1Fields
{
	return @[_conditionalVertex1XField, _conditionalVertex1YField, _conditionalVertex1ZField];
}

//========== conditionalVertex2Fields ==========================================
//==============================================================================
- (NSArray<NSTextField*>*) conditionalVertex2Fields
{
	return @[_conditionalVertex2XField, _conditionalVertex2YField, _conditionalVertex2ZField];
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
	LDrawConditionalLine *representedObject = [self object];
	
	Point3 vertex1				= [self coordinateValueFromFields:[self vertex1Fields]];
	Point3 vertex2				= [self coordinateValueFromFields:[self vertex2Fields]];
	Point3 conditionalVertex1	= [self coordinateValueFromFields:[self conditionalVertex1Fields]];
	Point3 conditionalVertex2	= [self coordinateValueFromFields:[self conditionalVertex2Fields]];
	
	[representedObject setVertex1:vertex1];
	[representedObject setVertex2:vertex2];
	[representedObject setConditionalVertex1:conditionalVertex1];
	[representedObject setConditionalVertex2:conditionalVertex2];
	
	[super commitChanges:sender];
	
}//end commitChanges:


//========== revert: ===========================================================
//
// Purpose:		Restores the palette to reflect the state of the object.
//				This method is called automatically when the object to inspect 
//				is set. Subclasses should override this method to populate 
//				the data in their inspector palettes.
//
//==============================================================================
- (IBAction) revert:(id)sender
{
	LDrawConditionalLine *representedObject = [self object];

	[_colorWell setLDrawColor:[representedObject LDrawColor]];

	Point3 vertex1				= [representedObject vertex1];
	Point3 vertex2				= [representedObject vertex2];
	Point3 conditionalVertex1	= [representedObject conditionalVertex1];
	Point3 conditionalVertex2	= [representedObject conditionalVertex2];
	
	[self setCoordinateValue:vertex1 onFields:[self vertex1Fields]];
	[self setCoordinateValue:vertex2 onFields:[self vertex2Fields]];
	[self setCoordinateValue:conditionalVertex1 onFields:[self conditionalVertex1Fields]];
	[self setCoordinateValue:conditionalVertex2 onFields:[self conditionalVertex2Fields]];
	
	[super revert:sender];
	
}//end revert:


#pragma mark -

//========== vertex1EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex1EndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self vertex1Fields]];
	Point3 vertex1		= [[self object] vertex1];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex1) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end vertex1EndedEditing:


//========== vertex2EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex2EndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self vertex2Fields]];
	Point3 vertex2		= [[self object] vertex2];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex2) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end vertex2EndedEditing:


//========== conditionalVertex1EndedEditing: ===================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) conditionalVertex1EndedEditing:(id)sender
{
	Point3 formContents			= [self coordinateValueFromFields:[self conditionalVertex1Fields]];
	Point3 conditionalVertex1	= [[self object] conditionalVertex1];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, conditionalVertex1) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end conditionalVertex1EndedEditing:


//========== conditionalVertex2EndedEditing: ===================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) conditionalVertex2EndedEditing:(id)sender
{
	Point3 formContents			= [self coordinateValueFromFields:[self conditionalVertex2Fields]];
	Point3 conditionalVertex2	= [[self object] conditionalVertex2];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, conditionalVertex2) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end conditionalVertex2EndedEditing:


@end
