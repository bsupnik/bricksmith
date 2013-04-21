//==============================================================================
//
// File:		LDrawPart.m
//
// Purpose:		Part command.
//				Inserts a part defined in another LDraw file.
//
//				Line format:
//				1 colour x y z a b c d e f g h i part.dat 
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x, y, z is the position of the part
//				* a - i are orientation & scaling parameters
//				* part.dat is the filename of the included file 
//
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawPart.h"
#import "MacLDraw.h"
#import <math.h>
#import <string.h>
#import "LDrawColor.h"
#import "LDrawFile.h"
#import "LDrawModel.h"
#import "LDrawStep.h"
#import "LDrawUtilities.h"
#import "LDrawVertexes.h"
#import "PartLibrary.h"
#import "PartReport.h"
#import "ModelManager.h"

// This is experimental for now: one way to draw the gaps between lego bricks 
// without using lines is to simply shrink the entire brick by a tiny amount,
// leaving a small gap between bricks.  (This is based on the seam-shrink code
// in Travis' LDView.)
//
// The theory is that the look of a seam is very lighting-direction dependent,
// e.g. a seam may be bright or dark depending on how the edge of the brick 
// faces the light source.  Shrunk seams sort of approximate this by exposing
// tiny amounts of the tops of bricks, etc.
//
// Normally defined to 0 for production use.  

#define SHRINK_SEAMS 0
#define SHRINK_AMOUNT 0.125		// in LDU

@implementation LDrawPart

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Creates an empty part.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	[self setDisplayName:@""];
    [self setIconName:@"Brick"];
	[self setTransformComponents:IdentityComponents];
	//	drawLock = [[NSLock alloc] init];
	
	return self;
	
}//end init


