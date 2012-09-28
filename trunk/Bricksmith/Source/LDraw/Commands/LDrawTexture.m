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

#import "LDrawDragHandle.h"
#import "LDrawKeywords.h"
#import "LDrawUtilities.h"
#import "LDrawVertexes.h"
#import "PartLibrary.h"
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
		[self parsePlanarTextureFromLine:currentLine parentGroup:parentGroup];
	
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
	
	[self setImageDisplayName:[decoder decodeObjectForKey:@"imageDisplayName"]];
	[self setGlossmapName:[decoder decodeObjectForKey:@"glossmapName"]];
	
	temporary = [decoder decodeBytesForKey:@"planePoint1" returnedLength:NULL];
	memcpy(&planePoint1, temporary, sizeof(Point3));
	
	temporary = [decoder decodeBytesForKey:@"planePoint2" returnedLength:NULL];
	memcpy(&planePoint2, temporary, sizeof(Point3));
	
	temporary = [decoder decodeBytesForKey:@"planePoint3" returnedLength:NULL];
	memcpy(&planePoint3, temporary, sizeof(Point3));
	
	self->fallback = [[decoder decodeObjectForKey:@"fallback"] retain];

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
	
	[encoder encodeObject:fallback			forKey:@"fallback"];
	[encoder encodeObject:imageDisplayName	forKey:@"imageDisplayName"];
	[encoder encodeObject:glossmapName		forKey:@"glossmapName"];
	
	[encoder encodeBytes:(void*)&planePoint1 length:sizeof(Point3) forKey:@"planePoint1"];
	[encoder encodeBytes:(void*)&planePoint2 length:sizeof(Point3) forKey:@"planePoint2"];
	[encoder encodeBytes:(void*)&planePoint3 length:sizeof(Point3) forKey:@"planePoint3"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawTexture	*copied			= (LDrawTexture *)[super copyWithZone:zone];
	
	copied->fallback = [self->fallback copy];
	[copied setImageDisplayName:[self imageDisplayName]];
	[copied setGlossmapName:[self glossmapName]];
	copied->planePoint1 = self->planePoint1;
	copied->planePoint2 = self->planePoint2;
	copied->planePoint3 = self->planePoint3;
	
	return copied;
	
}//end copyWithZone:


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
	Vector3 		normal				= ZeroPoint3;
	float			length				= 0;
	
	// Need to load the texture here
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
	glBindTexture(GL_TEXTURE_2D, self->textureTag);
	
	normal = V3Sub(self->planePoint2, self->planePoint1);
	length = V3Length(normal);//128./80;//
	normal = V3Normalize(normal);
	
	float planeCoefficientsS[4];
	planeCoefficientsS[0] = normal.x / length;
	planeCoefficientsS[1] = normal.y / length;
	planeCoefficientsS[2] = normal.z / length;
	planeCoefficientsS[3] = V3DistanceFromPointToPlane(ZeroPoint3, normal, self->planePoint1) * length;
	
	// Auto texture vertex generation. This stuff needs to be dumped in favor 
	// of a more modern solution, but it's here as a stopgap. 
	
	glEnable(GL_TEXTURE_GEN_S);
	glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);
	glTexGenfv(GL_S, GL_OBJECT_PLANE, planeCoefficientsS);
	
	
	normal = V3Sub(self->planePoint3, self->planePoint1);
	length = V3Length(normal);//128./80;//
	normal = V3Normalize(normal);
	
	float planeCoefficientsT[4];
	planeCoefficientsT[0] = normal.x / length;
	planeCoefficientsT[1] = normal.y / length;
	planeCoefficientsT[2] = normal.z / length;
	planeCoefficientsT[3] = V3DistanceFromPointToPlane(ZeroPoint3, normal, self->planePoint1) * length;
	
	glEnable(GL_TEXTURE_GEN_T);
	glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);
	glTexGenfv(GL_T, GL_OBJECT_PLANE, planeCoefficientsT);
	
	// Draw each element in the step.
	for(currentDirective in commands)
	{
		[currentDirective draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	}
	
	[self->vertexes draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	
	glBindTexture(GL_TEXTURE_2D, 0);

	if(self->dragHandles)
	{
		for(LDrawDragHandle *handle in self->dragHandles)
		{
			[handle draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
		}
	}
	
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

	if(self->dragHandles)
	{
		for(LDrawDragHandle *handle in self->dragHandles)
		{
			[handle hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:nil hits:hits];
		}
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
	NSArray     *commands			= [self subdirectives];
	NSUInteger  commandCount        = [commands count];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commands objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
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
							
							imageDisplayName];
							
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
	return imageDisplayName;
	
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

//========== glossmapName ======================================================
//==============================================================================
- (NSString *) glossmapName
{
	return glossmapName;
}


//========== imageDisplayName ==================================================
//==============================================================================
- (NSString *) imageDisplayName
{
	return self->imageDisplayName;
}


//========== imageReferenceName ================================================
//
// Purpose:		Returns the name of the image. This is the filename where the 
//				part is found. Since Macintosh computers are case-insensitive, 
//				I have adopted lower-case as the standard for names.
//
//==============================================================================
- (NSString *) imageReferenceName
{
	return self->imageReferenceName;
}


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


//========== setImageDisplayName: ==============================================
//
// Purpose:		Sets the filename of the image to use as the texture.
//
//==============================================================================
- (void) setImageDisplayName:(NSString *)newName
{
	[self setImageDisplayName:newName parse:YES inGroup:NULL];
}


//========== setImageDisplayName:parse:inGroup: ================================
//
// Purpose:		Sets the filename of the image to use as the texture.
//
//				If shouldParse is YES, pre-loads the referenced image if 
//				possible. Pre-loading is very import in initial model loading, 
//				because it enables structual optimizations to be performed prior 
//				to OpenGL optimizations. It also results in a more honest load 
//				progress bar. 
//
//==============================================================================
- (void) setImageDisplayName:(NSString *)newName
					   parse:(BOOL)shouldParse
					 inGroup:(dispatch_group_t)parentGroup
{
	NSString	*newReferenceName   = [newName lowercaseString];
	dispatch_group_t    parseGroup          = NULL;
	
	[newName retain];
	[self->imageDisplayName release];
	self->imageDisplayName = newName;
	
	[newReferenceName retain];
	[self->imageReferenceName release];
	self->imageReferenceName = newReferenceName;
	
	// Force the part library to parse the model this part will display. This 
	// pushes all parsing into the same operation, which improves loading time 
	// predictability and allows better potential threading optimization. 
	if(shouldParse == YES && newName != nil && [newName length] > 0)
	{
#if USE_BLOCKS
		// Create a parsing group if needed.
		if(parentGroup == NULL)
			parseGroup = dispatch_group_create();
		else
			parseGroup = parentGroup;
#endif
		[[PartLibrary sharedPartLibrary] loadImageForName:self->imageDisplayName inGroup:parseGroup];
		
#if USE_BLOCKS
		if(parentGroup == NULL)
		{
			dispatch_group_wait(parseGroup, DISPATCH_TIME_FOREVER);
			dispatch_release(parseGroup);
		}
#endif	
	}
	
}//end setImageDisplayName:


//========== setPlanePoint1: ===================================================
//
// Purpose:		Sets the texture's first planePoint.
//
//==============================================================================
-(void) setPlanePoint1:(Point3)newPlanePoint
{
	self->planePoint1 = newPlanePoint;
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:0] setPosition:newPlanePoint updateTarget:NO];
	}
	
//	[[self enclosingDirective] setVertexesNeedRebuilding];
	
}//end setPlanePoint1:


//========== setPlanePoint2: ===================================================
//
// Purpose:		Sets the texture's second planePoint.
//
//==============================================================================
-(void) setPlanePoint2:(Point3)newPlanePoint
{
	self->planePoint2 = newPlanePoint;
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:1] setPosition:newPlanePoint updateTarget:NO];
	}
	
//	[[self enclosingDirective] setVertexesNeedRebuilding];
	
}//end setPlanePoint2:


//========== setPlanePoint3: ===================================================
//
// Purpose:		Sets the texture's last planePoint.
//
//==============================================================================
-(void) setPlanePoint3:(Point3)newPlanePoint
{
	self->planePoint3 = newPlanePoint;
	
	if(dragHandles)
	{
		[[self->dragHandles objectAtIndex:2] setPosition:newPlanePoint updateTarget:NO];
	}
	
//	[[self enclosingDirective] setVertexesNeedRebuilding];
	
}//end setPlanePoint3:


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
		LDrawDragHandle *handle1 = [[[LDrawDragHandle alloc] initWithTag:1 position:self->planePoint1] autorelease];
		LDrawDragHandle *handle2 = [[[LDrawDragHandle alloc] initWithTag:2 position:self->planePoint2] autorelease];
		LDrawDragHandle *handle3 = [[[LDrawDragHandle alloc] initWithTag:3 position:self->planePoint3] autorelease];
		
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
		case 1: [self setPlanePoint1:newPosition]; break;
		case 2: [self setPlanePoint2:newPosition]; break;
		case 3: [self setPlanePoint3:newPosition]; break;
	}
}//end dragHandleChanged:


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
	
	textureTag = [[PartLibrary sharedPartLibrary] textureTagForTexture:self];
	
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
						parentGroup:(dispatch_group_t)parentGroup
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
		[self setImageDisplayName:parsedName];
		[self setImageDisplayName:parsedName parse:YES inGroup:parentGroup];
		
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
	[imageDisplayName release];
	[imageReferenceName release];
	[glossmapName release];
	
	[vertexes release];
	[dragHandles release];
	
	[super dealloc];
}

@end
