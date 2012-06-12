//==============================================================================
//
// File:		LDrawTexture.m
//
// Purpose:		Support for projecting images onto LDraw geometry.
//
// Modified:	04/10/2012 Allen Smith. Creation Date.
//
//==============================================================================
#import "LDrawTexture.h"

#import "LDrawKeywords.h"
#import "LDrawUtilities.h"
#import "LDrawVertexes.h"
#import "StringCategory.h"


@implementation LDrawTexture

//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Initializes the texture with the lines.
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString        *currentLine        = nil;
	Class           CommandClass        = Nil;
	NSRange         commandRange        = range;
	NSRange			fallbackRange		= NSMakeRange(NSNotFound, 0);
	NSUInteger      lineIndex           = 0;
	NSMutableArray	*strippedLines		= [NSMutableArray array];

	self = [super initWithLines:lines inRange:range parentGroup:parentGroup];
	if(self)
	{
		currentLine = [lines objectAtIndex:range.location];
		[self parsePlanarTextureFromLine:currentLine];
	
		// Parse out the END command
		if(range.length > 0)
		{
			currentLine = [lines objectAtIndex:(NSMaxRange(range) - 1)];
			
			if([[self class] lineIsTextureTerminator:currentLine])
			{
				range.length -= 1;
			}
		}
		
		//---------- Textured geometry -----------------------------------------
		
		// Strip the !: from the beginning of any geometry lines
		lineIndex = range.location + 1;
		while(lineIndex < NSMaxRange(range))
		{
			currentLine = [lines objectAtIndex:lineIndex];
			lineIndex += 1;
			
			NSString    *strippedLine   = nil;
			NSString    *field          = [LDrawUtilities readNextField:currentLine remainder:&strippedLine];
			BOOL		handled			= NO;
			
			if([field isEqualToString:@"0"])
			{
				field = [LDrawUtilities readNextField:strippedLine remainder:&strippedLine];
				if([field isEqualToString:LDRAW_TEXTURE_GEOMETRY])
				{
					[strippedLines addObject:strippedLine];
					handled = YES;
				}
				else if([field isEqualToString:LDRAW_TEXTURE])
				{
					field = [LDrawUtilities readNextField:strippedLine remainder:&strippedLine];
					if([field isEqualToString:LDRAW_TEXTURE_FALLBACK])
					{
						fallbackRange.location = lineIndex;
						fallbackRange.length = NSMaxRange(range) - lineIndex;
						handled = YES;
						break;
					}
				}
			}
			
			if(handled == NO)
			{
				// Line did not have a protective meta prefix. Keep the 
				// original line intact. 
				[strippedLines addObject:currentLine];
			}
		}
		
		// Interpret geometry
		lineIndex = 0;
		while(lineIndex < [strippedLines count])
		{
			currentLine = [strippedLines objectAtIndex:lineIndex];
			
			CommandClass = [LDrawUtilities classForDirectiveBeginningWithLine:currentLine];
			commandRange = [CommandClass rangeOfDirectiveBeginningAtIndex:lineIndex
																  inLines:strippedLines
																 maxIndex:[strippedLines count] - 1];
			LDrawDirective *newDirective = [[CommandClass alloc] initWithLines:strippedLines inRange:commandRange parentGroup:parentGroup];
			[self addDirective:newDirective];
			
			lineIndex     = NSMaxRange(commandRange);
		}
		
		//---------- Fallback geometry -----------------------------------------
		
		if(fallbackRange.location != NSNotFound)
		{
			// not even going to bother parsing this. 
			fallback = [[lines subarrayWithRange:fallbackRange] retain];
		}
	}
	
	return self;
	
}//end initWithLines:inRange:


#pragma mark -