//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Returns the LDraw directive based on lineFromFile, a single line 
//				of LDraw code from a file.
//
//				Line format:
//				1 colour x y z a b c d e f g h i part.dat 
//
//				Matrix format:
//				+-       -+
//				| a d g 0 |
//				| b e h 0 |
//				| c f i 0 |
//				| x y z 1 |
//				+-       -+
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString    *workingLine    = [lines objectAtIndex:range.location];
	NSString    *parsedField    = nil;
	Matrix4     transformation  = IdentityMatrix4;
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
		if([parsedField integerValue] == 1)
		{
			//Read in the color code.
			// (color)
			parsedField = [LDrawUtilities readNextField:  workingLine
											  remainder: &workingLine ];
			parsedColor = [LDrawUtilities parseColorFromField:parsedField];
			[self setLDrawColor:parsedColor];
			
			//Read position.
			// (x)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[3][0] = [parsedField floatValue];
			// (y)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[3][1] = [parsedField floatValue];
			// (z)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[3][2] = [parsedField floatValue];
			
			
			//Read Transformation X.
			// (a)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[0][0] = [parsedField floatValue];
			// (b)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[1][0] = [parsedField floatValue];
			// (c)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[2][0] = [parsedField floatValue];
			
			
			//Read Transformation Y.
			// (d)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[0][1] = [parsedField floatValue];
			// (e)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[1][1] = [parsedField floatValue];
			// (f)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[2][1] = [parsedField floatValue];
			
			
			//Read Transformation Z.
			// (g)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[0][2] = [parsedField floatValue];
			// (h)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[1][2] = [parsedField floatValue];
			// (i)
			parsedField = [LDrawUtilities readNextField:workingLine  remainder: &workingLine ];
			transformation.element[2][2] = [parsedField floatValue];
			
			//finish off the corner of the matrix.
			transformation.element[3][3] = 1;
			
			[self setTransformationMatrix:&transformation];
			
			//Read Part Name
			// (part.dat) -- It can have spaces (for MPD models), so we just use the whole 
			// rest of the line.
			[self setDisplayName:[workingLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
						   parse:YES
						 inGroup:parentGroup];
			
			// Debug check: full part resolution isn't thread-safe so make sure we haven't run it by accident here!
			assert(cacheType == PartTypeUnresolved);
		}
		else
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad part syntax" userInfo:nil];
	}
	@catch(NSException *exception)
	{
		NSLog(@"the part %@ was fatally invalid", [lines objectAtIndex:range.location]);
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
- (id)initWithCoder:(NSCoder *)decoder
{
	const uint8_t *temporary = NULL; //pointer to a temporary buffer returned by the decoder.
	
	self		= [super initWithCoder:decoder];
	
	[self setDisplayName:[decoder decodeObjectForKey:@"displayName"]];

    // Parts may have icons other than the standard "Brick", i.e. LSynth constraints
    [self setIconName:[decoder decodeObjectForKey:@"iconName"]];

	//Decoding structures is a bit messy.
	temporary	= [decoder decodeBytesForKey:@"glTransformation" returnedLength:NULL];
	memcpy(glTransformation, temporary, sizeof(GLfloat)*16 );
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeObject:displayName	forKey:@"displayName"];

    // Parts may have icons other than the standard "Brick", i.e. LSynth constraints
	[encoder encodeObject:[self iconName] forKey:@"iconName"];
	[encoder encodeBytes:(void *)glTransformation
				  length:sizeof(GLfloat)*16
				  forKey:@"glTransformation"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawPart	*copied			= (LDrawPart *)[super copyWithZone:zone];
	Matrix4		 transformation	= [self transformationMatrix];
	
	[copied setDisplayName:[self displayName]];
	[copied setTransformationMatrix:&transformation];
	
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
	LDrawDirective  *drawable       = nil;
	BOOL            drawBoundsOnly  = ((optionsMask & DRAW_BOUNDS_ONLY) != 0);
	
	// If the part is selected, we need to give some indication. We do this 
	// by drawing it as a wireframe instead of a filled color. This setting 
	// also conveniently applies to all referenced parts herein. 
	if([self isSelected] == YES)
	{
#if (USE_AUTOMATIC_WIREFRAMES)
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
#else
		optionsMask = optionsMask | DRAW_WIREFRAME;
#endif
	}

	// Multithreading finally works with one display list per displayed part 
	// AND mutexes around the glCallList. But the mutex contention causes a 
	// 50% increase in drawing time. Gah! 
	
	glPushMatrix();
	{
		glMultMatrixf(glTransformation);
		
		[self resolvePart];

		drawable = cacheDrawable;

		if (cacheType == PartTypeLibrary && cacheDrawable == nil)
		{
			// Parts assigned to LDrawCurrentColor may get drawn in many 
			// different colors in one draw, so we can't cache their 
			// optimized drawable. We have to retrieve their optimized 
			// drawable on-the-fly. 
			
			// Parts that have a SPECIFIC color have been linked DIRECTLY to 
			// their specific colored VBO during -optimizeOpenGL. 
			
			drawable = [[PartLibrary sharedPartLibrary] optimizedDrawableForPart:self color:drawingColor];
		}
		
		if(drawBoundsOnly == NO)
		{
			[drawable draw:optionsMask viewScale:scaleFactor parentColor:drawingColor];
		}
		else
		{
			[self drawBoundsWithColor:drawingColor];
		}
	}
	glPopMatrix();

	// Done drawing a selected part? Then switch back to normal filled drawing. 
	if([self isSelected] == YES)
	{
#if (USE_AUTOMATIC_WIREFRAMES)
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
#endif
	}

}//end drawElement:parentColor:


//========== drawSelf: ===========================================================
//
// Purpose:		Draw this directive and its subdirectives by calling APIs on 
//				the passed in renderer, then calling drawSelf on children.
//
// Notes:		Parts draw by pushing the matrix and color instancing info they
//				contain into the renderer, then passing drawSelf to the model
//				backing the part, if it exists.
//
//================================================================================
- (void) drawSelf:(id<LDrawRenderer>)renderer
{
	if(self->hidden == NO)
	{
		[self resolvePart];

		if(cacheModel)
		{
			if([self->color colorCode] != LDrawCurrentColor)
			{
				// Old rendering code did not actually support
				// pushing the edge color as the new current
				// color - and it's probably against spec.  But
				// it's not really the place of drawSelf to go
				// slappign wrists, so pass it to the render,
				// which actually DOES know how to get this case
				// right.
				if([self->color colorCode] == LDrawEdgeColor)	
					[renderer pushColor:LDrawRenderComplimentColor];
				else
				{
					GLfloat c[4];
					[self->color getColorRGBA:c];				
					[renderer pushColor:c];
				}
			}
			
			if([self isSelected] == YES)
				[renderer pushWireFrame];
			
			#if SHRINK_SEAMS
			
			Box3 bbox = [cacheModel boundingBox3];
			int i;
			GLfloat dim[3] = {	bbox.max.x - bbox.min.x,
								bbox.max.y - bbox.min.y,
								bbox.max.z - bbox.min.z };

			GLfloat ctr[3] = {	(bbox.max.x + bbox.min.x) * 0.5f,
								(bbox.max.y + bbox.min.y) * 0.5f,
								(bbox.max.z + bbox.min.z) * 0.5f };

			GLfloat	shrinkMatrix[16] = { 0 };
			shrinkMatrix[15] = 1.0f;
			
			for(i = 0; i < 3; ++i)
			{
				if(dim[i] > SHRINK_AMOUNT)
				{
					shrinkMatrix[i*4+i] = 1.0f - SHRINK_AMOUNT / dim[i];
					shrinkMatrix[12 + i] = SHRINK_AMOUNT / dim[i] * ctr[i];
				} 
				else
				{
					shrinkMatrix[i*4+i] = 1.0f;
				}
			}

			[renderer pushMatrix:glTransformation];			
			[renderer pushMatrix:shrinkMatrix];
			
			#else
			
			[renderer pushMatrix:glTransformation];
			#endif
			
			[cacheModel drawSelf:renderer];

			[renderer popMatrix];
			#if SHRINK_SEAMS
			[renderer popMatrix];
			#endif
			if([self->color colorCode] != LDrawCurrentColor)
				[renderer popColor];
				
			if([self isSelected] == YES)
				[renderer popWireFrame];
				
		}	
	}
}//end drawSelf:


//========== drawBoundsWithColor: ==============================================
//
// Purpose:		Draws the part's bounds as a solid box. Nonrecursive.
//
//==============================================================================
- (void) drawBoundsWithColor:(LDrawColor *)drawingColor
{
	//Pull the bounds directly from the model; we can't use the part's because 
	// it mangles them based on rotation. In this case, we want to do a raw 
	// draw and let the model matrix transform our drawing appropriately.
	[self resolvePart];
	LDrawModel	*modelToDraw	= cacheModel;
	
	//If the model can't be found, we can't draw good bounds for it!
	if(modelToDraw != nil)
	{
		LDrawVertexes   *unitCube   = [LDrawUtilities boundingCube];
		Box3            bounds      = [modelToDraw boundingBox3];
		Tuple3          extents     = V3Sub(bounds.max, bounds.min);
		
		// Expand and position the unit cube to match the model
		glTranslatef(bounds.min.x, bounds.min.y, bounds.min.z);
		glScalef(extents.x, extents.y, extents.z);
		
		[unitCube draw:DRAW_NO_OPTIONS viewScale:1.0 parentColor:drawingColor];
	}
}//end drawBounds


//========== debugDrawboundingBox ==============================================
//
// Purpose:		Draw a translucent visualization of our bounding box to test
//				bounding box caching.
//
//==============================================================================
- (void) debugDrawboundingBox
{
	[self resolvePart];
	LDrawModel	*modelToDraw	= cacheModel;
	
	//If the model can't be found, we can't draw good bounds for it!
	if(modelToDraw != nil)
	{
		glPushMatrix();
		glMultMatrixf(glTransformation);
		[modelToDraw debugDrawboundingBox];
		glPopMatrix();
	}
	
	[super debugDrawboundingBox];	
}//end debugDrawboundingBox


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Hit-test the geometry.
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
		Matrix4     partTransform       = [self transformationMatrix];
		Matrix4     combinedTransform   = Matrix4Multiply(partTransform, transform);
		
		// Credit all subgeometry to ourselves (unless we are already a child part)
		if(creditObject == nil)
		{
			creditObject = self;
		}

		[self resolvePart];
		// If we are doing a bounds test, for now get the model, not the VBO - VBO bounds test does not yet exist
		// (which is not so good).  For parent-color parts we HAVE to get the model - there is no VBO!
		LDrawDirective		*modelToDraw        = (cacheDrawable == nil || boundsOnly) ? cacheModel : cacheDrawable;
		
		if(modelToDraw)
		{
			if(boundsOnly == NO)
			{			
				[modelToDraw hitTest:pickRay transform:combinedTransform viewScale:scaleFactor boundsOnly:NO creditObject:creditObject hits:hits];

			}
			else
			{
				LDrawVertexes   *unitCube   = [LDrawUtilities boundingCube];
				Box3            bounds      = [modelToDraw boundingBox3];
				Tuple3          extents     = V3Sub(bounds.max, bounds.min);
				Matrix4	boxTransform = IdentityMatrix4;
				
				// Expand and position the unit cube to match the model
				boxTransform = Matrix4Scale(boxTransform, extents);
				boxTransform = Matrix4Translate(boxTransform, bounds.min);
				
				combinedTransform = Matrix4Multiply(boxTransform, combinedTransform);
				
				[unitCube hitTest:pickRay transform:combinedTransform viewScale:scaleFactor boundsOnly:NO creditObject:creditObject hits:hits];
			}
		}		
	}
}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
//
// Purpose:		Check for intersections with screen-space geometry.
//
//==============================================================================
- (BOOL)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	if(self->hidden == NO)
	{
		if(!VolumeCanIntersectBox(
							[self boundingBox3],
							transform,
							bounds))
		{
			return FALSE;
		}
	
	
		Matrix4     partTransform       = [self transformationMatrix];
		Matrix4     combinedTransform   = Matrix4Multiply(partTransform, transform);
		LDrawDirective  *modelToDraw        = nil;
		
		// Credit all subgeometry to ourselves (unless we are already a child part)
		if(creditObject == nil)
		{
			creditObject = self;
		}
		
		[self resolvePart];
		modelToDraw	= cacheModel;
		
		if(boundsOnly == NO)
		{
			if([modelToDraw boxTest:bounds transform:combinedTransform boundsOnly:NO creditObject:creditObject hits:hits])
				if(creditObject != nil)
					return TRUE;
		}
		else
		{
			// Hit test the bounding cube
			LDrawVertexes   *unitCube   = [LDrawUtilities boundingCube];
			Box3            bounds_3d      = [modelToDraw boundingBox3];
			Tuple3          extents     = V3Sub(bounds_3d.max, bounds_3d.min);
			Matrix4	boxTransform = IdentityMatrix4;
			
			// Expand and position the unit cube to match the model
			boxTransform = Matrix4Scale(boxTransform, extents);
			boxTransform = Matrix4Translate(boxTransform, bounds_3d.min);
			
			combinedTransform = Matrix4Multiply(boxTransform, combinedTransform);
			
			if([unitCube boxTest:bounds transform:combinedTransform boundsOnly:NO creditObject:creditObject hits:hits])
				if(creditObject != nil)
					return TRUE;
		}
	}
	return FALSE;
}//end boxTest:transform:boundsOnly:creditObject:hits:


//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
//
// Purpose:		depthTest finds the closest primitive (in screen space) 
//				overlapping a given point, as well as its device coordinate
//				depth.
//
//==============================================================================
- (void)	depthTest:(Point2) pt 
				inBox:(Box2)bounds 
			transform:(Matrix4)transform 
		 creditObject:(id)creditObject 
		   bestObject:(id *)bestObject 
			bestDepth:(float *)bestDepth
{
	if(self->hidden == NO)
	{
		if(!VolumeCanIntersectPoint([self boundingBox3], transform, bounds, *bestDepth)) 
			return;

		Matrix4     partTransform       = [self transformationMatrix];
		Matrix4     combinedTransform   = Matrix4Multiply(partTransform, transform);
		LDrawDirective  *modelToDraw        = nil;
		
		// Credit all subgeometry to ourselves (unless we are already a child part)
		if(creditObject == nil)
		{
			creditObject = self;
		}
		
		[self resolvePart];
		modelToDraw	= cacheModel;
		
		[modelToDraw depthTest:pt inBox:bounds transform:combinedTransform creditObject:creditObject bestObject:bestObject bestDepth:bestDepth];
	}
}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//
//				Line format:
//				1 colour x y z a b c d e f g h i part.dat 
//
//				Matrix format:
//				+-       -+
//				| a d g 0 |
//				| b e h 0 |
//				| c f i 0 |
//				| x y z 1 |
//				+-       -+
//
//==============================================================================
- (NSString *) write
{
	Matrix4 transformation = [self transformationMatrix];

	return [NSString stringWithFormat:
				@"1 %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@",
				[LDrawUtilities outputStringForColor:self->color],
				
				[LDrawUtilities outputStringForFloat:transformation.element[3][0]], //position.x,			(x)
				[LDrawUtilities outputStringForFloat:transformation.element[3][1]], //position.y,			(y)
				[LDrawUtilities outputStringForFloat:transformation.element[3][2]], //position.z,			(z)
				
				[LDrawUtilities outputStringForFloat:transformation.element[0][0]], //transformationX.x,	(a)
				[LDrawUtilities outputStringForFloat:transformation.element[1][0]], //transformationX.y,	(b)
				[LDrawUtilities outputStringForFloat:transformation.element[2][0]], //transformationX.z,	(c)
				
				[LDrawUtilities outputStringForFloat:transformation.element[0][1]], //transformationY.x,	(d)
				[LDrawUtilities outputStringForFloat:transformation.element[1][1]], //transformationY.y,	(e)
				[LDrawUtilities outputStringForFloat:transformation.element[2][1]], //transformationY.z,	(f)
				
				[LDrawUtilities outputStringForFloat:transformation.element[0][2]], //transformationZ.x,	(g)
				[LDrawUtilities outputStringForFloat:transformation.element[1][2]], //transformationZ.y,	(h)
				[LDrawUtilities outputStringForFloat:transformation.element[2][2]], //transformationZ.z,	(i)
				
				displayName
			];
}//end write

#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//				Here we want the part name displayed.
//
//==============================================================================
- (NSString *) browsingDescription
{
	return [[PartLibrary sharedPartLibrary] descriptionForPart:self];
	
}//end browsingDescription

