//==============================================================================
//
// File:		LDrawVertexes.m
//
// Purpose:		Receives primitives and transfers their vertexes into an 
//				OpenGL-optimized object. Drawing instances of this object will 
//				draw all the contained vertexes. 
//
// Notes:		OpenGL has historically offered several ways of submitting 
//				vertexes, most of which proved highly suboptimal for graphics 
//				cards. Regretfully, those were also the easiest ones to program. 
//
//				Since immediate mode is deprecated and on its way out (and 
//				display lists with it), Bricksmith must resort to this 
//				intermediary object which collects, packs into a buffer, and 
//				draws all the vertexes for a model's geometry. 
//
// Modified:	11/16/2010 Allen Smith. Creation Date.
//
//==============================================================================
#import "LDrawVertexes.h"

#import OPEN_GL_EXT_HEADER

#import "LDrawLine.h"
#import "LDrawTriangle.h"
#import "LDrawQuadrilateral.h"

static void DeleteOptimizationTags(struct OptimizationTags tags);

@implementation LDrawVertexes

//========== init ==============================================================
//
// Purpose:		Initialize the object.
//
//==============================================================================
- (id) init
{
    self = [super init];
    if (self)
	{
		self->lines                         = [[NSMutableArray alloc] init];
		self->triangles                     = [[NSMutableArray alloc] init];
		self->quadrilaterals                = [[NSMutableArray alloc] init];
		self->everythingElse                = [[NSMutableArray alloc] init];
		
		self->colorOptimizations            = [[NSMutableDictionary alloc] init];
		self->colorWireframeOptimizations   = [[NSMutableDictionary alloc] init];
		self->needsRebuilding				= YES;
    }
    return self;
}


#pragma mark -
#pragma mark DRAWING
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Submits the vertex buffer object to OpenGL.
//
// Notes:		This instance is now the only routine in Bricksmith actually 
//				capable of drawing pixels. All the other draw routines just 
//				figure out what to draw; with the demise of immediate-mode 
//				rendering, no directive is actually capable of rendering itself 
//				in isolation. 
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor
{
	id                      key     = parentColor;
	NSValue                 *value  = nil;
	struct OptimizationTags tags    = {};
	
	if(optionsMask & DRAW_WIREFRAME)
	{
		value = [self->colorWireframeOptimizations objectForKey:key];
	}
	else
	{
		value = [self->colorOptimizations objectForKey:key];
	}

	[value getValue:&tags];
	
	// Feh! VBOs+VAOs are 22% slower than display lists. So I'm using display 
	// lists even though everyone says not to. 
	//
	// On the bright side, the display list contains nothing but a VAO, so I 
	// have an "upgrade" path if needed! 
	
#if TRY_DISPLAY_LIST_WRAPPER_FOR_VAO
	if(tags.displayListTag)
	{
		glCallList(tags.displayListTag);
	}
	else
#endif
	{
		// Display lists with VAOs don't work on 10.5

#if UNIFIED_VBOS		
		glBindVertexArrayAPPLE(tags.anyVAOTag);

		// Lines
		if(tags.lineCount)
			glDrawArrays(GL_LINES, tags.lineOffset, tags.lineCount * 2);
		if(tags.triangleCount)
			glDrawArrays(GL_TRIANGLES, tags.triangleOffset, tags.triangleCount * 3);
#if (TESSELATE_QUADS == 0)
		if(tags.quadCount)
			glDrawArrays(GL_QUADS, tags.quadOffset, tags.quadCount * 4);
#endif

#else
		
		// Lines
		if(tags.lineCount)
		{
			glBindVertexArrayAPPLE(tags.linesVAOTag);
			glDrawArrays(GL_LINES, 0, tags.lineCount * 2);
		}
		
		// Triangles
		if(tags.triangleCount)
		{
			glBindVertexArrayAPPLE(tags.trianglesVAOTag);
			glDrawArrays(GL_TRIANGLES, 0, tags.triangleCount * 3);
		}
		
		// Quadrilaterals
#if (TESSELATE_QUADS == 0)
		if(tags.quadCount)
		{
			glBindVertexArrayAPPLE(tags.quadsVAOTag);
			glDrawArrays(GL_QUADS, 0, tags.quadCount * 4);
		}
#endif
#endif
	}
}


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Hit-test the geometry.
//
// Notes:		This being an optimized structure really intended only for 
//				drawing, the idea of hit-testing the geometry is dubvious. This 
//				is here because we use LDrawVertexes objects to draw bounding 
//				boxes, and it's easier to leverage the existing hit test code in 
//				the contained directives. 
//
//==============================================================================
- (void) hitTest:(Ray3)pickRay
	   transform:(Matrix4)transform
	   viewScale:(float)scaleFactor
	  boundsOnly:(BOOL)boundsOnly
	creditObject:(id)creditObject
			hits:(NSMutableDictionary *)hits
{
	NSArray     *commands           = nil;
	NSUInteger  commandCount        = 0;
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	// Triangles
	commands        = triangles;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// Quadrilaterals
	commands        = quadrilaterals;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// Lines
	commands        = lines;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// All else
	commands        = everythingElse;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
}


