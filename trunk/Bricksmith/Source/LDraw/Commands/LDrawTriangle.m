//==============================================================================
//
// File:		LDrawTriangle.m
//
// Purpose:		Triangle command.
//				Draws a filled triangle between three points.
//
//				Line format:
//				3 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x1, y1, z1 is the position of the first point
//				* x2, y2, z2 is the position of the second point
//				* x3, y3, z3 is the position of the third point 
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawTriangle.h"

#import OPEN_GL_HEADER
#import <string.h>

#import "LDrawColor.h"
#import "LDrawDragHandle.h"
#import "LDrawStep.h"
#import "LDrawUtilities.h"


@implementation LDrawTriangle

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Returns a triangle initialized from line of LDraw code beginning 
//				at the given range. 
//
//				directive should have the format:
//
//				3 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString    *workingLine    = [lines objectAtIndex:range.location];
	NSString    *parsedField    = nil;
	Point3      workingVertex   = ZeroPoint3;
	LDrawColor  *parsedColor    = nil;
	
	self = [super initWithLines:lines inRange:range parentGroup:parentGroup];
	
	//A malformed part could easily cause a string indexing error, which would 
	// raise an exception. We don't want this to happen here.
	@try
	{
		//Read in the line code and advance past it.
		parsedField = [LDrawUtilities readNextField:  workingLine
										  remainder: &workingLine ];
		//Only attempt to create the part if this is a valid line.
		if([parsedField integerValue] == 3)
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
			
			//Read Vertex 3.
			// (x3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.x = [parsedField floatValue];
			// (y3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.y = [parsedField floatValue];
			// (z3)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			workingVertex.z = [parsedField floatValue];
			
			[self setVertex3:workingVertex];
		}
		else
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad triangle syntax" userInfo:nil];
	}
	@catch(NSException *exception)
	{
		NSLog(@"the triangle primitive %@ was fatally invalid", [lines objectAtIndex:range.location]);
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
	
	self = [super initWithCoder:decoder];
	
	//Decoding structures is a bit messy.
	temporary = [decoder decodeBytesForKey:@"vertex1" returnedLength:NULL];
	memcpy(&vertex1, temporary, sizeof(Point3));
	
	temporary = [decoder decodeBytesForKey:@"vertex2" returnedLength:NULL];
	memcpy(&vertex2, temporary, sizeof(Point3));
	
	temporary = [decoder decodeBytesForKey:@"vertex3" returnedLength:NULL];
	memcpy(&vertex3, temporary, sizeof(Point3));
	
	temporary = [decoder decodeBytesForKey:@"normal" returnedLength:NULL];
	memcpy(&normal, temporary, sizeof(Vector3));
	
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
	
	[encoder encodeBytes:(void *)&vertex1 length:sizeof(Point3) forKey:@"vertex1"];
	[encoder encodeBytes:(void *)&vertex2 length:sizeof(Point3) forKey:@"vertex2"];
	[encoder encodeBytes:(void *)&vertex3 length:sizeof(Point3) forKey:@"vertex3"];
	[encoder encodeBytes:(void *)&normal  length:sizeof(Vector3) forKey:@"normal"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawTriangle *copied = (LDrawTriangle *)[super copyWithZone:zone];
	
	[copied setVertex1:[self vertex1]];
	[copied setVertex2:[self vertex2]];
	[copied setVertex3:[self vertex3]];
	
	return copied;
	
}//end copyWithZone:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== drawElement:viewScale:withColor: ==================================
//
// Purpose:		Draws the graphic of the element represented. This call is a 
//				subroutine of -draw: in LDrawDrawableElement.
//
//==============================================================================
- (void) drawElement:(NSUInteger)optionsMask viewScale:(float)scaleFactor withColor:(LDrawColor *)drawingColor
{
	if(self->dragHandles)
	{
		for(LDrawDragHandle *handle in self->dragHandles)
		{
			[handle draw:optionsMask viewScale:scaleFactor parentColor:drawingColor];
		}
	}

}//end drawElement:parentColor:


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Tests the directive and any of its children for intersections 
//				between the pickRay and the directive's drawn content. 
//
//==============================================================================
- (void) hitTest:(Ray3)pickRay
	   transform:(Matrix4)transform
	   viewScale:(float)scaleFactor
	  boundsOnly:(BOOL)boundsOnly
	creditObject:(id)creditObject
			hits:(NSMutableDictionary *)hits
{
	if(self->hidden == NO)
	{
		Vector3 worldVertex1    = V3MulPointByProjMatrix(self->vertex1, transform);
		Vector3 worldVertex2    = V3MulPointByProjMatrix(self->vertex2, transform);
		Vector3 worldVertex3    = V3MulPointByProjMatrix(self->vertex3, transform);
		float   intersectDepth  = 0;
		bool    intersects      = false;
		
		intersects = V3RayIntersectsTriangle(pickRay,
											 worldVertex1, worldVertex2, worldVertex3,
											 &intersectDepth, NULL);
		if(intersects)
		{
			[LDrawUtilities registerHitForObject:self depth:intersectDepth creditObject:creditObject hits:hits];
		}

		if(self->dragHandles)
		{
			for(LDrawDragHandle *handle in self->dragHandles)
			{
				[handle hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:nil hits:hits];
			}
		}
	}
}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//				Line format:
//				3 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 
//
//==============================================================================
- (NSString *) write
{
	return [NSString stringWithFormat:
				@"3 %@ %@ %@ %@ %@ %@ %@ %@ %@ %@",
				[LDrawUtilities outputStringForColor:self->color],
				
				[LDrawUtilities outputStringForFloat:vertex1.x],
				[LDrawUtilities outputStringForFloat:vertex1.y],
				[LDrawUtilities outputStringForFloat:vertex1.z],
				
				[LDrawUtilities outputStringForFloat:vertex2.x],
				[LDrawUtilities outputStringForFloat:vertex2.y],
				[LDrawUtilities outputStringForFloat:vertex2.z],
				
				[LDrawUtilities outputStringForFloat:vertex3.x],
				[LDrawUtilities outputStringForFloat:vertex3.y],
				[LDrawUtilities outputStringForFloat:vertex3.z]
		
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
	GLfloat components[4]   = {};
	int     vertexCount     = 0;
	
	[drawingColor getColorRGBA:components];
	
	if(wireframe == NO)
	{
		memcpy(&vertexBuffer[0].position, &vertex1,    sizeof(Point3));
		memcpy(&vertexBuffer[0].normal,   &normal,     sizeof(Point3));
		memcpy(&vertexBuffer[0].color,    components,  sizeof(GLfloat)*4);
		
		memcpy(&vertexBuffer[1].position, &vertex2,    sizeof(Point3));
		memcpy(&vertexBuffer[1].normal,   &normal,     sizeof(Point3));
		memcpy(&vertexBuffer[1].color,    components,  sizeof(GLfloat)*4);
		
		memcpy(&vertexBuffer[2].position, &vertex3,    sizeof(Point3));
		memcpy(&vertexBuffer[2].normal,   &normal,     sizeof(Point3));
		memcpy(&vertexBuffer[2].color,    components,  sizeof(GLfloat)*4);
		
		vertexCount = 3;
	}
	else
	{
		// edge1
		memcpy(&vertexBuffer[0].position, &vertex1,		sizeof(Point3));
		memcpy(&vertexBuffer[0].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[0].color,    components,	sizeof(GLfloat)*4);
		
		memcpy(&vertexBuffer[1].position, &vertex2,		sizeof(Point3));
		memcpy(&vertexBuffer[1].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[1].color,    components,	sizeof(GLfloat)*4);
		
		// edge2
		memcpy(&vertexBuffer[2].position, &vertex2,		sizeof(Point3));
		memcpy(&vertexBuffer[2].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[2].color,    components,	sizeof(GLfloat)*4);
		
		memcpy(&vertexBuffer[3].position, &vertex3,		sizeof(Point3));
		memcpy(&vertexBuffer[3].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[3].color,    components,	sizeof(GLfloat)*4);
		
		// edge3
		memcpy(&vertexBuffer[4].position, &vertex3,		sizeof(Point3));
		memcpy(&vertexBuffer[4].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[4].color,    components,	sizeof(GLfloat)*4);
		
		memcpy(&vertexBuffer[5].position, &vertex1,		sizeof(Point3));
		memcpy(&vertexBuffer[5].normal,   &normal,		sizeof(Point3));
		memcpy(&vertexBuffer[5].color,    components,	sizeof(GLfloat)*4);
		
		vertexCount = 6;
	}
	
	return vertexBuffer + vertexCount;
	
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
	return NSLocalizedString(@"Triangle", nil);
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"Triangle";
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionTriangle";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== boundingBox3 ======================================================
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains this object.
//
//==============================================================================
- (Box3) boundingBox3
{
	Box3 bounds;
	
	//Compare first two points.
	bounds = V3BoundsFromPoints(vertex1, vertex2);

	//Now toss the third vertex into the mix.
	bounds = V3UnionBoxAndPoint(bounds, vertex3);
	
	return bounds;
	
}//end boundingBox3


//========== position ==========================================================
//
// Purpose:		Returns some position for the element. This is used by 
//				drag-and-drop. This is not necessarily human-usable information.
//
//==============================================================================
- (Point3) position
{
	return self->vertex1;
	
}//end position


//========== vertex1 ===========================================================
//==============================================================================
- (Point3) vertex1
{
	return self->vertex1;
	
}//end vertex1


//========== vertex2 ===========================================================
//==============================================================================
- (Point3) vertex2
{
	return self->vertex2;
	
}//end vertex2


//========== vertex3 ===========================================================
//==============================================================================
- (Point3) vertex3
{
	return self->vertex3;
	
}//end vertex3


#pragma mark -

//========== setSelected: ======================================================
//
// Purpose:		Somebody make this a protocol method.
//
//==============================================================================
- (void) setSelected:(BOOL)flag
{
	[super setSelected:flag];
	
	if(flag == YES)
	{
		LDrawDragHandle *handle1 = [[[LDrawDragHandle alloc] initWithTag:1 position:self->vertex1] autorelease];
		LDrawDragHandle *handle2 = [[[LDrawDragHandle alloc] initWithTag:2 position:self->vertex2] autorelease];
		LDrawDragHandle *handle3 = [[[LDrawDragHandle alloc] initWithTag:3 position:self->vertex3] autorelease];
		
		[handle1 setTarget:self];
		[handle2 setTarget:self];
		[handle3 setTarget:self];

		[handle1 setAction:@selector(dragHandleChanged:)];
		[handle2 setAction:@selector(dragHandleChanged:)];
		[handle3 setAction:@selector(dragHandleChanged:)];
		
		self->dragHandles = [[NSArray alloc] initWithObjects:handle1, handle2, handle3, nil];
	}
	else
	{
		[self->dragHandles release];
		self->dragHandles = nil;
	}

}//end setSelected:


//========== setVertex1: =======================================================
//
// Purpose:		Sets the triangle's first vertex.
//
//==============================================================================
-(void) setVertex1:(Point3)newVertex
{
	self->vertex1 = newVertex;
	[self recomputeNormal];
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:0] setPosition:newVertex updateTarget:NO];
	}
	
}//end setVertex1:


//========== setVertex2: =======================================================
//
// Purpose:		Sets the triangle's second vertex.
//
//==============================================================================
-(void) setVertex2:(Point3)newVertex
{
	self->vertex2 = newVertex;
	[self recomputeNormal];
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:1] setPosition:newVertex updateTarget:NO];
	}
	
}//end setVertex2:


//========== setVertex3: =======================================================
//
// Purpose:		Sets the triangle's last vertex.
//
//==============================================================================
-(void) setVertex3:(Point3)newVertex
{
	self->vertex3 = newVertex;
	[self recomputeNormal];
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:2] setPosition:newVertex updateTarget:NO];
	}
	
}//end setVertex3:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== dragHandleChanged: ================================================
//
// Purpose:		One of the drag handles on our vertexes has changed.
//
//==============================================================================
- (void) dragHandleChanged:(id)sender
{
	LDrawDragHandle *handle         = (LDrawDragHandle *)sender;
	Point3          newPosition     = [handle position];
	NSInteger       vertexNumber    = [handle tag];
	
	switch(vertexNumber)
	{
		case 1: [self setVertex1:newPosition]; break;
		case 2: [self setVertex2:newPosition]; break;
		case 3: [self setVertex3:newPosition]; break;
	}
}//end dragHandleChanged:


//========== moveBy: ===========================================================
//
// Purpose:		Moves the receiver in the specified direction.
//
//==============================================================================
- (void) moveBy:(Vector3)moveVector
{
	Point3 newVertex1 = V3Add(self->vertex1, moveVector);
	Point3 newVertex2 = V3Add(self->vertex2, moveVector);
	Point3 newVertex3 = V3Add(self->vertex3, moveVector);
	
	[self setVertex1:newVertex1];
	[self setVertex2:newVertex2];
	[self setVertex3:newVertex3];
	
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
	[super flattenIntoLines:lines
				  triangles:triangles
			 quadrilaterals:quadrilaterals
					  other:everythingElse
			   currentColor:parentColor
		   currentTransform:transform
			normalTransform:normalTransform
				  recursive:recursive];
	
	self->vertex1   = V3MulPointByProjMatrix(self->vertex1, transform);
	self->vertex2   = V3MulPointByProjMatrix(self->vertex2, transform);
	self->vertex3   = V3MulPointByProjMatrix(self->vertex3, transform);
	
	self->normal    = V3MulPointByMatrix(self->normal, normalTransform);
	
	[triangles addObject:self];
	
}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


//========== recomputeNormal ===================================================
//
// Purpose:		Finds the normal vector for this surface.
//
//==============================================================================
- (void) recomputeNormal
{
	Vector3 vector1, vector2;
	
	vector1 = V3Sub(self->vertex2, self->vertex1);
	vector2 = V3Sub(self->vertex3, self->vertex1);
	
	self->normal = V3Cross(vector1, vector2);
	
}//end recomputeNormal


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{	
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setVertex3:[self vertex3]];
	[[undoManager prepareWithInvocationTarget:self] setVertex2:[self vertex2]];
	[[undoManager prepareWithInvocationTarget:self] setVertex1:[self vertex1]];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAttributesTriangle", nil)];
	
}//end registerUndoActions:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Taking a dirt nap.
//
//==============================================================================
- (void) dealloc
{
	[dragHandles release];
	
	[super dealloc];
}


@end