//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
//
// Purpose:		Returns the range from the beginning to the end of the step.
//
//------------------------------------------------------------------------------
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
									 inLines:(NSArray *)lines
									maxIndex:(NSUInteger)maxIndex
{
	NSString	*currentLine	= nil;
	NSUInteger	counter 		= 0;
	NSRange 	testRange		= NSMakeRange(index, maxIndex - index + 1);
	NSInteger	textureLength	= 0;
	NSRange 	textureRange;
	
	NSString	*parsedField	= nil;
	NSString	*workingLine	= nil;
	
	// Regretfully, we have a NEXT directive which saves a whole whopping ONE 
	// LINE of LDraw code. SWEETNESS! And for this INCREDIBLE, STUPENDOUS 
	// SAVINGS, we have to do much more complicated parsing. 
	currentLine = [lines objectAtIndex:index];
	parsedField = [LDrawUtilities readNextField:currentLine remainder:&currentLine];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:currentLine remainder:&currentLine];
		
		if([parsedField isEqualToString:LDRAW_TEXTURE])
		{
			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
//			if([parsedField isEqualToString:LDRAW_TEXTURE_NEXT] )
//			{
//				// 0 !TEXMAP NEXT
//				// <a single-line directive, we hope>
//				
//				textureLength = 2; // the header and the next line
//			}
//			else
			{
				// 0 !TEXMAP START
				// .....
				// 0 !TEXMAP END
				//
				// Find the last line in the texture. 
				for(counter = testRange.location + 1; counter < NSMaxRange(testRange); counter++)
				{
					currentLine = [lines objectAtIndex:counter];
					
					if([[self class] lineIsTextureBeginning:currentLine])
					{
						// Get length of nested texture using a recursive call. This handles 
						// any level of texture nesting. 
						// This is only necessary at all if nested textures are permitted to 
						// be added without a leading "0 !:". 
						NSRange nestedTextureRange = [[self class] rangeOfDirectiveBeginningAtIndex:counter inLines:lines maxIndex:NSMaxRange(testRange)];
						textureLength += nestedTextureRange.length;
					}
					else {
						textureLength += 1;
					}
					
					if([self lineIsTextureTerminator:currentLine])
					{
						// Nothing more to parse. Stop.
						textureLength += 1;
						break;
					}
				}
			}

		}
	}
	
	
	
	textureRange = NSMakeRange(index, textureLength);
	
	return textureRange;
	
}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Bind the texture and draw all the subparts in it.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	NSArray 		*commands			= [self subdirectives];
	LDrawDirective	*currentDirective	= nil;
	
	// Need to load the texture here
	
	// Draw each element in the step.
	for(currentDirective in commands)
	{
		[currentDirective draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	}
	
	[self->vertexes draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	
}//end draw:viewScale:parentColor:


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
	NSArray     *commands			= [self subdirectives];
	NSUInteger  commandCount        = [commands count];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
}