//========== boxTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Check for intersections with screen-space geometry.
//
//==============================================================================
- (void)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		  viewScale:(float)scaleFactor 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	NSArray     *commands           = nil;
	NSUInteger  commandCount        = 0;
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;

	NSValue *	creditValue = creditObject ? [NSValue valueWithPointer:creditObject] : nil;
	
	// Triangles
	commands        = triangles;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		if(creditObject && [hits containsObject:creditValue])
			return;
	
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// Quadrilaterals
	commands        = quadrilaterals;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		if(creditObject && [hits containsObject:creditValue])
			return;

		currentDirective = [commands objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// Lines
	commands        = lines;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		if(creditObject && [hits containsObject:creditValue])
			return;

		currentDirective = [commands objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
	// All else
	commands        = everythingElse;
	commandCount    = [commands count];
	for(counter = 0; counter < commandCount; counter++)
	{
		if(creditObject && [hits containsObject:creditValue])
			return;

		currentDirective = [commands objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}

}



#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== isOptimizedForColor: ==============================================
//
// Purpose:		Has a cached optimization for the given color.
//
//==============================================================================
- (BOOL) isOptimizedForColor:(LDrawColor *)color
{
	id      key     = color;
	NSValue *value  = [self->colorOptimizations objectForKey:key];
	
	return (value != nil);
}


//========== setLines:triangles:quadrilaterals:other: ==========================
//
// Purpose:		Sets the primitives this container will be responsible for 
//				converting into a vertex array and drawing. 
//
//==============================================================================
- (void) setLines:(NSArray *)linesIn
		triangles:(NSArray *)trianglesIn
   quadrilaterals:(NSArray *)quadrilateralsIn
			other:(NSArray *)everythingElseIn
{
	[self->lines			removeAllObjects];
	[self->triangles		removeAllObjects];
	[self->quadrilaterals	removeAllObjects];
	[self->everythingElse	removeAllObjects];
	
	[self->lines			addObjectsFromArray:linesIn];
	[self->triangles		addObjectsFromArray:trianglesIn];
	[self->quadrilaterals	addObjectsFromArray:quadrilateralsIn];
	[self->everythingElse	addObjectsFromArray:everythingElseIn];
	
}//end setLines:triangles:quadrilaterals:other:


//========== setVertexesNeedRebuilding =========================================
//
// Purpose:		Marks all the optimizations of this vertex collection as needing 
//				rebuilding. 
//
//==============================================================================
- (void) setVertexesNeedRebuilding
{
	self->needsRebuilding = YES;
}


#pragma mark -

//========== addDirective: =====================================================
//
// Purpose:		Register a directive of an arbitrary type (type will be deduced 
//				correctly). 
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)directive
{
	if([directive isMemberOfClass:[LDrawLine class]])
	{
		[self addLine:(LDrawLine*)directive];
	}
	else if([directive isKindOfClass:[LDrawTriangle class]])
	{
		[self addTriangle:(LDrawTriangle*)directive];
	}
	else if([directive isKindOfClass:[LDrawQuadrilateral class]])
	{
		[self addQuadrilateral:(LDrawQuadrilateral*)directive];
	}
	else
	{
		[self addOther:directive];
	}

}//end addDirective:


//========== addLine: ==========================================================
//
// Purpose:		Register a line to be included in the optimized vertexes. The 
//				object must be re-optimized now. 
//
//==============================================================================
- (void) addLine:(LDrawLine *)line
{
	[self->lines addObject:line];
	self->needsRebuilding = YES;
}


//========== addTriangle: ======================================================
//
// Purpose:		Register a triangle to be included in the optimized vertexes. 
//				The object must be re-optimized now. 
//
//==============================================================================
- (void) addTriangle:(LDrawTriangle *)triangle
{
	[self->triangles addObject:triangle];
	self->needsRebuilding = YES;
}


//========== addQuadrilateral: =================================================
//
// Purpose:		Register a quadrilateral to be included in the optimized 
//				vertexes. The object must be re-optimized now. 
//
//==============================================================================
- (void) addQuadrilateral:(LDrawQuadrilateral *)quadrilateral
{
	[self->quadrilaterals addObject:quadrilateral];
	self->needsRebuilding = YES;
}


//========== addOther: =========================================================
//
// Purpose:		Register a other to be included in the optimized vertexes. The 
//				object must be re-optimized now. 
//
//==============================================================================
- (void) addOther:(LDrawDirective *)other
{
	[self->everythingElse addObject:other];
}


#pragma mark -

//========== removeDirective: ==================================================
//
// Purpose:		Register a directive of an arbitrary type (type will be deduced 
//				correctly). 
//
//==============================================================================
- (void) removeDirective:(LDrawDirective *)directive
{
	if([directive isMemberOfClass:[LDrawLine class]])
	{
		[self removeLine:(LDrawLine*)directive];
	}
	else if([directive isKindOfClass:[LDrawTriangle class]])
	{
		[self removeTriangle:(LDrawTriangle*)directive];
	}
	else if([directive isKindOfClass:[LDrawQuadrilateral class]])
	{
		[self removeQuadrilateral:(LDrawQuadrilateral*)directive];
	}
	else
	{
		[self removeOther:directive];
	}
	
}//end removeDirective:


//========== removeLine: =======================================================
//
// Purpose:		De-registers a line to be included in the optimized vertexes. 
//				The object must be re-optimized now. 
//
//==============================================================================
- (void) removeLine:(LDrawLine *)line
{
	[self->lines removeObjectIdenticalTo:line];
	self->needsRebuilding = YES;
}


//========== removeTriangle: ===================================================
//
// Purpose:		De-registers a line to be included in the optimized vertexes. 
//				The object must be re-optimized now. 
//
//==============================================================================
- (void) removeTriangle:(LDrawTriangle *)triangle
{
	[self->triangles removeObjectIdenticalTo:triangle];
	self->needsRebuilding = YES;
}


//========== removeQuadrilateral: ==============================================
//
// Purpose:		De-registers a quadrilateral to be included in the optimized 
//				vertexes. The object must be re-optimized now. 
//
//==============================================================================
- (void) removeQuadrilateral:(LDrawQuadrilateral *)quadrilateral
{
	[self->quadrilaterals removeObjectIdenticalTo:quadrilateral];
	self->needsRebuilding = YES;
}


//========== removeOther: ======================================================
//
// Purpose:		De-registers a other to be included in the optimized vertexes. 
//				The object must be re-optimized now. 
//
//==============================================================================
- (void) removeOther:(LDrawDirective *)other
{
	[self->everythingElse removeObjectIdenticalTo:other];
}


#pragma mark -
#pragma mark OPTIMIZE
#pragma mark -

//========== optimizeOpenGLWithParentColor: ====================================
//
// Purpose:		The caller is asking this instance to optimize itself for faster 
//				drawing. 
//
//				OpenGL optimization is not thread-safe. No OpenGL optimization 
//				is ever performed during parsing because of the thread-safety 
//				limitation, so you are responsible for calling this method on 
//				newly-parsed models. 
//
//==============================================================================
- (void) optimizeOpenGLWithParentColor:(LDrawColor *)color
{
	[self optimizeSolidWithParentColor:color];

#if (USE_AUTOMATIC_WIREFRAMES == 0)
	[self optimizeWireframeWithParentColor:color];
#endif
}


//========== optimizeSolidWithParentColor: =====================================
//
// Purpose:		Optimizes the filled geometry.
//
//==============================================================================
- (void) optimizeSolidWithParentColor:(LDrawColor *)color
{
	VBOVertexData           *buffer                 = NULL;
	struct OptimizationTags tags                    = {};

#if UNIFIED_VBOS

	//---------- Lines VBO -----------------------------------------------------
	{
		glGenBuffers(1, &tags.anyVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.anyVBOTag);
		
		size_t			maxLineCount		= [self->lines count];
		size_t			maxTriangleCount	= [self->triangles count];
		size_t			maxQuadCount		= [self->quadrilaterals count];
#if TESSELATE_QUADS
		maxTriangleCount += ([self->quadrilaterals count] * 2);
		maxQuadCount = 0;
#endif
		size_t			anyBufferSize = (maxLineCount * 2 + maxTriangleCount * 3 + maxQuadCount * 4) * sizeof(VBOVertexData);
		VBOVertexData *	anyVertexes = malloc(anyBufferSize);
		buffer = anyVertexes;
		GLint			offset = 0;
		
		tags.lineOffset = offset;
		for(LDrawLine *currentDirective in self->lines)
		{
			if([currentDirective isHidden] == NO)
			{
				buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
				tags.lineCount++;
				offset += 2;
			}
		}
		tags.triangleOffset = offset;
		for(LDrawTriangle *currentDirective in self->triangles)
		{
			if([currentDirective isHidden] == NO)
			{
				buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
				tags.triangleCount++;
				offset += 3;
			}
		}
	#if TESSELATE_QUADS
		for(LDrawQuadrilateral *currentDirective in self->quadrilaterals)
		{
			if([currentDirective isHidden] == NO)
			{
				buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
				tags.triangleCount += 2;
				offset += 6;
			}
		}
	#endif
		tags.quadOffset = offset;
	#if !TESSELATE_QUADS
		for(LDrawQuadrilateral *currentDirective in self->quadrilaterals)
		{
			if([currentDirective isHidden] == NO)
			{
				buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
				tags.quadCount++;
				offset += 4;
			}
		}
	
	#endif
			
		glBufferData(GL_ARRAY_BUFFER, anyBufferSize, anyVertexes, GL_STATIC_DRAW);
		free(anyVertexes);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		// Encapsulate in a VAO
		glGenVertexArraysAPPLE(1, &tags.anyVAOTag);
		glBindVertexArrayAPPLE(tags.anyVAOTag);
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);
		glBindBuffer(GL_ARRAY_BUFFER, tags.anyVBOTag);
		glVertexPointer(3, GL_FLOAT, sizeof(VBOVertexData), NULL);
		glNormalPointer(GL_FLOAT,    sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3));
		glColorPointer(4, GL_FLOAT,  sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3 + sizeof(float)*3) );
	}
	