//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionPart";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== boundingBox3 ======================================================
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains this object. Returns InvalidBox if the part 
//				cannot be found.
//
//==============================================================================
- (Box3) boundingBox3
{
	if([self revalCache:CacheFlagBounds] == CacheFlagBounds)
	{
		[self resolvePart];
		LDrawModel	*modelToDraw	= cacheModel;
		
		Box3        bounds              = InvalidBox;
					cacheBounds			= InvalidBox;
		Matrix4     transformation      = [self transformationMatrix];
		
		// We need to have an actual model here. Blithely calling boundingBox3 will 
		// result in most of our Box3 structure being garbage data!
		if(modelToDraw != nil && self->hidden == NO)
		{
			bounds = [modelToDraw boundingBox3];
			
			if(V3EqualBoxes(bounds, InvalidBox) == NO)
			{
				// Transform all the points of the bounding box to find the new 
				// minimum and maximum. 
				int     counter     = 0;
				Point3  vertices[8] = {	
										{bounds.min.x, bounds.min.y, bounds.min.z},
										{bounds.min.x, bounds.min.y, bounds.max.z},
										{bounds.min.x, bounds.max.y, bounds.max.z},
										{bounds.min.x, bounds.max.y, bounds.min.z},
										
										{bounds.max.x, bounds.min.y, bounds.min.z},
										{bounds.max.x, bounds.min.y, bounds.max.z},
										{bounds.max.x, bounds.max.y, bounds.max.z},
										{bounds.max.x, bounds.max.y, bounds.min.z},
									  };
				for(counter = 0; counter < 8; counter++)
				{
					vertices[counter] = V3MulPointByProjMatrix(vertices[counter], transformation);
					cacheBounds = V3UnionBoxAndPoint(cacheBounds, vertices[counter]);
				}
			}
		}
	}
	
	return cacheBounds;
	
}//end boundingBox3


//========== displayName =======================================================
//
// Purpose:		Returns the name of the part as the user typed it. This 
//				maintains the user's upper- and lower-case usage.
//
//==============================================================================
- (NSString *) displayName
{
	return displayName;
	
}//end displayName


//========== position ==========================================================
//
// Purpose:		Returns the coordinates at which the part is drawn.
//
// Notes:		This is purely a convenience method. The actual position is 
//				encoded in the transformation matrix. If you wish to set the 
//				position, you should set either the matrix or the Transformation 
//				Components.
//
//==============================================================================
- (Point3) position
{
	TransformComponents	components	= [self transformComponents];
	Point3				position	= components.translate;
	
	return position;
	
}//end position

/*
To work, this needs to multiply the modelViewGLMatrix by the part transform.

//========== projectedBoundingBoxWithModelView:projection:view: ================
//
// Purpose:		Returns the 2D projection (ignore the z) of the object's bounds.
//
//==============================================================================
- (Box3) projectedBoundingBoxWithModelView:(Matrix4)modelView
								projection:(Matrix4)projection
									  view:(Box2)viewport;
{
	LDrawModel  *modelToDraw    = [[PartLibrary sharedPartLibrary] modelForPart:self];
	Box3        projectedBounds = InvalidBox;
	
	projectedBounds = [modelToDraw projectedBoundingBoxWithModelView:modelViewGLMatrix
														  projection:projectionGLMatrix
																view:viewport];
	
	return projectedBounds;
	
}//end projectedBoundingBoxWithModelView:projection:view:
*/

//========== referenceName =====================================================
//
// Purpose:		Returns the name of the part. This is the filename where the 
//				part is found. Since Macintosh computers are case-insensitive, 
//				I have adopted lower-case as the standard for names.
//
//==============================================================================
- (NSString *) referenceName
{
	return referenceName;
	
}//end referenceName


//========== referencedMPDSubmodel =============================================
//
// Purpose:		Returns the MPD model to which this part refers, or nil if there 
//				is no submodel in this part's file which has the name this part 
//				specifies.
//
// Note:		This method is ONLY intended to be used for resolving MPD 
//				references. If you want to resolve the general reference, you 
//				should call -modelForPart: in the PartLibrary!
//
//==============================================================================
- (LDrawModel *) referencedMPDSubmodel
{
	LDrawModel	*model			= nil;
	LDrawFile	*enclosingFile	= [self enclosingFile];
	
	if(enclosingFile != nil)
		model = (LDrawModel *)[enclosingFile modelWithName:self->referenceName];
	
	//No can do if we get a reference back to ourselves. That would be 
	// an infinitely-recursing reference, which is bad!
	if(model == [[self enclosingStep] enclosingModel])
		model = nil;
	
	return model;
}//end referencedMPDSubmodel


//========== transformComponents ===============================================
//
// Purpose:		Returns the individual components of the transformation matrix 
//			    applied to this part. 
//
//==============================================================================
- (TransformComponents) transformComponents
{
	Matrix4				transformation	= [self transformationMatrix];
	TransformComponents	components		= IdentityComponents;
	
	//This is a pretty darn neat little function. I wish I could say I wrote it.
	// It will extract all the user-friendly components out of this nasty matrix.
	Matrix4DecomposeTransformation( transformation, &components );

	return components;
	
}//end transformComponents


//========== transformationMatrix ==============================================
//
// Purpose:		Returns a two-dimensional (row matrix) representation of the 
//				part's transformation matrix.
//
//																+-       -+
//				+-                           -+        +-     -+| a d g 0 |
//				|a d g 0 b e h c f i 0 x y z 1|  -->   |x y z 1|| b e h 0 |
//				+-                           -+        +-     -+| c f i 0 |
//																| x y z 1 |
//																+-       -+
//					  OpenGL Matrix Format                 LDraw Matrix
//				(flat column-major of transpose)              Format
//
//==============================================================================
- (Matrix4) transformationMatrix
{
	return Matrix4CreateFromGLMatrix4(glTransformation);
	
}//end transformationMatrix


#pragma mark -

//========== setEnclosingDirective: ============================================
//==============================================================================
- (void) setEnclosingDirective:(LDrawContainer *)newParent
{
	[self unresolvePart];
	[super setEnclosingDirective:newParent];
}


//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the color of this element.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *)newColor
{
	[super setLDrawColor:newColor];
	
	[self unresolvePart];
	[self invalCache:CacheFlagBounds];
	
}//end setLDrawColor:


//========== setDisplayName: ===================================================
//
// Purpose:		Updates the name of the part and attempts to load it into the 
//				part library. 
//
//==============================================================================
- (void) setDisplayName:(NSString *)newPartName
{
	[self setDisplayName:newPartName parse:YES inGroup:NULL];
}


