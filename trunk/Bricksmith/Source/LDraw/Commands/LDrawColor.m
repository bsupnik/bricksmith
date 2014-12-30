//==============================================================================
//
// File:		LDrawColor.m
//
// Purpose:		Meta-command representing !COLOUR definitions. Color codes are 
//				most commonly encountered in ldconfig.ldr, but they may also 
//				appear within models for local scope. 
//
//				At a high level, colors should be retrieved from a ColorLibrary 
//				object. 
//
// Modified:	3/16/08 Allen Smith. Creation Date.
//
//==============================================================================
#import "LDrawColor.h"

#import "LDrawKeywords.h"
#import "LDrawModel.h"
#import "LDrawStep.h"

void RGBtoHSV( float r, float g, float b, float *h, float *s, float *v );

@implementation LDrawColor

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize a new object. 
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	[self setColorCode:LDrawColorBogus];
	[self setEdgeColorCode:LDrawColorBogus];
	[self setMaterial:LDrawColorMaterialNone];
	[self setName:@""];
	
	colorRGBA[3] = 1.0; // alpha.
	
	return self;
	
}//end init


//========== initWithCoder: ====================================================
//
// Purpose:		Reads a representation of this object from the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	self->colorCode             = [decoder decodeIntForKey:@"colorCode"];
	self->colorRGBA[0]          = [decoder decodeFloatForKey:@"colorRGBARed"];
	self->colorRGBA[1]          = [decoder decodeFloatForKey:@"colorRGBAGreen"];
	self->colorRGBA[2]          = [decoder decodeFloatForKey:@"colorRGBABlue"];
	self->colorRGBA[3]          = [decoder decodeFloatForKey:@"colorRGBAAlpha"];
	self->edgeColorCode         = [decoder decodeIntForKey:@"edgeColorCode"];
	self->edgeColorRGBA[0]      = [decoder decodeFloatForKey:@"edgeColorRGBARed"];
	self->edgeColorRGBA[1]      = [decoder decodeFloatForKey:@"edgeColorRGBAGreen"];
	self->edgeColorRGBA[2]      = [decoder decodeFloatForKey:@"edgeColorRGBABlue"];
	self->edgeColorRGBA[3]      = [decoder decodeFloatForKey:@"edgeColorRGBAAlpha"];
	self->hasExplicitAlpha      = [decoder decodeBoolForKey:@"hasExplicitAlpha"];
	self->hasLuminance          = [decoder decodeBoolForKey:@"hasLuminance"];
	self->luminance             = (uint8_t)[decoder decodeIntForKey:@"luminance"];
	self->material              = [decoder decodeIntForKey:@"material"];
	self->materialParameters    = [[decoder decodeObjectForKey:@"materialParameters"] retain];
	self->name                  = [[decoder decodeObjectForKey:@"name"] retain];
	
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
	
	[encoder encodeInt:colorCode				forKey:@"colorCode"];
	[encoder encodeFloat:colorRGBA[0]			forKey:@"colorRGBARed"];
	[encoder encodeFloat:colorRGBA[1]			forKey:@"colorRGBAGreen"];
	[encoder encodeFloat:colorRGBA[2]			forKey:@"colorRGBABlue"];
	[encoder encodeFloat:colorRGBA[3]			forKey:@"colorRGBAAlpha"];
	[encoder encodeInt:edgeColorCode			forKey:@"edgeColorCode"];
	[encoder encodeFloat:edgeColorRGBA[0]		forKey:@"edgeColorRGBARed"];
	[encoder encodeFloat:edgeColorRGBA[1]		forKey:@"edgeColorRGBAGreen"];
	[encoder encodeFloat:edgeColorRGBA[2]		forKey:@"edgeColorRGBABlue"];
	[encoder encodeFloat:edgeColorRGBA[3]		forKey:@"edgeColorRGBAAlpha"];
	[encoder encodeBool:hasExplicitAlpha		forKey:@"hasExplicitAlpha"];
	[encoder encodeBool:hasLuminance			forKey:@"hasLuminance"];
	[encoder encodeInt:luminance				forKey:@"luminance"];
	[encoder encodeInt:material					forKey:@"material"];
	[encoder encodeObject:materialParameters	forKey:@"materialParameters"];
	[encoder encodeObject:name					forKey:@"name"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this color.
//
// Notes:		This method must be implemented in fussy ways to allow this 
//				object to serve as a key for NSDictionaries, which it does in 
//				LDrawVertexes. 
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	// Since almost all colors are supposed to be from libraries, and since copy 
	// must be efficient because dictionary keys are copied, and particularly 
	// since equal objects must have the same hash, it is *VASTLY* easier to 
	// return the object itself for its "copy." 
	//
	// The -hash implementation will die if this is not the case.
	return [self retain];

//	LDrawColor *copied = (LDrawColor *)[super copyWithZone:zone];
//	
//	copied->colorCode				= self->colorCode;
//	memcpy(copied->colorRGBA,		  self->colorRGBA, sizeof(colorRGBA));
//	copied->edgeColorCode			= self->edgeColorCode;
//	memcpy(copied->edgeColorRGBA,	  self->edgeColorRGBA, sizeof(edgeColorRGBA));
//	copied->hasExplicitAlpha		= self->hasExplicitAlpha;
//	copied->hasLuminance			= self->hasLuminance;
//	copied->luminance				= self->luminance;
//	copied->material				= self->material;
//	[copied setMaterialParameters:[self materialParameters]];
//	[copied setName:[self name]];
//	
//	return copied;
	
}//end copyWithZone:

//========== fullCopyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this color.  Used for creating transparent
//              versions of a color on the fly
//
// Notes:		This method must be implemented in fussy ways to allow this
//				object to serve as a key for NSDictionaries, which it does in
//				LDrawVertexes.
//
//              This is probably not an efficient method
//
//==============================================================================
- (id)fullCopyWithZone:(NSZone *)zone
{
	LDrawColor *copied = (LDrawColor *)[super copyWithZone:zone];

	copied->colorCode				= self->colorCode;
	memcpy(copied->colorRGBA,		  self->colorRGBA, sizeof(colorRGBA));
	copied->edgeColorCode			= self->edgeColorCode;
	memcpy(copied->edgeColorRGBA,	  self->edgeColorRGBA, sizeof(edgeColorRGBA));
	copied->hasExplicitAlpha		= self->hasExplicitAlpha;
	copied->hasLuminance			= self->hasLuminance;
	copied->luminance				= self->luminance;
	copied->material				= self->material;
	[copied setMaterialParameters:[self materialParameters]];
	[copied setName:[self name]];

	return copied;

}//end copyWithZone:


//========== finishParsing: ====================================================
//
// Purpose:		-[LDrawMetaCommand initWithLines:inRange:] is 
//				responsible for parsing out the line code and color command 
//				(i.e., "0 !COLOUR"); now we just have to finish the 
//				color-command specific syntax. 
//
//==============================================================================
- (BOOL) finishParsing:(NSScanner *)scanner
{
	NSString	*field				= nil;
	int			scannedAlpha		= 0;
	int			scannedLuminance	= 0;
	float		parsedColor[4]		= {0.0};
	
	[scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
	
	// Name
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&field];
	[self setName:field];
	
	// Color Code
	if([scanner scanString:LDRAW_COLOR_DEF_CODE intoString:nil] == NO)
		@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad !COLOUR syntax" userInfo:nil];
	if([scanner scanInt:&self->colorCode] == NO)
		@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad !COLOUR syntax" userInfo:nil];
	
	// Color Components
	if([scanner scanString:LDRAW_COLOR_DEF_VALUE intoString:nil] == NO)
		@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad !COLOUR syntax" userInfo:nil];
	if([self scanHexString:scanner intoRGB:self->colorRGBA] == NO)
		@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad !COLOUR syntax" userInfo:nil];
		
	// Edge
	if([scanner scanString:LDRAW_COLOR_DEF_EDGE intoString:nil] == NO)
		@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad !COLOUR syntax" userInfo:nil];
	if([self scanHexString:scanner intoRGB:parsedColor] == YES)
		[self setEdgeColorRGBA:parsedColor];
	else
		[scanner scanInt:&self->edgeColorCode];
	
	// Optional Fields
	
	// - Alpha
	if([scanner scanString:LDRAW_COLOR_DEF_ALPHA intoString:nil] == YES)
	{
		[scanner scanInt:&scannedAlpha];
		self->colorRGBA[3]		= (float) scannedAlpha / 255;
		self->hasExplicitAlpha	= YES;
	}
	
	// - Luminance
	if([scanner scanString:LDRAW_COLOR_DEF_LUMINANCE intoString:nil] == YES)
	{
		[scanner scanInt:&scannedLuminance];
		[self setLuminance:scannedLuminance];
	}
	
	// - Material
	if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_CHROME intoString:nil] == YES)
		[self setMaterial:LDrawColorMaterialChrome];
		
	else if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_PEARLESCENT intoString:nil] == YES)
		[self setMaterial:LDrawColorMaterialPearlescent];
	
	else if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_RUBBER intoString:nil] == YES)
		[self setMaterial:LDrawColorMaterialRubber];
	
	else if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_MATTE_METALLIC intoString:nil] == YES)
		[self setMaterial:LDrawColorMaterialMatteMetallic];
	
	else if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_METAL intoString:nil] == YES)
		[self setMaterial:LDrawColorMaterialMetal];
	
	else if([scanner scanString:LDRAW_COLOR_DEF_MATERIAL_CUSTOM intoString:nil] == YES)
	{
		[self setMaterial:LDrawColorMaterialCustom];
		
		// eat whitespace
		[scanner setCharactersToBeSkipped:nil];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		
		// Custom material parameters are implementation-defined and follow the 
		// MATERIAL keyword. Just scan them and save them; we can't do anything 
		// with them except write them back out when the file is saved. 
		field = [[scanner string] substringFromIndex:[scanner scanLocation]];
		[self setMaterialParameters:field];
	}
	
	return YES;
	
}//end lineWithDirectiveText