#else
	
	//---------- Lines VBO -----------------------------------------------------
	{
		glGenBuffers(1, &tags.linesVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.linesVBOTag);
		
		size_t maxLineCount = [self->lines count];
		
		if(maxLineCount)
		{
			size_t          linesBufferSize     = maxLineCount * sizeof(VBOVertexData) * 2;
			VBOVertexData   *lineVertexes       = malloc(linesBufferSize);
			
			buffer = lineVertexes;
			for(LDrawLine *currentDirective in self->lines)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
					tags.lineCount++;
				}
			}
			
			glBufferData(GL_ARRAY_BUFFER, linesBufferSize, lineVertexes, GL_STATIC_DRAW);
			free(lineVertexes);
			glBindBuffer(GL_ARRAY_BUFFER, 0);

			// Encapsulate in a VAO
			glGenVertexArraysAPPLE(1, &tags.linesVAOTag);
			glBindVertexArrayAPPLE(tags.linesVAOTag);
			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			glBindBuffer(GL_ARRAY_BUFFER, tags.linesVBOTag);
			glVertexPointer(3, GL_FLOAT, sizeof(VBOVertexData), NULL);
			glNormalPointer(GL_FLOAT,    sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3));
			glColorPointer(4, GL_FLOAT,  sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3 + sizeof(float)*3) );
		}
	}
	
	//---------- Triangles VBO -------------------------------------------------
	{
		glGenBuffers(1, &tags.trianglesVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.trianglesVBOTag);
		
		size_t			maxTriangleCount	= [self->triangles count];
		size_t          trianglesBufferSize = 0;
		VBOVertexData   *triangleVertexes   = NULL;
		
#if TESSELATE_QUADS
		// Draws each quad using two independent triangles. 
		// Datsville: 1.04 fps
		maxTriangleCount += ([self->quadrilaterals count] * 2);
#endif
		if(maxTriangleCount > 0)
		{
			trianglesBufferSize = maxTriangleCount * sizeof(VBOVertexData) * 3;
			triangleVertexes    = malloc(trianglesBufferSize);
			
			buffer = triangleVertexes;
			for(LDrawTriangle *currentDirective in self->triangles)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
					tags.triangleCount++;
				}
			}
			
	#if TESSELATE_QUADS
			for(LDrawQuadrilateral *currentDirective in self->quadrilaterals)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
					tags.triangleCount += 2;
				}
			}
	#endif
			
			glBufferData(GL_ARRAY_BUFFER, trianglesBufferSize, triangleVertexes, GL_STATIC_DRAW);
			free(triangleVertexes);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			
			// Encapsulate in a VAO
			glGenVertexArraysAPPLE(1, &tags.trianglesVAOTag);
			glBindVertexArrayAPPLE(tags.trianglesVAOTag);
			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			glBindBuffer(GL_ARRAY_BUFFER, tags.trianglesVBOTag);
			glVertexPointer(3, GL_FLOAT, sizeof(VBOVertexData), NULL);
			glNormalPointer(GL_FLOAT,    sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3));
			glColorPointer(4, GL_FLOAT,  sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3 + sizeof(float)*3) );
		}
	}
	
	//---------- Quadrilaterals VBO --------------------------------------------
	// Draws quads in as quads. 
	// Datsville: 1.3 fps