//========== setDisplayName:parse:inGroup: =====================================
//
// Purpose:		Updates the name of the part. This is the filename where the 
//				part is found.
//
//				If shouldParse is YES, pre-loads the referenced part if 
//				possible. Pre-loading is very import in initial model loading, 
//				because it enables structual optimizations to be performed prior 
//				to OpenGL optimizations. It also results in a more honest load 
//				progress bar. 
//
// Notes:		References to LDraw/parts and LDraw/p are simply encoded as the 
//				file name. However, references to LDraw/parts/s are encoded as 
//				"s\partname.dat". The part library, meanwhile, must properly 
//				handle the s\ prefix.
//
//==============================================================================
- (void) setDisplayName:(NSString *)newPartName
				  parse:(BOOL)shouldParse
				inGroup:(dispatch_group_t)parentGroup
{
	NSString            *newReferenceName   = [newPartName lowercaseString];
	dispatch_group_t    parseGroup          = NULL;

	[newPartName retain];
	[displayName release];
	
	displayName = newPartName;
	
	[newReferenceName retain];
	[referenceName release];
	referenceName = newReferenceName;

	assert(parentGroup == NULL || cacheType == PartTypeUnresolved);
	
	[self unresolvePart];
	
	// Force the part library to parse the model this part will display. This 
	// pushes all parsing into the same operation, which improves loading time 
	// predictability and allows better potential threading optimization. 	
	//
	// Ben says: we _have_ to call this, even on MPD and peer models.  Since
	// we don't know what kind of thing we are, checking the cache type will
	// always return unresolved.  But I don't think I want to force-resolve 
	// here - resolving later prevents thrash.
	if(shouldParse == YES && newPartName != nil && [newPartName length] > 0)
	{
#if USE_BLOCKS
		// Create a parsing group if needed.
		if(parentGroup == NULL)
			parseGroup = dispatch_group_create();
		else
			parseGroup = parentGroup;
#endif
		[[PartLibrary sharedPartLibrary] loadModelForName:referenceName inGroup:parseGroup];
		
#if USE_BLOCKS
		if(parentGroup == NULL)
		{
			dispatch_group_wait(parseGroup, DISPATCH_TIME_FOREVER);
			dispatch_release(parseGroup);
		}
#endif	
	}
	
}//end setDisplayName:


//========== setTransformComponents: ===========================================
//
// Purpose:		Converts the given componets (rotation, scaling, etc.) into an 
//				internal transformation matrix represenation.
//
//==============================================================================
- (void) setTransformComponents:(TransformComponents)newComponents
{
	Matrix4 transformation = Matrix4CreateTransformation(&newComponents);
	
	[self setTransformationMatrix:&transformation];

}//end setTransformComponents:


//========== setTransformationMatrix: ==========================================
//
// Purpose:		Converts the row-major row-vector matrix into a flat column-
//				major column-vector matrix understood by OpenGL.
//
//
//			 +-       -+     +-       -++- -+
//	+-     -+| a d g 0 |     | a b c x || x |
//	|x y z 1|| b e h 0 |     | d e f y || y |     +-                           -+
//	+-     -+| c f i 0 | --> | g h i z || z | --> |a d g 0 b e h c f i 0 x y z 1|
//			 | x y z 1 |     | 0 0 0 1 || 1 |     +-                           -+
//			 +-       -+     +-       -++- -+
//		LDraw Matrix            Transpose               OpenGL Matrix Format
//		   Format                                 (flat column-major of transpose)
//  (also Matrix4 format)
//
//==============================================================================
- (void) setTransformationMatrix:(Matrix4 *)newMatrix
{
	[self invalCache:CacheFlagBounds];
	Matrix4GetGLMatrix4(*newMatrix, self->glTransformation);
	
}//end setTransformationMatrix


//========== setSelected: ======================================================
//
// Purpose:		Somebody make this a protocol method.
//
//==============================================================================
- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];

    // would like LDrawContainer to be a protocol.  In its absence...
    if ([[self enclosingDirective] respondsToSelector:@selector(setSubdirectiveSelected:)]) {
        [[self enclosingDirective] setSubdirectiveSelected:flag];
    }

}//end setSelected:


#pragma mark -
#pragma mark MOVEMENT
#pragma mark -

//========== displacementForNudge: =============================================
//
// Purpose:		Returns the amount by which the element wants to move, given a 
//				"nudge" in the specified direction. A "nudge" is generated by 
//				pressing the arrow keys. We scale this value so as to make 
//				nudging go by plate-heights vertically and brick widths 
//				horizontally.
//
//==============================================================================
- (Vector3) displacementForNudge:(Vector3)nudgeVector
{
	Matrix4 transformationMatrix	= IdentityMatrix4;
	Matrix4 inverseMatrix			= IdentityMatrix4;
	Vector4 worldNudge				= {0, 0, 0, 1};
	Vector4 brickNudge				= {0};
	
	//convert incoming 3D vector to 4D for our math:
	worldNudge.x = nudgeVector.x;
	worldNudge.y = nudgeVector.y;
	worldNudge.z = nudgeVector.z;
	
	//Figure out which direction we're asking to move the part itself.
	transformationMatrix	= [self transformationMatrix];
	inverseMatrix			= Matrix4Invert( transformationMatrix );
	inverseMatrix.element[3][0] = 0; //zero out the translation part, leaving only rotation etc.
	inverseMatrix.element[3][1] = 0;
	inverseMatrix.element[3][2] = 0;
	
	//See if this is a nudge along the brick's "up" direction. 
	// If so, the nudge needs to be a different magnitude, to compensate 
	// for the fact that Lego bricks are not square!
	brickNudge = V4MulPointByMatrix(worldNudge, inverseMatrix);
	if(fabs(brickNudge.y) > fabs(brickNudge.x) && 
	   fabs(brickNudge.y) > fabs(brickNudge.z) )
	{
		//The trouble is, we need to do different things for different 
		// scales. For instance, in medium mode, we probably want to 
		// move 1/2 stud horizontally but 1/3 stud vertically.
		//
		// But in coarse mode, we want to move 1 stud horizontally and 
		// vertically. These are different ratios! So I test for known 
		// numbers, and only apply modifications if they are recognized.
		
		if(fmod(nudgeVector.x, 20) == 0)
			nudgeVector.x *= 24.0 / 20.0;
		else if(fmod(nudgeVector.x, 10) == 0)
			nudgeVector.x *= 8.0 / 10.0;
		
		if(fmod(nudgeVector.y, 20) == 0)
			nudgeVector.y *= 24.0 / 20.0;
		else if(fmod(nudgeVector.y, 10) == 0)
			nudgeVector.y *= 8.0 / 10.0;
		
		if(fmod(nudgeVector.z, 20) == 0)
			nudgeVector.z *= 24.0 / 20.0;
		else if(fmod(nudgeVector.z, 10) == 0)
			nudgeVector.z *= 8.0 / 10.0;
	}

	
	//we now have a nudge based on the correct size: plates or bricks.
	return nudgeVector;
	
}//end displacementForNudge:


//========== componentsSnappedToGrid:minimumAngle: =============================
//
// Purpose:		Returns a copy of the part's current components, but snapped to 
//			    the grid. Kinda a weird legacy API. 
//
//==============================================================================
- (TransformComponents) componentsSnappedToGrid:(float) gridSpacing
								   minimumAngle:(float)degrees
{
	TransformComponents	components		= [self transformComponents];
	
	return [self components:components snappedToGrid:gridSpacing minimumAngle:degrees];
	
}//end componentsSnappedToGrid:minimumAngle:


//========== components:snappedToGrid:minimumAngle: ============================
//
// Purpose:		Aligns the given components to an imaginary grid along lines 
//			    separated by a distance of gridSpacing. This is done 
//			    intelligently based on the current orientation of the receiver: 
//			    if gridSpacing == 20, that is assumed to mean "1 stud," so the 
//			    y-axis (up) of the part will be aligned along a grid spacing of 
//			    24 (1 stud vertically). 
//
//				The part's rotation angles will be adjusted to multiples of the 
//				minimum angle specified.
//
// Parameters:	components	- transform to adjust.
//				gridSpacing	- the grid line interval along stud widths.
//				degrees		- angle granularity. Pass 0 to leave angle 
//							  unchanged. 
//
//==============================================================================
- (TransformComponents) components:(TransformComponents)components
					 snappedToGrid:(float) gridSpacing
					  minimumAngle:(float)degrees
{
	float	rotationRadians			= radians(degrees);
	
	Matrix4 transformationMatrix	= IdentityMatrix4;
	Vector4 yAxisOfPart				= {0, 1, 0, 1};
	Vector4 worldY					= {0, 0, 0, 1}; //yAxisOfPart converted to world coordinates
	Vector3 worldY3					= {0, 0, 0};
	float	gridSpacingYAxis		= 0.0;
	float	gridX					= 0.0;
	float	gridY					= 0.0;
	float	gridZ					= 0.0;
	
	//---------- Adjust position to grid ---------------------------------------

	//Figure out which direction the y-axis is facing in world coordinates:
	transformationMatrix = [self transformationMatrix];
	transformationMatrix.element[3][0] = 0; //zero out the translation part, leaving only rotation etc.
	transformationMatrix.element[3][1] = 0;
	transformationMatrix.element[3][2] = 0;
	worldY	= V4MulPointByMatrix(yAxisOfPart, transformationMatrix);
	
	worldY3	= V3FromV4(worldY);
	worldY3 = V3IsolateGreatestComponent(worldY3);
	worldY3	= V3Normalize(worldY3);
	
	//Get the adjusted grid spacing along the y direction. Remember that Lego 
	// bricks are not cubical, so the grid along the brick's y-axis should be 
	// spaced differently from the grid along its other sides.
	gridSpacingYAxis = gridSpacing;
	
	if(fmod(gridSpacing, 20) == 0)
		gridSpacingYAxis *= 24.0 / 20.0;
	
	else if(fmod(gridSpacing, 10) == 0)
		gridSpacingYAxis *= 8.0 / 10.0;
		
	//The actual grid spacing, in world coordinates. We will adjust the approrpiate 
	// x, y, or z based on which one the part's y-axis is aligned.
	gridX = gridSpacing;
	gridY = gridSpacing;
	gridZ = gridSpacing;

	//Find the direction of the part's Y-axis, and change its grid.
	if(worldY3.x != 0)
		gridX = gridSpacingYAxis;
	
	if(worldY3.y != 0)
		gridY = gridSpacingYAxis;
	
	if(worldY3.z != 0)
		gridZ = gridSpacingYAxis;
	
	// Snap to the Grid!
	// Figure the closest grid line and bump the part to it.
	// Logically, this is a rounding operation with a granularity of the grid 
	// size. So all we need to do is normalize, round, then expand back to the 
	// original size. 
	
	components.translate.x = roundf(components.translate.x/gridX) * gridX;
	components.translate.y = roundf(components.translate.y/gridY) * gridY;
	components.translate.z = roundf(components.translate.z/gridZ) * gridZ;
	

	//---------- Snap angles ---------------------------------------------------
	
	if(rotationRadians != 0)
	{
		components.rotate.x = roundf(components.rotate.x/rotationRadians) * rotationRadians;
		components.rotate.y = roundf(components.rotate.y/rotationRadians) * rotationRadians;
		components.rotate.z = roundf(components.rotate.z/rotationRadians) * rotationRadians;
	}
	
	//round-off errors here? Potential for trouble.
	return components;
	
}//end components:snappedToGrid:minimumAngle:


//========== moveBy: ===========================================================
//
// Purpose:		Moves the receiver in the specified direction.
//
//==============================================================================
- (void) moveBy:(Vector3)moveVector
{	
	Matrix4 transformationMatrix	= [self transformationMatrix];

	//I NEED to modify the matrix itself here. Some parts have funky, fragile 
	// rotation values, and getting the components really badly botches them up.
	transformationMatrix = Matrix4Translate(transformationMatrix, moveVector);
	
	[self setTransformationMatrix:&transformationMatrix];
    [self sendMessageToObservers:MessageObservedChanged];
	
}//end moveBy:


//========== position:snappedToGrid: ===========================================
//
// Purpose:		Orients position at discrete points separated by the given grid 
//				spacing. 
//
// Notes:		This method may be overridden by subclasses to provide more 
//				intelligent grid alignment. 
//
//				This method is provided mainly as a service to drag-and-drop. 
//				In the case of LDrawParts, you should generally avoid this 
//				method in favor of 
//				-[LDrawPart components:snappedToGrid:minimumAngle:].
//
//==============================================================================
- (Point3) position:(Point3)position
	  snappedToGrid:(float)gridSpacing
{
	TransformComponents	components	= IdentityComponents;
	
	// copy the position into a transform
	components.translate = position;
	
	// Snap to grid using intelligent LDrawPart logic
	components = [self components:components snappedToGrid:gridSpacing minimumAngle:0];
	
	// copy the new position back out of the components
	position = components.translate;
	
	return position;
	
}//end position:snappedToGrid:


//========== rotateByDegrees: ==================================================
//
// Purpose:		Rotates the part by the specified angles around its centerpoint.
//
//==============================================================================
- (void) rotateByDegrees:(Tuple3)degreesToRotate
{
	Point3	partCenter	= [self position];
	
	//Rotate!
	[self rotateByDegrees:degreesToRotate centerPoint:partCenter];
	
}//end rotateByDegrees