//---------- blendedColorForCode: ------------------------------------[static]--
//
// Purpose:		Returns pseduocolors according to logic found in LDRAW.EXE.
//
// Notes:		James Jessiman's original DOS-based LDraw was limited in to 16 
//				colors (in 1995!), so he developed a hack to accommodate a 
//				bigger palette: dithering. Two colors would be combined in a 
//				pixel-checkerboard pattern. Transparent colors were implemented 
//				with a dither overlay, as was a huge swath of color codes which 
//				would combine two colors. 
//
//				All of this is utterly, pathologically obsolete. For one thing, 
//				computers can display 16.7 million colors per pixel. For another 
//				thing, dithering was really ugly. And finally, LDConfig and the 
//				!COLOUR meta-command provide a way of specifying any one of 
//				those 16.7 million colors. 
//
//				Unfortunately, MLCad displayed dithered colors in its color 
//				picker up until 2010. Worse yet, woe betide us, part authors 
//				used these dithered colors to model certain stickers and printed 
//				bricks. 
//
//				Bricksmith will grudgingly support blended colors strictly for 
//				purposes of displaying those stickers. But it will NOT, EVER 
//				show these colors in its color picker. This functionality should 
//				be sent back to the early nineties where it deserved to die. 
//
//------------------------------------------------------------------------------
+ (LDrawColor *) blendedColorForCode:(LDrawColorT)colorCode
{
	uint8_t ldrawEXEColorTable[16][3] = {
											{ 51,	 51,	 51},
											{  0,	 51,	178},
											{  0,	127,	 51},
											{  0,	181,	166},
											{204,	  0,	  0},
											{255,	 51,	153},
											{102,	 51,	  0},
											{153,	153,	153},
											{102,	102,	 88},
											{  0,	128,	255},
											{ 51,	255,	102},
											{171,	253,	249},
											{255,	  0,	  0},
											{255,	176,	204},
											{255,	229,	  0},
											{255,	255,	255} 
										};

	int         blendCode1              = 0;
	int         blendCode2              = 0;
	GLfloat     blendedComponents[4]    = {0.0};
	LDrawColor  *blendedColor           = [[LDrawColor alloc] init];
	
	// Find the two base indexes of the blended color's dither.
	blendCode1 = (colorCode - 256) / 16; // div (integer division)
	blendCode2 = (colorCode - 256) % 16;
	
	// Derive the components. Hold your nose.
	// Obviously, we don't support dithering. We average the colors to produce 
	// something which looks nicer. 
	blendedComponents[0] = (float)(ldrawEXEColorTable[blendCode1][0] + ldrawEXEColorTable[blendCode2][0]) / 2 / 255; // red
	blendedComponents[1] = (float)(ldrawEXEColorTable[blendCode1][1] + ldrawEXEColorTable[blendCode2][1]) / 2 / 255; // green
	blendedComponents[2] = (float)(ldrawEXEColorTable[blendCode1][2] + ldrawEXEColorTable[blendCode2][2]) / 2 / 255; // blue
	blendedComponents[3] = 1.0; // alpha
	
	// Create a color to hold them.
	[blendedColor setColorCode:colorCode];
	[blendedColor setColorRGBA:blendedComponents];
	[blendedColor setName:[NSString stringWithFormat:@"BlendedColor%d", colorCode]];
	
	return [blendedColor autorelease];
	
}//end blendedColorForCode:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		"Draws" the color.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	// Need to add this color to the model's color library.
	ColorLibrary *colorLibrary = [[(LDrawStep*)[self enclosingDirective] enclosingModel] colorLibrary];
	
	[colorLibrary addColor:self];
		
}//end draw:viewScale:parentColor:


//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//				Line format:
//				0 !COLOUR name CODE x VALUE v EDGE e [ALPHA a] [LUMINANCE l] 
//					[ CHROME | PEARLESCENT | RUBBER | MATTE_METALLIC | 
//					  METAL | MATERIAL <params> ]</params> 
//
// Notes:		This does not try to preserve spacing a la ldconfig.ldr, mainly 
//				because %17@ doesn't work. 
//
//==============================================================================
- (NSString *) write
{
	NSMutableString *line = nil;
	
	line = [NSMutableString stringWithFormat:
							@"0 %@ %@ %@ %d %@ %@",
							//	|	  |		|
								LDRAW_COLOR_DEFINITION, self->name,
							//		  |		|
									  LDRAW_COLOR_DEF_CODE,	self->colorCode,
							//				|
											LDRAW_COLOR_DEF_VALUE,	[self hexStringForRGB:self->colorRGBA] ];
											
	if(self->edgeColorCode == LDrawColorBogus)
		[line appendFormat:@" %@ %@", LDRAW_COLOR_DEF_EDGE, [self hexStringForRGB:self->edgeColorRGBA]];
	else
		[line appendFormat:@" %@ %d", LDRAW_COLOR_DEF_EDGE, self->edgeColorCode];
		
	if(self->hasExplicitAlpha == YES)
		[line appendFormat:@" %@ %d", LDRAW_COLOR_DEF_ALPHA, (int)(self->colorRGBA[3] * 255)];
		
	if(self->hasLuminance == YES)
		[line appendFormat:@" %@ %d", LDRAW_COLOR_DEF_LUMINANCE, self->luminance];
	
	switch(self->material)
	{
		case LDrawColorMaterialNone:
			break;
			
		case LDrawColorMaterialChrome:
			[line appendFormat:@" %@", LDRAW_COLOR_DEF_MATERIAL_CHROME];
			break;		
		
		case LDrawColorMaterialPearlescent:
			[line appendFormat:@" %@", LDRAW_COLOR_DEF_MATERIAL_PEARLESCENT];
			break;		
			
		case LDrawColorMaterialRubber:
			[line appendFormat:@" %@", LDRAW_COLOR_DEF_MATERIAL_RUBBER];
			break;		
			
		case LDrawColorMaterialMatteMetallic:
			[line appendFormat:@" %@", LDRAW_COLOR_DEF_MATERIAL_MATTE_METALLIC];
			break;		
			
		case LDrawColorMaterialMetal:
			[line appendFormat:@" %@", LDRAW_COLOR_DEF_MATERIAL_METAL];
			break;		
			
		case LDrawColorMaterialCustom:
			[line appendFormat:@" %@ %@", LDRAW_COLOR_DEF_MATERIAL_CUSTOM, self->materialParameters];
			break;		
	}
	
	return line;
	
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
	return [self name];
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"ColorDroplet";
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return nil;
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== alpha =============================================================
//==============================================================================
- (GLfloat) alpha
{
	return colorRGBA[3];
}

//========== colorCode =========================================================
//==============================================================================
- (LDrawColorT) colorCode
{
	return self->colorCode;
	
}//end colorCode


//========== complimentColor ===================================================
//
// Purpose:		Returns the color which should be used for drawing 
//				LDrawEdgeColor for this color. 
//
//==============================================================================
- (LDrawColor *) complimentColor
{
	// LDConfig compliment colors look ugly. Bricksmith uses internally-derived 
	// compliments which look more like the original LDraw. 
	if(fakeComplimentColor == nil)
	{
		self->fakeComplimentColor = [[LDrawColor alloc] init];
		
		GLfloat fakeComplimentComponents[4] = {};
		complimentColor(self->colorRGBA, fakeComplimentComponents);
		
		[fakeComplimentColor setColorCode:LDrawEdgeColor];
		[fakeComplimentColor setColorRGBA:fakeComplimentComponents];
	}
	
	return fakeComplimentColor;
}


//========== edgeColorCode =====================================================
//
// Purpose:		Return the LDraw color code to be used when drawing the 
//				compilement of this color. If the compliment is stored as actual 
//				components instead, this call will return LDrawColorBogus. When 
//				that code is encountered, you should instead call edgeColorRGBA 
//				for the actual color values. 
//
//==============================================================================
- (LDrawColorT) edgeColorCode
{
	return self->edgeColorCode;
	
}//end edgeColorCode



//========== getColorRGBA: =====================================================
//
// Purpose:		Fills the inComponents array with the RGBA components of this 
//				color. 
//
//==============================================================================
- (void) getColorRGBA:(GLfloat *)inComponents
{
	memcpy(inComponents, self->colorRGBA, sizeof(GLfloat) * 4);
	
}//end getColorRGBA:


//========== getEdgeColorRGBA: =================================================
//
// Purpose:		Returns the actual color components specified for the compliment 
//				of this color. 
//
// Notes:		These values MAY NOT BE VALID. To determine if they are in 
//				force, you must first call -edgeColorCode. If it returns a value 
//				other than LDrawColorBogus, look up the color for that code 
//				instead. Otherwise, use the values returned by this method. 
//
//==============================================================================
- (void) getEdgeColorRGBA:(GLfloat *)inComponents
{
	memcpy(inComponents, self->edgeColorRGBA, sizeof(GLfloat) * 4);
	
}//end getEdgeColorRGBA:


//========== localizedName =====================================================
//
// Purpose:		Returns the name for the specified color code. If possible, the 
//				name will be localized. For colors which have no localization 
//				defined, this will default to the actual color name from the 
//				config file, with any underscores converted to spaces. 
//
// Notes:		If, in some bizarre aberration, this color has a code 
//				corresponding to a standard LDraw code, but the color is NOT 
//				actually representing this color, you will get the localized 
//				name of the standard color. Deal with it. 
//
//==============================================================================
- (NSString *) localizedName
{
	NSString *nameKey	= nil;
	NSString *colorName	= nil;
	
	//Find the color's name in the localized string file.
	// Color names are conveniently keyed.
	nameKey		= [NSString stringWithFormat:@"LDraw: %d", colorCode];
	colorName	= NSLocalizedString(nameKey , nil);
	
	// If no localization was defined, then fall back on the name defined in the 
	// color directive. 
	if([colorName isEqualToString:nameKey])
	{
		// Since spaces are verboten in !COLOUR directives, color names tend to 
		// have a bunch of unsightly underscores in them. We don't want to show 
		// that to the user. 
		NSMutableString *fixedName = [[[self name] mutableCopy] autorelease];
		[fixedName replaceOccurrencesOfString:@"_" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [fixedName length])];
		colorName = fixedName;
		
		// Alas! 10.5 only!
//		colorName = [[self name] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
	}
	
	return colorName;
	
}//end localizedName