#if (TESSELATE_QUADS == 0)
	{
		glGenBuffers(1, &tags.quadsVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.quadsVBOTag);
		
		size_t			maxQuadCount	= [self->quadrilaterals count];
		
		if(maxQuadCount)
		{
			size_t          quadsBufferSize = maxQuadCount * sizeof(VBOVertexData) * 4;
			VBOVertexData   *quadVertexes   = malloc(quadsBufferSize);
			
			buffer = quadVertexes;
			for(LDrawQuadrilateral *currentDirective in self->quadrilaterals)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:NO];
					tags.quadCount++;
				}
			}
			
			glBufferData(GL_ARRAY_BUFFER, quadsBufferSize, quadVertexes, GL_STATIC_DRAW);
			free(quadVertexes);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			
			// Encapsulate in a VAO
			glGenVertexArraysAPPLE(1, &tags.quadsVAOTag);
			glBindVertexArrayAPPLE(tags.quadsVAOTag);
			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			glBindBuffer(GL_ARRAY_BUFFER, tags.quadsVBOTag);
			glVertexPointer(3, GL_FLOAT, sizeof(VBOVertexData), NULL);
			glNormalPointer(GL_FLOAT,    sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3));
			glColorPointer(4, GL_FLOAT,  sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3 + sizeof(float)*3) );
		}
	}
	