//========== rotateByDegrees:centerPoint: ======================================
//
// Purpose:		Performs an additive rotation on the part, rotating by the 
//				specified number of degress around each axis. The part will be 
//				rotated around the specified centerpoint.
//
// Notes:		This gets a little tricky because there is more than one way 
//				to represent a single rotation when using three rotation angles. 
//				Since we don't really know which one was intended, we can't just 
//				blithely manipulate the rotation components.
//
//				Instead, we must generate a new transformation matrix that 
//				rotates by degreesToRotate in the desired direction. Then we 
//				multiply that matrix by the part's current transformation. This 
//				way, we can rest assured that we rotated the part exactly the 
//				direction the user intended, no matter what goofy representation
//				the components came up with.
//
//				Caveat: We have to do some translations to take into account the  
//				centerpoint.
//
//==============================================================================
- (void) rotateByDegrees:(Tuple3)degreesToRotate
			 centerPoint:(Point3)rotationCenter
{
	Matrix4						transform			= [self transformationMatrix];
	Vector3						displacement		= rotationCenter;
	Vector3						negativeDisplacement= V3Negate(rotationCenter);
	
	//Do the rotation around the specified centerpoint.
	transform = Matrix4Translate(transform, negativeDisplacement); //translate to rotationCenter
	transform = Matrix4Rotate(transform, degreesToRotate); //rotate at rotationCenter
	transform = Matrix4Translate(transform, displacement); //translate back to original position
	
	[self setTransformationMatrix:&transform];
    [self sendMessageToObservers:MessageObservedChanged];
	
}//end rotateByDegrees:centerPoint:


#pragma mark -
#pragma mark OBSERVER
#pragma mark -

//========== observableSaysGoodbyeCruelWorld: ==================================
//
// Purpose:		
//
//==============================================================================
- (void) observableSaysGoodbyeCruelWorld:(id<LDrawObservable>) doomedObservable
{
	if(cacheType == PartTypeUnresolved || cacheType == PartTypeNotFound)
		NSLog(@"WARNING: LDraw part is receiving a notification that its observer is dying but it thinks it should have no observer.\n");
	if(doomedObservable != cacheModel)
		NSLog(@"WARNING: LDraw part is receiving a notification from an observer that is not its cached drawable.\n");
		
	[self unresolvePart];
}


//========== statusInvalidated:who: ============================================
//
// Purpose:		This message is sent to us when a directive we are observing is
//				invalidated.  We invalidate ourselves.  This is what makes our
//				bbox need recalculating when a sub-model changes.
//
//==============================================================================
- (void) statusInvalidated:(CacheFlagsT) flags who:(id<LDrawObservable>) observable
{	
	[self invalCache:(flags & CacheFlagBounds)];
}//end statusInvalidated:who:


//========== receiveMessage:who: ===============================================
//
// Purpose:		
//
//==============================================================================
- (void) receiveMessage:(MessageT) msg who:(id<LDrawObservable>) observable
{
	if(msg == MessageNameChanged)
		[self unresolvePart];
	if(msg == MessageScopeChanged)
		[self unresolvePart];
}



#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== containsReferenceTo: ==============================================
//
// Purpose:		Returns if the part references a model with the given name. This 
//				is used by containers to detect circular references. 
//
//==============================================================================
- (BOOL) containsReferenceTo:(NSString *)name
{
	BOOL isMatch = [referenceName isEqualToString:name];
	return isMatch;
}


//========== partIsMissing =====================================================
//
// Purpose:		Identifies whether the part cannot be found in any known places 
//				to look for it. 
//
//==============================================================================
- (BOOL) partIsMissing
{
	[self resolvePart];
	return cacheType == PartTypeNotFound;
}


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
	LDrawModel  *modelToDraw        = nil;
	LDrawModel  *flatCopy           = nil;
	Matrix4		partTransform		= [self transformationMatrix];
	Matrix4     combinedTransform   = IdentityMatrix4;

	// Nonrecursive flattenings are just trying to collect the primitives. Parts 
	// should be completely ignored. 
	if(recursive == YES)
	{
		[super flattenIntoLines:lines
					  triangles:triangles
				 quadrilaterals:quadrilaterals
						  other:everythingElse
				   currentColor:parentColor
			   currentTransform:transform
				normalTransform:normalTransform
					  recursive:recursive];
					  
		// Flattening involves applying the part's transform to copies of all 
		// referenced vertices. (We are forced to make copies because you can't call 
		// glMultMatrix inside a glBegin; the only way to draw all like geometry at 
		// once is to have a flat, transformed copy of it.) 

		// Do not go through the regular part resolution scheme - it is not thread safe.
		// Look up sub-model first, to avoid taking a lock on the shared library catalog ONLY
		// to discover that we aren't in there.
		
		modelToDraw = [self referencedMPDSubmodel];
		
		if(modelToDraw == nil)
			modelToDraw = [[PartLibrary sharedPartLibrary] modelForName_threadSafe:referenceName];
		
		flatCopy    = [modelToDraw copy];
		
		// concatenate the transform and pass it down
		combinedTransform   = Matrix4Multiply(partTransform, transform);
		
		// Normals are actually transformed by a different matrix.
		normalTransform     = Matrix3MakeNormalTransformFromProjMatrix(combinedTransform);
		
		[flatCopy flattenIntoLines:lines
						 triangles:triangles
					quadrilaterals:quadrilaterals
							 other:everythingElse
					  currentColor:[self LDrawColor]
				  currentTransform:combinedTransform
				   normalTransform:normalTransform
						 recursive:recursive ];
		
		[flatCopy release];
	}

}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


//========== collectPartReport: ================================================
//
// Purpose:		Collects a report on this part. If this is really an MPD 
//				reference, we want to get a report on the submodel and not this 
//				actual part.
//
//==============================================================================
- (void) collectPartReport:(PartReport *)report
{
	[self resolvePart];
	if(cacheType == PartTypeSubmodel || cacheType == PartTypePeerFile)
		[cacheModel collectPartReport:report];
	else if(cacheType == PartTypeLibrary)
		[report registerPart:self];
	
	//There's a bug here: -referencedMPDSubmodel doesn't necessarily tell you if 
	// this actually *is* a submodel reference. It may actually resolve to 
	// something in the part library. In this case, we would draw the library 
	// part, but report the submodel! I'm going to let this ride, because the 
	// specification explicitly says the behavior in such a case is undefined.
	
}//end collectPartReport:


//========== optimizeOpenGL ===================================================
//
// Purpose:		Makes this part run faster by compiling its contents into a 
//				display list if possible.
//
//				This optimization mechanism can only be managed by the 
//				containers which hold the part. 
//
//==============================================================================
- (void) optimizeOpenGL
{
	[self resolvePart];
	
	switch(self->cacheType)
	{
		case PartTypeSubmodel:
		{
			// Tell the submodel we want to draw it with our color.
			if([self->color colorCode] != LDrawCurrentColor)
			{
				[[cacheModel vertexes] optimizeOpenGLWithParentColor:self->color];
			}
		}	break;
	
		case PartTypePeerFile:
		{
			[cacheModel optimizePrimitiveStructure];
			[[cacheModel vertexes] optimizeOpenGLWithParentColor:self->color];
			[cacheDrawable optimizeOpenGL];
		}	break;
		
		case PartTypeLibrary:
		{
			// Only optimize explicitly colored parts.
			// Uncolored parts need to use the color passed at draw time, which 
			// can't be pre-optimized. 
			if([self->color colorCode] != LDrawCurrentColor)
			{
				cacheDrawable = [[PartLibrary sharedPartLibrary] optimizedDrawableForPart:self color:self->color];
			}
		}	break;
	
		default:
			break;
	}
		
	// Make sure the bounding cube is available in our color
	LDrawVertexes *unitCube = [LDrawUtilities boundingCube];
	if([unitCube isOptimizedForColor:self->color] == NO)
	{
		[unitCube optimizeOpenGLWithParentColor:self->color];
	}

}//end optimizeOpenGL


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setTransformComponents:[self transformComponents]];
	[[undoManager prepareWithInvocationTarget:self] setDisplayName:[self displayName]];
	[[undoManager prepareWithInvocationTarget:self] optimizeOpenGL];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAttributesPart", nil)];

}//end registerUndoActions:


//========== addedMPDModel =====================================================
//
// Purpose:		This message is sent when a model is added to a MPD file; if we
//				aren't fonud, we unresolve so that we can get a shot at
//				re-resolving to the newly added part.
//
//==============================================================================
- (void) addedMPDModel:(NSNotification *)notification
{
	if(cacheType == PartTypeNotFound)
		[self unresolvePart];
}//end addedMPDModel


//========== resolvePart =======================================================
//
// Purpose:		Find the object this part references and record the way in which 
//				it was found. 
//
//==============================================================================
- (void) resolvePart
{
	if(cacheType == PartTypeUnresolved)
	{
		LDrawModel * mdpModel = [self referencedMPDSubmodel];
		if(mdpModel != nil)
		{
			cacheModel = mdpModel;
			cacheDrawable = mdpModel;
			cacheType = PartTypeSubmodel;
			
			[self invalCache:CacheFlagBounds];
			[cacheModel addObserver:self];
		}
		else 
		{
			// Try the part library first for speed - sub-paths will thrash the modelmanager.
			cacheModel = [[PartLibrary sharedPartLibrary] modelForName:referenceName];
			if(cacheModel != nil)
			{
				// Intentional: do not observe library parts - they are immutable so 
				// we don't need observations, and messing with the lib parts set is expensive.
				// [cacheModel addObserver:self];

				// WE DO NOT LOOK UP THE DRAWABLE VBO HERE!!!  Do that in -optimizeOpenGL 
				// instead. 
				cacheDrawable = nil;
				[self invalCache:CacheFlagBounds];					
				cacheType = PartTypeLibrary;
			}
			else
			{
				cacheModel = [[ModelManager sharedModelManager] requestModel:referenceName withDocument:[self enclosingFile]];
				if(cacheModel)
				{
					cacheType = PartTypePeerFile;
					cacheDrawable = cacheModel;
					[self invalCache:CacheFlagBounds];
					[cacheModel addObserver:self];				
				}
				else
				{
					cacheType = PartTypeNotFound;
					cacheDrawable = nil;
					cacheModel = nil;
					[self invalCache:CacheFlagBounds];
					// If we are not found, listen to the "sub-model-added" notification; ideally this would be on our enclosing LDrawFile but for
					// now listen to all instances.
					[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addedMPDModel:) name:LDrawMPDSubModelAdded object:nil];					
				}			
			}
		}
	}
}


//========== unresolvePart =====================================================
//
// Purpose:		This method is called when something potentially breaks the link
//				between a part and the underlying model that represents it.
//				Typical events include: renaming the part (new name, new model),
//				putting the part in a new container (new container, new MPD 
//				peers) or deallocing a directive tree in use by the observer
//				(since parts have weak references to their models, this can in
//				theory happen).
//
//==============================================================================
- (void) unresolvePart
{
	if(cacheType != PartTypeUnresolved)
	{
		if(cacheModel != nil && (cacheType == PartTypeSubmodel || cacheType == PartTypePeerFile))
		{
			//printf("Part %p telling observer/cache %p to forget us.\n",self,cacheModel);
			[cacheModel removeObserver:self];
		}
		
		if(cacheType == PartTypeNotFound)
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:LDrawMPDSubModelAdded object:nil];	
		}
		
		cacheType = PartTypeUnresolved;
		cacheDrawable = nil;
		cacheModel = nil;
	}
}//end unresolvePart



//========== unresolvePartIfPartLibrary ========================================
//
// Purpose:		Unresolve a part only if it is a library part.  There are two
//				cases: actual library parts and parts that were not found (and
//				thus maybe they should be library parts but the library that was
//				loaded was incomplete.
//
//				This is used by unresolveLibraryParts to reload the library.
//
//==============================================================================
- (void) unresolvePartIfPartLibrary
{
	if(cacheType == PartTypeLibrary || cacheType == PartTypeNotFound)
		[self unresolvePart];
		
}//end unresolvePartIfPartLibrary

#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		It's time to go home to that great Lego room in the sky--where 
//				all teeth marks on secondhand bricks are healed, where the gold 
//				print never rubs off the classic spacemen, and where the white 
//				bricks never discolor.
//
//==============================================================================
- (void) dealloc
{
	[self unresolvePart];
	
	//release instance variables.
	[displayName	release];
	[referenceName	release];
	
	cacheDrawable = (id) 0xDEADBEEF;
	cacheModel = (id) 0xDEADBEEF;
	
	[super dealloc];
	
}//end dealloc

@end