//========== luminance =========================================================
//==============================================================================
- (uint8_t) luminance
{
	return self->luminance;
	
}//end luminance


//========== material ==========================================================
//==============================================================================
- (LDrawColorMaterialT) material
{
	return self->material;
	
}//end material


//========== materialParameters ================================================
//==============================================================================
- (NSString *) materialParameters
{
	return self->materialParameters;
	
}//end materialParameters


//========== name ==============================================================
//==============================================================================
- (NSString *) name
{
	return self->name;
	
}//end name


#pragma mark -

//========== setColorCode: =====================================================
//
// Purpose:		Sets the LDraw integer code for this color.
//
//==============================================================================
- (void) setColorCode:(LDrawColorT)newCode
{
	self->colorCode = newCode;

}//end setColorCode:


//========== setColorRGBA: =====================================================
//
// Purpose:		Sets the actual RGBA component values for this color. 
//
//==============================================================================
- (void) setColorRGBA:(GLfloat *)newComponents
{
	memcpy(self->colorRGBA, newComponents, sizeof(GLfloat[4]));
	
}//end setColorRGBA:


//========== setEdgeColorCode: =================================================
//
// Purpose:		Sets the code of the color to use as this color's compliment 
//				color. That value will have to be resolved by the color library. 
//
// Notes:		Edge colors may be specified either as real color components or 
//				as a color-code reference. Only one is valid. To signal that the 
//				components should be used instead of this color code, pass 
//				LDrawColorBogus. 
//
//==============================================================================
- (void) setEdgeColorCode:(LDrawColorT)newCode
{
	self->edgeColorCode = newCode;
	
}//end setEdgeColorCode:


//========== setEdgeColorRGBA: =================================================
//
// Purpose:		Sets actual color components for the edge color.
//
// Notes:		Edge colors may be specified either as real color components or 
//				as a color-code reference. Only one is valid. If you call this 
//				method, it is assumed you are choosing the components variation. 
//				The edge color code will automatically be set to 
//				LDrawColorBogus. 
//
//==============================================================================
- (void) setEdgeColorRGBA:(GLfloat *)newComponents
{
	memcpy(self->edgeColorRGBA, newComponents, sizeof(GLfloat[4]));
	
	// Disable the edge color code, since we have real color values for it now.
	[self setEdgeColorCode:LDrawColorBogus];
	
}//end setEdgeColorRGBA:


//========== setLuminance: =====================================================
//
// Purpose:		Brightness for colors that glow (range 0-255). Luminance is not 
//				generally used by LDraw renderers (including this one), but may 
//				be used for translation to other rendering systems. LUMINANCE is 
//				optional. 
//
//==============================================================================
- (void) setLuminance:(uint8_t)newValue
{
	self->luminance		= newValue;
	self->hasLuminance	= YES;
	
}//end setLuminance:


//========== setMaterial: ======================================================
//
// Purpose:		Sets the material associated with this color.
//
// Notes:		Bricksmith doesn't use this value, it just preserves it in the 
//				color directive. 
//
//==============================================================================
- (void) setMaterial:(LDrawColorMaterialT)newValue
{
	self->material = newValue;

}//end setMaterial:


//========== setMaterialParameters: ============================================
//
// Purpose:		Custom (implementation-dependent) values associated with a 
//				custom material. 
//
// Notes:		Bricksmith doesn't use this value, it just preserves it in the 
//				color directive. 
//
//==============================================================================
- (void) setMaterialParameters:(NSString *)newValue
{
	[newValue retain];
	[self->materialParameters release];
	
	self->materialParameters = newValue;
	
}//end setMaterialParameters:


//========== setName: ==========================================================
//
// Purpose:		Sets the name of the color. Spaces are represented by 
//				underscores. 
//
//==============================================================================
- (void) setName:(NSString *)newName
{
	[newName retain];
	[self->name release];
	
	self->name = newName;
	
}//end setName:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== isEqual: ==========================================================
//
// Purpose:		Allow these objects to serve as keys in a dictionary (used in 
//				LDrawVertexes); -isEqual: and -hash are both required.
//
//				We only expect one instance of each unique color to exist, so 
//				the trivial comparison should be valid. After all, two different 
//				(file-local) colors could share the same color code, but they 
//				aren't equal.
//
//==============================================================================
- (BOOL) isEqual:(id)anObject
{
	BOOL isEqual = NO;
	
	// If two objects are equal, they must return the same hash. The hash is a 
	// pain to compute, so we don't want to do anything fancy with equality.
//	if([anObject isMemberOfClass:[LDrawColor class]])
//	{
//		isEqual = (self->colorCode == [anObject colorCode]);
//	}

	isEqual = (anObject == self);

	return isEqual;
}


//========== hash ==============================================================
//
// Purpose:		Allow these objects to serve as keys in a dictionary (used in 
//				LDrawVertexes).
//
//==============================================================================
- (NSUInteger)hash
{
	return (NSUInteger)self;
}


//========== compare: ==========================================================
//
// Purpose:		Compatibility method directing to our specialized comparison.
//
//==============================================================================
- (NSComparisonResult) compare:(LDrawColor *)otherColor
{
	return [self HSVACompare:otherColor];
}


//========== HSVACompare: ======================================================
//
// Purpose:		Orders colors according to their Hue, Saturation, and 
//				Brightness. 
//
//==============================================================================
- (NSComparisonResult) HSVACompare:(LDrawColor *)otherColor
{
	NSComparisonResult  result              = NSOrderedSame;
	float               ourHSV[4]           = {0.0};
	float               otherColorHSV[4]    = {0.0};
	
	// Convert both to Hue-saturation-brightness
	RGBtoHSV(self->colorRGBA[0], self->colorRGBA[1], self->colorRGBA[2],
			 &ourHSV[0], &ourHSV[1], &ourHSV[2]);
	
	RGBtoHSV(otherColor->colorRGBA[0], otherColor->colorRGBA[1], otherColor->colorRGBA[2],
			 &otherColorHSV[0], &otherColorHSV[1], &otherColorHSV[2]);
			 
	// Alpha
	ourHSV[3]           = self->colorRGBA[3];
	otherColorHSV[3]    = self->colorRGBA[3];
	
	// Hue
	if( ourHSV[0] > otherColorHSV[0] )
		result = NSOrderedDescending;
	else if( ourHSV[0] < otherColorHSV[0] )
		result = NSOrderedAscending;
	else
	{
		// Saturation
		if( ourHSV[1] > otherColorHSV[1] )
			result = NSOrderedDescending;
		else if( ourHSV[1] < otherColorHSV[1] )
			result = NSOrderedAscending;
		else
		{
			// Brightness
			if( ourHSV[2] > otherColorHSV[2] )
				result = NSOrderedDescending;
			else if( ourHSV[2] < otherColorHSV[2] )
				result = NSOrderedAscending;
			else
			{
				// Alpha
				if( ourHSV[3] > otherColorHSV[3] )
					result = NSOrderedDescending;
				else if( ourHSV[3] < otherColorHSV[3] )
					result = NSOrderedAscending;
				else
				{
					result = NSOrderedSame;
				}
			}
		}
	}
	
	return result;
	
}//end HSVACompare:


//========== hexStringForRGB: ==================================================
//
// Purpose:		Returns a hex string for the given RGB components, formatted in 
//				the syntax required by the LDraw Colour Definition Language 
//				extension. 
//
//==============================================================================
- (NSString *) hexStringForRGB:(GLfloat *)components
{
	NSString	*hexString	= [NSString stringWithFormat:@"#%02X%02X%02X",
													(int) (components[0] * 255),
													(int) (components[1] * 255),
													(int) (components[2] * 255) ];
	return hexString;

}//end hexStringForRGB:


//========== scanHexString:intoRGB: ============================================
//
// Purpose:		Parses the given Hexidecimal string into the first three 
//				elements of the components array, dividing each hexidecimal byte 
//				by 255. 
//
// Notes:		hexString must be prefixed by either "#" or "0x". The LDraw spec 
//				is not clear on the case of the hex letters; we will assume both 
//				are valid. 
//
// Example:		#77CC00 becomes (R = 0.4666; G = 0.8; B = 0.0)
//
//==============================================================================
- (BOOL) scanHexString:(NSScanner *)hexScanner intoRGB:(GLfloat *)components
{
	unsigned	hexBytes	= 0;
	BOOL		success		= NO;
	
	// Make sure it has the required prefix, whichever it might be
	if(		[hexScanner scanString:@"#"  intoString:nil] == YES
	   ||	[hexScanner scanString:@"0x" intoString:nil] == YES )
	{
		success = YES;
	}
	
	if(success == YES)
	{
		// Scan the hex bytes into a packed integer, because that's the easiest 
		// thing to do with this NSScanner API. 
		[hexScanner scanHexInt:&hexBytes];
		
		// Colors will be stored in the integer as follows: xxRRGGBB
		components[0] = (GLfloat) ((hexBytes >> 2 * 8) & 0xFF) / 255; // Red
		components[1] = (GLfloat) ((hexBytes >> 1 * 8) & 0xFF) / 255; // Green
		components[2] = (GLfloat) ((hexBytes >> 0 * 8) & 0xFF) / 255; // Blue
		components[3] = 1.0; // we shall assume alpha
	}
	
	return success;
	
}//end parseHexString:intoRGB:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're turning blue.
//
//==============================================================================
- (void) dealloc
{
	[materialParameters		release];
	[name					release];
	
	[fakeComplimentColor	release];
	
	[super dealloc];
	
}//end dealloc


@end


#pragma mark -

//========== RGBtoHSV ==========================================================
//
// Purpose:		Converts an RGB color into Hue-Saturation-Brightness
//
// Parameters:	r,g,b values are from 0 to 1
//				h = [0,360], s = [0,1], v = [0,1]
//					if s == 0, then h = -1 (undefined)
//
// Notes:		from http://www.cs.rit.edu/~ncs/color/t_convert.html
//
//==============================================================================
void RGBtoHSV( float r, float g, float b, float *h, float *s, float *v )
{
	float min, max, delta;
	
	min = MIN( r, MIN(g, b) );
	max = MAX( r, MAX(g, b) );
	*v = max;				// v
	
	delta = max - min;
	
	if( max != 0 )
		*s = delta / max;		// s
	else {
		// r = g = b = 0		// s = 0, v is undefined
		*s = 0;
		*h = -1;
		return;
	}
	
	if( r == max )
		*h = ( g - b ) / delta;		// between yellow & magenta
	else if( g == max )
		*h = 2 + ( b - r ) / delta;	// between cyan & yellow
	else
		*h = 4 + ( r - g ) / delta;	// between magenta & cyan
	
	*h *= 60;				// degrees
	if( *h < 0 )
		*h += 360;
}


//========== HSVtoRGB ==========================================================
//
// Purpose:		Converts an HSV color into Red-Green-Blue
//
// Parameters:	r,g,b values are from 0 to 1
//				h = [0,360], s = [0,1], v = [0,1]
//					if s == 0, then h = -1 (undefined)
//
// Notes:		from http://www.cs.rit.edu/~ncs/color/t_convert.html
//
//==============================================================================
void HSVtoRGB( float h, float s, float v, float *r, float *g, float *b )
{
	int i;
	float f, p, q, t;
	
	if( s == 0 ) {
		// achromatic (grey)
		*r = *g = *b = v;
		return;
	}
	
	h /= 60;			// sector 0 to 5
	i = floor( h );
	f = h - i;			// factorial part of h
	p = v * ( 1 - s );
	q = v * ( 1 - s * f );
	t = v * ( 1 - s * ( 1 - f ) );
	
	switch( i ) {
		case 0:
			*r = v;
			*g = t;
			*b = p;
			break;
		case 1:
			*r = q;
			*g = v;
			*b = p;
			break;
		case 2:
			*r = p;
			*g = v;
			*b = t;
			break;
		case 3:
			*r = p;
			*g = q;
			*b = v;
			break;
		case 4:
			*r = t;
			*g = p;
			*b = v;
			break;
		default:		// case 5:
			*r = v;
			*g = p;
			*b = q;
			break;
	}
}