#endif

#endif
	
	//---------- Wrap it all in a display list ---------------------------------
	
#if TRY_DISPLAY_LIST_WRAPPER_FOR_VAO
	// Display lists are 28% faster than VAOs. What the heck?
	
	// But you can't embed multiple VAOs in a display list on 10.5. (Not 
	// documented; experimentally determined.) 
	static SInt32  systemVersion  = 0;
	static BOOL    useDisplayList = YES;
	if(systemVersion == 0)
	{
		Gestalt(gestaltSystemVersion, &systemVersion);
		useDisplayList = (systemVersion >= 0x1060);
	}
	
	if(useDisplayList)
	{
		tags.displayListTag = glGenLists(1);
		glNewList(tags.displayListTag, GL_COMPILE);
		{
#if UNIFIED_VBOS
			glBindVertexArrayAPPLE(tags.anyVAOTag);

			// Lines
			if(tags.lineCount)
				glDrawArrays(GL_LINES, tags.lineOffset, tags.lineCount * 2);
			if(tags.triangleCount)
				glDrawArrays(GL_TRIANGLES, tags.triangleOffset, tags.triangleCount * 3);
#if (TESSELATE_QUADS == 0)
			if(tags.quadCount)
				glDrawArrays(GL_QUADS, tags.quadOffset, tags.quadCount * 4);
#endif

#else

			// Lines
			if(tags.lineCount)
			{
				glBindVertexArrayAPPLE(tags.linesVAOTag);
				glDrawArrays(GL_LINES, 0, tags.lineCount * 2);
			}
			// Triangles
			if(tags.triangleCount)
			{
				glBindVertexArrayAPPLE(tags.trianglesVAOTag);
				glDrawArrays(GL_TRIANGLES, 0, tags.triangleCount * 3);
			}
			
			// Quadrilaterals
#if (TESSELATE_QUADS == 0)
			if(tags.quadCount)
			{
				glBindVertexArrayAPPLE(tags.quadsVAOTag);
				glDrawArrays(GL_QUADS, 0, tags.quadCount * 4);
			}
#endif
#endif
		}
		glEndList();
	}