//========== write =============================================================
//
// Purpose:		Write out all the commands in the step, prefaced by the line 
//				0 STEP
//
//==============================================================================
- (NSString *) write
{
	NSMutableString *written        = [NSMutableString string];
	NSString        *CRLF           = [NSString CRLF];
	NSArray         *commands		= [self subdirectives];
	LDrawDirective  *currentCommand = nil;
	NSString		*commandString	= nil;
	NSUInteger      numberCommands  = 0;
	NSUInteger      counter         = 0;
	
	// Start
	[written appendFormat:@"0 %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@",
							LDRAW_TEXTURE, LDRAW_TEXTURE_START, LDRAW_TEXTURE_METHOD_PLANAR,
							
							[LDrawUtilities outputStringForFloat:planePoint1.x],
							[LDrawUtilities outputStringForFloat:planePoint1.y],
							[LDrawUtilities outputStringForFloat:planePoint1.z],
							
							[LDrawUtilities outputStringForFloat:planePoint2.x],
							[LDrawUtilities outputStringForFloat:planePoint2.y],
							[LDrawUtilities outputStringForFloat:planePoint2.z],
							
							[LDrawUtilities outputStringForFloat:planePoint3.x],
							[LDrawUtilities outputStringForFloat:planePoint3.y],
							[LDrawUtilities outputStringForFloat:planePoint3.z],
							
							imageName];
							
	if(glossmapName)
		[written appendFormat:@" %@ %@", LDRAW_TEXTURE_GLOSSMAP, glossmapName];
		
	[written appendString:CRLF];

	// Write all the primary geometry
	numberCommands  = [commands count];
	for(counter = 0; counter < numberCommands; counter++)
	{
		currentCommand = [commands objectAtIndex:counter];
		commandString = [currentCommand write];
		
		// Pre-pend the !: meta if it hasn't already been put there. Nesting !: 
		// is illegal. 
		if([commandString hasPrefix:LDRAW_TEXTURE_GEOMETRY] == NO)
		{
			// Note: I make no attempt to remember if the original geometry had 
			//		 the !: meta when parsed. Doing so is far more trouble than 
			//		 it seems worth. 
			[written appendFormat:@"0 %@ %@", LDRAW_TEXTURE_GEOMETRY, commandString];
		}
		else
		{
			[written appendString:commandString];
		}
		[written appendString:CRLF];
	}
	
	// Fallback geometry
	if([self->fallback count] > 0)
	{
		[written appendFormat:@"0 %@ %@%@", LDRAW_TEXTURE, LDRAW_TEXTURE_FALLBACK, CRLF];
		
		for(NSString* line in fallback)
		{
			[written appendString:line];
			[written appendString:CRLF];
		}
	}
	
	// End
	[written appendFormat:@"0 %@ %@", LDRAW_TEXTURE, LDRAW_TEXTURE_END];
		
	return written;
	
}//end write


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
	return imageName;
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"Texture";
	
}//end iconName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== setGlossmapName: ==================================================
//
// Purpose:		Sets the filename of the image to use for a specular reflection 
//				map. Unused. 
//
//==============================================================================
- (void) setGlossmapName:(NSString *)newName
{
	[newName retain];
	[self->glossmapName release];
	self->glossmapName = newName;
}


//========== setImageName: =====================================================
//
// Purpose:		Sets the filename of the image to use as the texture.
//
//==============================================================================
- (void) setImageName:(NSString *)newName
{
	[newName retain];
	[self->imageName release];
	self->imageName = newName;
}


//========== setVertexesNeedRebuilding =========================================
//
// Purpose:		Marks all the optimizations of this vertex collection as needing 
//				rebuilding. 
//
//==============================================================================
- (void) setVertexesNeedRebuilding
{
	[self->vertexes setVertexesNeedRebuilding];
}


#pragma mark -

//========== insertDirective:atIndex: ==========================================
//
// Purpose:		Inserts the new directive into the step.
//
//==============================================================================
- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index
{
	[super insertDirective:directive atIndex:index];
	
	[vertexes addDirective:directive];
	
}//end insertDirective:atIndex:


//========== removeDirectiveAtIndex: ===========================================
//
// Purpose:		Removes the directive from the step.
//
//==============================================================================
- (void) removeDirectiveAtIndex:(NSInteger)index
{
	LDrawDirective *directive = [[[self subdirectives] objectAtIndex:index] retain];
	
	[super removeDirectiveAtIndex:index];
	
	[vertexes removeDirective:directive];
	
	[directive release];
	
}//end removeDirectiveAtIndex:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== lineIsTextureFallback: ============================================
//
// Purpose:		Returns if line is a 0 !TEXMAP FALLBACK
//
//==============================================================================
+ (BOOL) lineIsTextureFallback:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isEnd			= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_TEXTURE])
		{
			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
			if([parsedField isEqualToString:LDRAW_TEXTURE_FALLBACK])
				isEnd = YES;
		}
	}
	
	return isEnd;
}


