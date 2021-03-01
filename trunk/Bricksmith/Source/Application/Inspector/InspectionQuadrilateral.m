//==============================================================================
//
// File:		InspectionQuadrilateral.m
//
// Purpose:		Inspector Controller for an LDrawQuadrilateral.
//
//				This inspector panel is loaded by the main Inspector class.
//
//  Created by Allen Smith on 3/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "InspectionQuadrilateral.h"

#import "LDrawColorWell.h"
#import "LDrawModel.h"
#import "LDrawQuadrilateral.h"

@implementation QuadrilateralView

//========== drawRect: =========================================================
//
// Purpose:		Draw a rectangle outline.
//
//==============================================================================
- (void) drawRect:(NSRect)rect
{
	NSBezierPath	*trianglePath	= [NSBezierPath bezierPath];
	NSRect			frame			= NSInsetRect([self bounds], 2, 2);
	
	[trianglePath moveToPoint:NSMakePoint( NSMinX(frame), NSMinY(frame) )];
	[trianglePath lineToPoint:NSMakePoint( NSMaxX(frame), NSMinY(frame) )];
	[trianglePath lineToPoint:NSMakePoint( NSMaxX(frame), NSMaxY(frame) )];
	[trianglePath lineToPoint:NSMakePoint( NSMinX(frame), NSMaxY(frame) )];
	[trianglePath closePath];
	
	[[NSColor grayColor] set];
	[trianglePath setLineWidth:1.5];
	[trianglePath stroke];
	
}//end drawRect:


@end


// MARK: -

@interface InspectionQuadrilateral ()

@property (nonatomic, unsafe_unretained) IBOutlet	LDrawColorWell*	colorWell;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex1ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex2ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex3XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex3YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex3ZField;

@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex4XField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex4YField;
@property (nonatomic, unsafe_unretained) IBOutlet	NSTextField*	vertex4ZField;

@end


@implementation InspectionQuadrilateral

//========== init ==============================================================
//
// Purpose:		Load the interface for this inspector.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"InspectorQuadrilateral" owner:self] == NO) {
        NSLog(@"Couldn't load InspectorQuadrilateral.nib");
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

//========== vertex3Fields =====================================================
//==============================================================================
- (NSArray<NSTextField*>*) vertex3Fields
{
	return @[_vertex3XField, _vertex3YField, _vertex3ZField];
}

//========== vertex4Fields =====================================================
//==============================================================================
- (NSArray<NSTextField*>*) vertex4Fields
{
	return @[_vertex4XField, _vertex4YField, _vertex4ZField];
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
	LDrawQuadrilateral *representedObject = [self object];
	
	Point3	vertex1 = [self coordinateValueFromFields:[self vertex1Fields]];
	Point3	vertex2 = [self coordinateValueFromFields:[self vertex2Fields]];
	Point3	vertex3 = [self coordinateValueFromFields:[self vertex3Fields]];
	Point3	vertex4 = [self coordinateValueFromFields:[self vertex4Fields]];

	[representedObject setVertex1:vertex1];
	[representedObject setVertex2:vertex2];
	[representedObject setVertex3:vertex3];
	[representedObject setVertex4:vertex4];
	
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
	LDrawQuadrilateral *representedObject = [self object];

	[_colorWell setLDrawColor:[representedObject LDrawColor]];

	Point3 vertex1 = [representedObject vertex1];
	Point3 vertex2 = [representedObject vertex2];
	Point3 vertex3 = [representedObject vertex3];
	Point3 vertex4 = [representedObject vertex4];
	
	[self setCoordinateValue:vertex1 onFields:[self vertex1Fields]];
	[self setCoordinateValue:vertex2 onFields:[self vertex2Fields]];
	[self setCoordinateValue:vertex3 onFields:[self vertex3Fields]];
	[self setCoordinateValue:vertex4 onFields:[self vertex4Fields]];

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


//========== vertex3EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex3EndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self vertex3Fields]];
	Point3 vertex3		= [[self object] vertex3];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex3) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end vertex3EndedEditing:


//========== vertex4EndedEditing: ==============================================
//
// Purpose:		The user had been editing the coordinate; now he has stopped. 
//				We need to find out if he actually changed something. If so, 
//				update the object.
//
//==============================================================================
- (IBAction) vertex4EndedEditing:(id)sender
{
	Point3 formContents	= [self coordinateValueFromFields:[self vertex4Fields]];
	Point3 vertex4		= [[self object] vertex4];
	
	//If the values really did change, then update.
	if(V3EqualPoints(formContents, vertex4) == NO)
	{
		[self finishedEditing:sender];
	}
		
}//end vertex4EndedEditing:


@end