#endif
	
	// Cache
	id      key     = color;
	NSValue *value  = [NSValue valueWithBytes:&tags objCType:@encode(struct OptimizationTags)];
	[self->colorOptimizations setObject:value forKey:key];
	
}//end optimizeOpenGL


//========== optimizeWireframeWithParentColor: =================================
//
// Purpose:		The caller is asking this instance to optimize itself for faster 
//				drawing as a wireframe. 
//
//==============================================================================
- (void) optimizeWireframeWithParentColor:(LDrawColor *)color
{
	VBOVertexData           *buffer                 = NULL;
	struct OptimizationTags tags                    = {};
	
	//---------- Lines VBO -----------------------------------------------------
	{
#if UNIFIED_VBOS
		glGenBuffers(1, &tags.anyVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.anyVBOTag);
#else	
		glGenBuffers(1, &tags.linesVBOTag);
		glBindBuffer(GL_ARRAY_BUFFER, tags.linesVBOTag);
#endif		
		size_t          maxVertexCount  = 0;
		size_t          linesBufferSize = 0;
		VBOVertexData   *lineVertexes   = 0;
		
		maxVertexCount += [self->lines count] * 2;
		maxVertexCount += [self->triangles count] * 6;
		maxVertexCount += [self->quadrilaterals count] * 8;
		
		if(maxVertexCount)
		{
			linesBufferSize = maxVertexCount * sizeof(VBOVertexData);
			lineVertexes    = malloc(linesBufferSize);
			buffer          = lineVertexes;
			
			for(LDrawLine *currentDirective in self->lines)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:YES];
					tags.lineCount++;
				}
			}
			for(LDrawTriangle *currentDirective in self->triangles)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:YES];
					tags.lineCount++;
				}
			}
			for(LDrawQuadrilateral *currentDirective in self->quadrilaterals)
			{
				if([currentDirective isHidden] == NO)
				{
					buffer = [currentDirective writeToVertexBuffer:buffer parentColor:color wireframe:YES];
					tags.lineCount++;
				}
			}
			
			glBufferData(GL_ARRAY_BUFFER, linesBufferSize, lineVertexes, GL_STATIC_DRAW);
			free(lineVertexes);
			glBindBuffer(GL_ARRAY_BUFFER, 0);

			// Encapsulate in a VAO
#if UNIFIED_VBOS			
			glGenVertexArraysAPPLE(1, &tags.anyVAOTag);
			glBindVertexArrayAPPLE(tags.anyVAOTag);
#else
			glGenVertexArraysAPPLE(1, &tags.linesVAOTag);
			glBindVertexArrayAPPLE(tags.linesVAOTag);
#endif
			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
#if UNIFIED_VBOS			
			glBindBuffer(GL_ARRAY_BUFFER, tags.anyVBOTag);
#else
			glBindBuffer(GL_ARRAY_BUFFER, tags.linesVBOTag);
#endif
			glVertexPointer(3, GL_FLOAT, sizeof(VBOVertexData), NULL);
			glNormalPointer(GL_FLOAT,    sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3));
			glColorPointer(4, GL_FLOAT,  sizeof(VBOVertexData), (GLvoid*)(sizeof(float)*3 + sizeof(float)*3) );
		}
	}
	
	//---------- Wrap it all in a display list ---------------------------------
	