//========== lineIsTextureBeginning: ===========================================
//
// Purpose:		Returns if line is a 0 !TEXMAP START
//
//==============================================================================
+ (BOOL) lineIsTextureBeginning:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isStart			= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_TEXTURE])
		{
			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
			if(		[parsedField isEqualToString:LDRAW_TEXTURE_START]
			   ||	[parsedField isEqualToString:LDRAW_TEXTURE_NEXT] )
			{
				parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
				if([parsedField isEqualToString:LDRAW_TEXTURE_METHOD_PLANAR])
				{
					isStart = YES;
				}
			}
		}
	}
	
	return isStart;
}


//========== lineIsTextureTerminator: ==========================================
//
// Purpose:		Returns if line is a 0 !TEXMAP END
//
//==============================================================================
+ (BOOL) lineIsTextureTerminator:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isEnd			= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_TEXTURE])
		{
			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
			if([parsedField isEqualToString:LDRAW_TEXTURE_END])
				isEnd = YES;
		}
	}
	
	return isEnd;
}


//========== optimizeOpenGL ====================================================
//
// Purpose:		Collect members into optimized OpenGL containers.
//
// Notes:		This method is NOT thread safe.
//
//==============================================================================
- (void) optimizeOpenGL
{
	// Allow primitives to be visible when displaying the model itself.
	[self optimizeVertexes];
	
	[super optimizeOpenGL];
}


//========== optimizeStructure =================================================
//
// Purpose:		Arranges the directives in such a way that the file will be 
//				drawn faster. This method should *never* be called on files 
//				which the user has created himself, since it reorganizes the 
//				file contents. It is intended only for parts read from the part  
//				library.
//
//				To optimize, we flatten all the primitives referenced by a part 
//				into a non-nested structure, then separate all the directives 
//				out by the type: all triangles go in a step, all quadrilaterals 
//				go in their own step, etc. 
//
//				Then when drawing, we need not call glBegin() each time. The 
//				result is a speed increase of over 1000%. 
//
//				1000%. That is not a typo.
//
//==============================================================================
- (void) optimizeStructure
{
	NSArray         *steps              = [self subdirectives];
	
	NSMutableArray  *lines              = [NSMutableArray array];
	NSMutableArray  *triangles          = [NSMutableArray array];
	NSMutableArray  *quadrilaterals     = [NSMutableArray array];
	NSMutableArray  *everythingElse     = [NSMutableArray array];
	
	LDrawDirective	*directive			= nil;
	NSUInteger      directiveCount      = 0;
	NSInteger       counter             = 0;
	
	// Traverse the entire hiearchy of part references and sort out each 
	// primitive type into a flat list. This allows staggering speed increases. 
	[self flattenIntoLines:lines
				 triangles:triangles
			quadrilaterals:quadrilaterals
					 other:everythingElse
			  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
		  currentTransform:IdentityMatrix4
		   normalTransform:IdentityMatrix3
				 recursive:YES];
	
	// Now that we have everything separated, remove the main step (it's the one 
	// that has the entire model in it) and . 
	directiveCount = [steps count];
	for(counter = (directiveCount - 1); counter >= 0; counter--)
	{
		[self removeDirectiveAtIndex:counter];
	}
	
	[fallback release];
	fallback = nil;
	
	// Add back all the flattened geometry
	
	for(directive in lines)
		[self addDirective:directive];
	
	for(directive in triangles)
		[self addDirective:directive];
	
	for(directive in quadrilaterals)
		[self addDirective:directive];
	
	for(directive in everythingElse)
		[self addDirective:directive];
		
}//end optimizeStructure


