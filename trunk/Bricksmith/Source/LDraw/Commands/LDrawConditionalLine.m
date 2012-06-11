//==============================================================================
//
// File:		LDrawConditionalLine.m
//
// Purpose:		Conditional-Line command.
//				Draws a line between the first two points, if the projections of 
//				the last two points onto the screen are on the same side of an 
//				imaginary line through the projections of the first two points 
//				onto the screen.
//
//				Line format:
//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4 
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x1, y1, z1 is the position of the first point
//				* x2, y2, z2 is the position of the second point
//				* x3, y3, z3 is the position of the third point
//				* x4, y4, z4 is the position of the fourth point 
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawConditionalLine.h"

#import "LDrawUtilities.h"

@implementation LDrawConditionalLine


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Returns the LDraw directive based on lineFromFile, a single line 
//				of LDraw code from a file.
//
//				directive should have the format:
//
//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4 
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString                *workingLine            = [lines objectAtIndex:range.location];
	NSString                *parsedField            = nil;
	Point3                  workingVertex           = ZeroPoint3;
	LDrawColor				*parsedColor			= nil;
	
	// Our superclass is LDrawLine, which has its own unique syntax, so we can't 
	// call -[super initWithLines:inRange:] 
	self = [self init];
	
	//A malformed part could easily cause a string indexing error, which would 
	// raise an exception. We don't want this to happen here.
	@try
	{
		//Read in the line code and advance past it.
		parsedField = [LDrawUtilities readNextField:  workingLine
										  remainder: &workingLine ];
		//Only attempt to create the part if this is a valid line.
		if([parsedField integerValue] == 5)
		{
			//Read in the color code.
			// (color)
			parsedField = [LDrawUtilities readNextField:  workingLine
											  remainder: &workingLine ];
			parsedColor = [LDrawUtilities parseColorFromField:parsedField];
			[self setLDrawColor:parsedColor];
			
			//Read Vertex 1.
			// (x1)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.x = [parsedField floatValue];
			// (y1)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.y = [parsedField floatValue];
			// (z1)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.z = [parsedField floatValue];
			
			[self setVertex1:workingVertex];
				
			//Read Vertex 2.
			// (x2)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.x = [parsedField floatValue];
			// (y2)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.y = [parsedField floatValue];
			// (z2)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.z = [parsedField floatValue];
			
			[self setVertex2:workingVertex];
			
			//Read Conditonal Vertex 1.
			// (x3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.x = [parsedField floatValue];
			// (y3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.y = [parsedField floatValue];
			// (z3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.z = [parsedField floatValue];
			
			[self setConditionalVertex1:workingVertex];
			
			//Read Conditonal Vertex 2.
			// (x4)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.x = [parsedField floatValue];
			// (y4)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.y = [parsedField floatValue];
			// (z4)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.z = [parsedField floatValue];
			
			[self setConditionalVertex2:workingVertex];
		}
		else
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad conditional line syntax" userInfo:nil];
	}	
	@catch(NSException *exception)
	{
		NSLog(@"the conditional line primitive %@ was fatally invalid", [lines objectAtIndex:range.location]);
		NSLog(@" raised exception %@", [exception name]);
		[self release];
		self = nil;
	}
	
	return self;
	
}//end initWithLines:inRange:


//========== initWithCoder: ====================================================
//
// Purpose:		Reads a representation of this object from the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (id) initWithCoder:(NSCoder *)decoder
{
	const uint8_t *temporary = NULL; //pointer to a temporary buffer returned by the decoder.
	
	self		= [super initWithCoder:decoder];
	
	//Decoding structures is a bit messy.
	temporary	= [decoder decodeBytesForKey:@"conditionalVertex1" returnedLength:NULL];
	memcpy(&conditionalVertex1, temporary, sizeof(Point3));
	
	temporary	= [decoder decodeBytesForKey:@"conditionalVertex2" returnedLength:NULL];
	memcpy(&conditionalVertex2, temporary, sizeof(Point3));
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeBytes:(void *)&conditionalVertex1 length:sizeof(Point3) forKey:@"conditionalVertex1"];
	[encoder encodeBytes:(void *)&conditionalVertex2 length:sizeof(Point3) forKey:@"conditionalVertex2"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawConditionalLine *copied = (LDrawConditionalLine *)[super copyWithZone:zone];
	
	[copied setConditionalVertex1:[self conditionalVertex1]];
	[copied setConditionalVertex2:[self conditionalVertex2]];
	
	return copied;
	
}//end copyWithZone:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:optionsMask: =================================================
//
// Purpose:		We have completely disabled these conditional lines. They add 
//				little to the modern shaded LDraw experience, and they would 
//				absolutely kill performance. 
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	//do nothing.
	
}//end draw:optionsMask:


//========== drawElement:viewScale:withColor: ==================================
//
// Purpose:		Draws the graphic of the element represented. This call is a 
//				subroutine of -draw: in LDrawDrawableElement.
//
// Note:		DISABLED. See -draw:parentColor:
//
//==============================================================================
- (void) drawElement:(NSUInteger)optionsMask viewScale:(float)scaleFactor withColor:(LDrawColor *)drawingColor
{
	[super drawElement:optionsMask viewScale:scaleFactor withColor:drawingColor];
	
}//end drawElement:withColor:


//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//				Line format:
//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4 
//
//==============================================================================
- (NSString *) write
{
	return [NSString stringWithFormat:
				@"5 %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@",
				[LDrawUtilities outputStringForColor:self->color],
				
				[LDrawUtilities outputStringForFloat:vertex1.x],
				[LDrawUtilities outputStringForFloat:vertex1.y],
				[LDrawUtilities outputStringForFloat:vertex1.z],
				
				[LDrawUtilities outputStringForFloat:vertex2.x],
				[LDrawUtilities outputStringForFloat:vertex2.y],
				[LDrawUtilities outputStringForFloat:vertex2.z],
				
				[LDrawUtilities outputStringForFloat:conditionalVertex1.x],
				[LDrawUtilities outputStringForFloat:conditionalVertex1.y],
				[LDrawUtilities outputStringForFloat:conditionalVertex1.z],
		
				[LDrawUtilities outputStringForFloat:conditionalVertex2.x],
				[LDrawUtilities outputStringForFloat:conditionalVertex2.y],
				[LDrawUtilities outputStringForFloat:conditionalVertex2.z]		
			];
}//end write


//========== writeElementToVertexBuffer:withColor:wireframe: ===================
//
// Purpose:		Writes this object into the specified vertex buffer, which is a 
//				pointer to the offset into which the first vertex point's data 
//				is to be stored. Store subsequent vertexs after the first.
//
//==============================================================================
- (VBOVertexData *) writeElementToVertexBuffer:(VBOVertexData *)vertexBuffer
									 withColor:(LDrawColor *)drawingColor
									 wireframe:(BOOL)wireframe
{
	// This should never be called, but just in case...
	return NULL;

}//end writeElementToVertexBuffer:withColor:


#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) browsingDescription
{
	return NSLocalizedString(@"ConditionalLine", nil);
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"ConditionalLine";
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionConditionalLine";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== conditionalVertex1 ================================================
//
// Purpose:		Returns the triangle's first vertex.
//
//==============================================================================
- (Point3) conditionalVertex1
{
	return conditionalVertex1;
	
}//end conditionalVertex1


//========== conditionalVertex2 ================================================
//
// Purpose:		
//
//==============================================================================
- (Point3) conditionalVertex2
{
	return conditionalVertex2;
	
}//end conditionalVertex2


//========== setconditionalVertex1: ============================================
//
// Purpose:		
//
//==============================================================================
-(void) setConditionalVertex1:(Point3)newVertex
{
	conditionalVertex1 = newVertex;
	
}//end setconditionalVertex1:


//========== setconditionalVertex2: ============================================
//
// Purpose:		
//
//==============================================================================
-(void) setConditionalVertex2:(Point3)newVertex
{
	conditionalVertex2 = newVertex;
	
}//end setconditionalVertex2:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== moveBy: ===========================================================
//
// Purpose:		Moves the receiver in the specified direction.
//
//==============================================================================
- (void) moveBy:(Vector3)moveVector
{
	//I don't know if this makes any sense.
	conditionalVertex1.x += moveVector.x;
	conditionalVertex1.y += moveVector.y;
	conditionalVertex1.z += moveVector.z;
	
	conditionalVertex2.x += moveVector.x;
	conditionalVertex2.y += moveVector.y;
	conditionalVertex2.z += moveVector.z;
	
}//end moveBy:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
//
// Purpose:		Appends the directive into the appropriate container. 
//
//==============================================================================
- (void) flattenIntoLines:(NSMutableArray *)lines
				triangles:(NSMutableArray *)triangles
		   quadrilaterals:(NSMutableArray *)quadrilaterals
					other:(NSMutableArray *)everythingElse
			 currentColor:(LDrawColor *)parentColor
		 currentTransform:(Matrix4)transform
		  normalTransform:(Matrix3)normalTransform
				recursive:(BOOL)recursive
{
	// Do nothing. Prevent LDrawLine (the superclass) from adding this object to 
	// the list! 
	
	// Conditional lines are not really my friend, so I'm dumping them all.
	
}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setConditionalVertex2:[self conditionalVertex2]];
	[[undoManager prepareWithInvocationTarget:self] setConditionalVertex1:[self conditionalVertex1]];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAttributesConditionalLine", nil)];
	
}//end registerUndoActions:


@end