#if TRY_DISPLAY_LIST_WRAPPER_FOR_VAO
	// Display lists are 28% faster than VAOs. What the heck?
	
	// But you can't embed multiple VAOs in a display list on 10.5. (Not 
	// documented; experimentally determined.) 
	static SInt32  systemVersion  = 0;
	static BOOL    useDisplayList = YES;
	if(systemVersion == 0)
	{
		Gestalt(gestaltSystemVersion, &systemVersion);
		useDisplayList = (systemVersion >= 0x1060);
	}
	
	if(useDisplayList)
	{
		tags.displayListTag = glGenLists(1);
		glNewList(tags.displayListTag, GL_COMPILE);
		{
			// Lines
#if UNIFIED_VBOS			
			glBindVertexArrayAPPLE(tags.anyVAOTag);
#else
			glBindVertexArrayAPPLE(tags.linesVAOTag);
#endif		
			if(tags.lineCount)			
				glDrawArrays(GL_LINES, 0, tags.lineCount * 2);
		}
		glEndList();
	}
#endif
	
	// Cache
	id      key     = color;
	NSValue *value  = [NSValue valueWithBytes:&tags objCType:@encode(struct OptimizationTags)];
	[self->colorWireframeOptimizations setObject:value forKey:key];
	
}//end optimizeOpenGL


//========== rebuildAllOptimizations ===========================================
//
// Purpose:		Regenerates the optimized OpenGL structures for all existing 
//				optimized colors. 
//
//==============================================================================
- (void) rebuildAllOptimizations
{
	if(self->needsRebuilding)
	{
		NSArray *allColors = [self->colorOptimizations allKeys];
		
		[self removeAllOptimizations];
		
		// Rebuild all optimizations
		for(LDrawColor *color in allColors)
		{
			[self optimizeOpenGLWithParentColor:color];
		}
		self->needsRebuilding = NO;
	}
}//end rebuildAllOptimizations


//========== removeAllOptimizations ============================================
//
// Purpose:		Deletes all the optimizations for the vertexes.
//
//==============================================================================
- (void) removeAllOptimizations
{
	// Remove all existing optimizations
	for(LDrawColor *color in self->colorOptimizations)
	{
		NSValue                 *value  = [self->colorOptimizations objectForKey:color];
		struct OptimizationTags tags    = {};
		
		[value getValue:&tags];
		
		DeleteOptimizationTags(tags);
	}
	
	for(LDrawColor *color in self->colorWireframeOptimizations)
	{
		NSValue                 *value  = [self->colorWireframeOptimizations objectForKey:color];
		struct OptimizationTags tags    = {};
		
		[value getValue:&tags];
		
		DeleteOptimizationTags(tags);
	}
	
	[self->colorOptimizations removeAllObjects];
	
}//end removeAllOptimizations


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		It's a permanent flush.
//
//==============================================================================
- (void) dealloc
{
	[self removeAllOptimizations];
	
	[lines							release];
	[triangles						release];
	[quadrilaterals					release];
	[everythingElse					release];
	
	[colorOptimizations				release];
	[colorWireframeOptimizations	release];

	[super dealloc];
	
}//end dealloc


@end


//========== DeleteOptimizationTags ============================================
//
// Purpose:		Removes the optimized objects in the tag list.
//
//==============================================================================
void DeleteOptimizationTags(struct OptimizationTags tags)
{
	if(tags.displayListTag != 0)
	{
#if TRY_DISPLAY_LIST_WRAPPER_FOR_VAO
		glDeleteLists(tags.displayListTag, 1);
#endif
#if UNIFIED_VBOS
		glDeleteBuffers(1, &tags.anyVBOTag);		
		glDeleteVertexArraysAPPLE(1, &tags.anyVAOTag);
		
		tags.displayListTag     = 0;
		tags.anyVBOTag        = 0;
		tags.anyVAOTag        = 0;
#else		
		glDeleteBuffers(1, &tags.linesVBOTag);
		glDeleteBuffers(1, &tags.trianglesVBOTag);
		glDeleteBuffers(1, &tags.quadsVBOTag);
		
		glDeleteVertexArraysAPPLE(1, &tags.linesVAOTag);
		glDeleteVertexArraysAPPLE(1, &tags.trianglesVAOTag);
		glDeleteVertexArraysAPPLE(1, &tags.quadsVAOTag);
		
		tags.displayListTag     = 0;
		tags.linesVBOTag        = 0;
		tags.trianglesVBOTag    = 0;
		tags.quadsVBOTag        = 0;
		tags.linesVAOTag        = 0;
		tags.trianglesVAOTag    = 0;
		tags.quadsVAOTag        = 0;
#endif		
	}
}