//========== optimizeVertexes ==================================================
//
// Purpose:		Makes sure the vertexes (collected in 
//				-optimizePrimitiveStructure) are displayable. This is called in 
//				response to changing the vertexes, so all existing optimizations 
//				must be destroyed. 
//
//==============================================================================
- (void) optimizeVertexes
{
	[super optimizeVertexes];
	
	// We must create the vertex object HERE, because it is not thread-safe 
	// and will ordinarily be written to when adding and removing 
	// directives. Since the initial parse is multithreaded, we cannot allow 
	// this object to be used until the model has been fully parsed. 
	if(self->vertexes == nil)
	{
		self->vertexes = [[LDrawVertexes alloc] init];
		
		NSMutableArray  *lines              = [NSMutableArray array];
		NSMutableArray  *triangles          = [NSMutableArray array];
		NSMutableArray  *quadrilaterals     = [NSMutableArray array];
		
		[super flattenIntoLines:lines
					 triangles:triangles
				quadrilaterals:quadrilaterals
						 other:nil
				  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
			  currentTransform:IdentityMatrix4
			   normalTransform:IdentityMatrix3
					 recursive:NO];
		
		[vertexes setLines:lines triangles:triangles quadrilaterals:quadrilaterals other:nil];
	}
	
	// Allow primitives to be visible when displaying the model itself.
	LDrawColor *parentColor = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor];
	
	if([vertexes isOptimizedForColor:parentColor])
	{
		// The vertexs have already been optimized for any referencing colors. 
		// Just rebuild the existing color optimizations. 
		[self->vertexes rebuildAllOptimizations];
	}
	else
	{
		// Newly-created, empty vertexes. Make a list to display the model itself. 
		[self->vertexes optimizeOpenGLWithParentColor:parentColor];
	}
}//end optimizeVertexes


//========== parsePlanarTextureFromLine: =======================================
//
// Purpose:		Pulls out the fields of a planar texture.
//
//==============================================================================
- (BOOL) parsePlanarTextureFromLine:(NSString *)line
{
	NSScanner	*scanner	= [NSScanner scannerWithString:line];
	BOOL		success 	= YES;

	@try
	{
		if([scanner scanString:@"0" intoString:NULL] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanString:LDRAW_TEXTURE intoString:NULL] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if(		[scanner scanString:LDRAW_TEXTURE_START intoString:NULL] == NO
		   &&	[scanner scanString:LDRAW_TEXTURE_NEXT intoString:NULL] == NO )
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanString:LDRAW_TEXTURE_METHOD_PLANAR intoString:NULL] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		//---------- Coordinates -----------------------------------------------
		
		if([scanner scanFloat:&(planePoint1.x)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint1.y)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint1.z)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		

		if([scanner scanFloat:&(planePoint2.x)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint2.y)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint2.z)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		

		if([scanner scanFloat:&(planePoint3.x)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint3.y)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		if([scanner scanFloat:&(planePoint3.z)] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		
		//---------- Name ------------------------------------------------------
		// TEXMAP has different syntax from linetype 1 because Joshua Delahunty 
		// wouldn't consider synchronizing the two. 
		NSString *parsedName = [LDrawUtilities scanQuotableToken:scanner];
		if([parsedName length] == 0)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
		[self setImageName:parsedName];
		
		//---------- Glossmap --------------------------------------------------
		// It's optional and unused. It should have been on a separate TEXMAP 
		// line so we didn't have to even bother with it. See above for reason 
		// it's not. 
		if([scanner scanString:LDRAW_TEXTURE_GLOSSMAP intoString:NULL])
		{
			NSString *parsedGlossmapName = [LDrawUtilities scanQuotableToken:scanner];
			if([parsedGlossmapName length] == 0)
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad Planar TEXMAP syntax" userInfo:nil];
			
			[self setGlossmapName:parsedGlossmapName];
		}
	}
	@catch(NSException *exception)
	{
		success = NO;
	}
	
	return success;
	
}


//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
//
// Purpose:		Appends the directive (or a copy of the directive) into the 
//				appropriate container. 
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
	// Textures are responsible for drawing their own geometry. We reveal only 
	// ourself to the parent, not our child geometry. 
	[everythingElse addObject:self];
	
}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Think black fabric. Loosely cut. In a hood.
//
//==============================================================================
- (void) dealloc
{
	[fallback release];
	[imageName release];
	[glossmapName release];
	
	[vertexes release];
	
	[super dealloc];
}

@end
