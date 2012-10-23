//==============================================================================
//
// File:		LDrawUtilities.m
//
// Purpose:		Convenience routines for managing LDraw directives: their 
//				syntax, manipulation, or display. 
//
//  Created by Allen Smith on 2/28/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "LDrawUtilities.h"

#import "LDrawColor.h"
#import "LDrawConditionalLine.h"
#import "LDrawContainer.h"
#import "LDrawKeywords.h"
#import "LDrawLine.h"
#import "LDrawMetaCommand.h"
#import "LDrawPart.h"
#import "LDrawQuadrilateral.h"
#import "LDrawTexture.h"
#import "LDrawTriangle.h"
#import "LDrawVertexes.h"
#import "PartLibrary.h"

static LDrawVertexes        *boundingCube       = nil;
static BOOL                 ColumnizesOutput    = NO;
static NSString				*defaultAuthor		= @"anonymous";

@implementation LDrawUtilities

#pragma mark -
#pragma mark CONFIGURATION
#pragma mark -

//---------- defaultAuthor -------------------------------------------[static]--
//------------------------------------------------------------------------------
+ (NSString *) defaultAuthor
{
	return defaultAuthor;
}


#pragma mark -

//---------- setColumnizesOutput: ------------------------------------[static]--
//
// Purpose:		Sets whether certain variable-width fields will be padded to 
//				make them all the same size in outputted files. 
//
// Notes:		Historically, LDraw programs truncate numbers as much as 
//				possible and insert exactly one space in between: 
//					4 16 -40 0 -20 -40 24 -20 40 24 -20 40 0 -20
//					4 16 40 0 20 40 24 20 -40 24 20 -40 0 20
//
//				Bricksmith 1.0 - 2.3 instead formatted the output into columns 
//				for easy readability, like so: 
//					4  16   -40.000000     0.000000   -20.000000   -40.000000    24.000000   -20.000000    40.000000    24.000000   -20.000000    40.000000     0.000000   -20.000000
//					4  16    40.000000     0.000000    20.000000    40.000000    24.000000    20.000000   -40.000000    24.000000    20.000000   -40.000000     0.000000    20.000000
//
//				But LDraw traditionalists hated that.
//
//				This method checks preferences to see which format is specified 
//				and outputs the chosen format. The result may be concatenated 
//				together with exactly one space; the columnizable string will 
//				already contain the necessary padding spaces. 
//
//------------------------------------------------------------------------------
+ (void) setColumnizesOutput:(BOOL)flag
{
	ColumnizesOutput = flag;
}


//---------- setDefaultAuthor: ---------------------------------------[static]--
//
// Purpose:		Sets the default author name used in new models.
//
//------------------------------------------------------------------------------
+ (void) setDefaultAuthor:(NSString *)nameIn
{
    // LLW: If the incoming nameIn is nil, leave this alone.
    if (nameIn != nil)
    {
        [nameIn retain];
        [defaultAuthor release];
        defaultAuthor = nameIn;
    }
}


#pragma mark -
#pragma mark PARSING
#pragma mark -

//---------- classForDirectiveBeginningWithLine: ---------------------[static]--
//
// Purpose:		Allows initializing the right kind of class based on the code 
//				found at the beginning of an LDraw line.
//
//------------------------------------------------------------------------------
+ (Class) classForDirectiveBeginningWithLine:(NSString *)line
{
	Class       classForType        = Nil;
	NSString    *commandCodeString  = nil;
	NSInteger   lineType            = 0;
	
	commandCodeString   = [LDrawUtilities readNextField:line remainder:NULL];
	//We may need to check for nil here someday.
	lineType            = [commandCodeString integerValue];
	
	// The linecode (0, 1, 2, 3, 4, 5) identifies the type of command, and is 
	// always the first character in the line. 
	switch(lineType)
	{
		case 0:
		{
			if([LDrawTexture lineIsTextureBeginning:line])
				classForType = [LDrawTexture class];
			else
				classForType = [LDrawMetaCommand class];
		}	break;
			
		case 1:
			classForType = [LDrawPart class];
			break;
		case 2:
			classForType = [LDrawLine class];
			break;
		case 3:
			classForType = [LDrawTriangle class];
			break;
		case 4:
			classForType = [LDrawQuadrilateral class];
			break;
		case 5:
			classForType = [LDrawConditionalLine class];
			break;
		default:
			NSLog(@"unrecognized LDraw line type: %ld", (long)lineType);
	}
	
	return classForType;
	
}//end classForDirectiveBeginningWithLine:


//---------- parseColorFromField: ------------------------------------[static]--
//
// Purpose:		Returns the color code which is represented by the field.
//
// Notes:		This supports a nonstandard but fairly widely-supported 
//				extension which allows arbitrary RGB values to be specified in 
//				place of color codes. (MLCad, L3P, LDView, and others support 
//				this.) 
//
//------------------------------------------------------------------------------
+ (LDrawColor *) parseColorFromField:(NSString *)colorField
{
	NSScanner   *scanner        = [NSScanner scannerWithString:colorField];
	LDrawColorT colorCode       = LDrawColorBogus;
	unsigned    hexBytes        = 0;
	int         customCodeType  = 0;
	GLfloat     components[4]   = {};
	LDrawColor	*color			= nil;

	// Custom RGB?
	if([scanner scanString:@"0x" intoString:nil] == YES)
	{
		// The integer should be of the format:
		// 0x2RRGGBB for opaque colors
		// 0x3RRGGBB for transparent colors
		// 0x4RGBRGB for a dither of two 12-bit RGB colors
		// 0x5RGBxxx as a dither of one 12-bit RGB color with clear (for transparency).

		[scanner scanHexInt:&hexBytes];
		customCodeType = (hexBytes >> 3*8) & 0xFF;
		
		switch(customCodeType)
		{
			// Solid color
			case 2:
				components[0] = (GLfloat) ((hexBytes >> 2*8) & 0xFF) / 255; // Red
				components[1] = (GLfloat) ((hexBytes >> 1*8) & 0xFF) / 255; // Green
				components[2] = (GLfloat) ((hexBytes >> 0*8) & 0xFF) / 255; // Blue
				components[3] = (GLfloat) 1.0; // alpha
				break;
			
			// Transparent color
			case 3:
				components[0] = (GLfloat) ((hexBytes >> 2*8) & 0xFF) / 255; // Red
				components[1] = (GLfloat) ((hexBytes >> 1*8) & 0xFF) / 255; // Green
				components[2] = (GLfloat) ((hexBytes >> 0*8) & 0xFF) / 255; // Blue
				components[3] = (GLfloat) 0.5; // alpha
				break;
			
			// combined opaque color
			case 4:
				components[0] = (GLfloat) (((hexBytes >> 5*4) & 0xF) + ((hexBytes >> 2*4) & 0xF))/2 / 255; // Red
				components[0] = (GLfloat) (((hexBytes >> 4*4) & 0xF) + ((hexBytes >> 1*4) & 0xF))/2 / 255; // Green
				components[0] = (GLfloat) (((hexBytes >> 3*4) & 0xF) + ((hexBytes >> 0*4) & 0xF))/2 / 255; // Blue
				components[3] = (GLfloat) 1.0; // alpha
				break;
				
			// bad-looking transparent color
			case 5:
				components[0] = (GLfloat) ((hexBytes >> 5*4) & 0xF) / 15; // Red
				components[0] = (GLfloat) ((hexBytes >> 4*4) & 0xF) / 15; // Green
				components[0] = (GLfloat) ((hexBytes >> 3*4) & 0xF) / 15; // Blue
				components[3] = (GLfloat) 0.5; // alpha
				break;
			
			default:
				break;
		}
		
		color = [[[LDrawColor alloc] init] autorelease];
		[color setColorCode:LDrawColorCustomRGB];
		[color setEdgeColorCode:LDrawBlack];
		[color setColorRGBA:components];
	}
	else
	{
		// Regular, standards-compliant LDraw color code
		colorCode   = [colorField intValue];
		color       = [[ColorLibrary sharedColorLibrary] colorForCode:colorCode];
		
		if(color == nil)
		{
			// This is probably a file-local color. Or a file from the future.
			color = [[[LDrawColor alloc] init] autorelease];
			[color setColorCode:colorCode];
			[color setEdgeColorCode:LDrawBlack];
		}
	}
		
	return color;
	
}//end parseColorFromField:


//---------- readNextField:remainder: --------------------------------[static]--
//
// Purpose:		Given the portion of the LDraw line, read the first available 
//				field. Fields are separated by whitespace of any length.
//
//				If remainder is not NULL, return by indirection the remainder of 
//				partialDirective after the first field has been removed. If 
//				there is no remainder, an empty string will be returned.
//
//				So, given the line
//				1 8 -150 -8 20 0 0 -1 0 1 0 1 0 0 3710.DAT
//
//				remainder will be set to:
//				 8 -150 -8 20 0 0 -1 0 1 0 1 0 0 3710.DAT
//
// Notes:		This method is incapable of reading field strings with spaces 
//				in them!
//
//				A case could be made to replace this method with an NSScanner!
//				They don't seem to be as adept at scanning in unknown string 
//				tags though, which would make them difficult to use to 
//				distinguish between "0 WRITE blah" and "0 COMMENT blah".
//
//------------------------------------------------------------------------------
+ (NSString *) readNextField:(NSString *) partialDirective
				   remainder:(NSString **) remainder
{
	NSCharacterSet	*whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSRange			 rangeOfNextWhiteSpace;
	NSString		*fieldContents			= nil;
	
	//First, remove any heading whitespace.
	partialDirective		= [partialDirective stringByTrimmingCharactersInSet:whitespaceCharacterSet];
	//Find the beginning of the next field separation
	rangeOfNextWhiteSpace	= [partialDirective rangeOfCharacterFromSet:whitespaceCharacterSet];
	
	//The text between the beginning and the next field separator is the first 
	// field (what we are after).
	if(rangeOfNextWhiteSpace.location != NSNotFound)
	{
		fieldContents = [partialDirective substringToIndex:rangeOfNextWhiteSpace.location];
		//See if they want the rest of the line, sans the field we just parsed.
		if(remainder != NULL)
			*remainder = [partialDirective substringFromIndex:rangeOfNextWhiteSpace.location];
	}
	else
	{
		//There was no subsequent field separator; we must be at the end of the line.
		fieldContents = partialDirective;
		if(remainder != NULL)
			*remainder = [NSString string];
	}
	
	return fieldContents;
}//end readNextField


//---------- scanQuotableToken: --------------------------------------[static]--
//
// Purpose:		Scans a field which allows embedded whitespace if the field is 
//				wrappend in double-quotes. Otherwise, leading whitespace is 
//				trimmed and the field ends at the first whitespace character. 
//
//------------------------------------------------------------------------------
+ (NSString *) scanQuotableToken:(NSScanner *)scanner
{
	NSCharacterSet	*doubleQuote	= [NSCharacterSet characterSetWithCharactersInString:@"\""];
	NSMutableString *token			= [NSMutableString string];
	NSString		*temp			= nil;
	
	if([scanner scanCharactersFromSet:doubleQuote intoString:NULL] == YES)
	{
		// String is wrapped in double quotes.
		// Watch out for embedded " characters, escaped as \"
		//                    and \ characters, escaped as \\        .
		
		[scanner scanUpToCharactersFromSet:doubleQuote intoString:&temp];
		[scanner scanCharactersFromSet:doubleQuote intoString:NULL];
		[token appendString:temp];
		while([token hasSuffix:@"\\"] == YES)
		{
			// Un-escape the \"
			[token deleteCharactersInRange:NSMakeRange([token length] - 1, 1)];
			[token appendString:@"\""];
			
			[scanner scanUpToCharactersFromSet:doubleQuote intoString:&temp];
			[scanner scanCharactersFromSet:doubleQuote intoString:NULL];
			[token appendString:temp];
		}
		
		// Un-escape backslashes
		[token replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:NSLiteralSearch range:NSMakeRange(0, [token length])];
	}
	else
	{
		// No leading quote mark
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&temp];
		[token appendString:temp];
	}
	
	return token;
	
}//end scanQuotableToken:


//---------- stringFromFile: -----------------------------------------[static]--
//
// Purpose:		Reads the contents of the file at the given path into a string. 
//
//------------------------------------------------------------------------------
+ (NSString *) stringFromFile:(NSString *)path
{
	NSData      *fileData   = [NSData dataWithContentsOfFile:path];
	NSString    *fileString = [self stringFromFileData:fileData];
	
	return fileString;
	
}//end stringFromFile:


//---------- stringFromFileData: -------------------------------------[static]--
//
// Purpose:		Reads the contents of the file with the given data into a 
//				string. We try a few different encodings. 
//
//------------------------------------------------------------------------------
+ (NSString *) stringFromFileData:(NSData *)fileData
{
	NSString    *fileString = nil;
	
	if(fileData)
	{
		// Try UTF-8 first, because it's so nice.
		fileString = [[NSString alloc] initWithData:fileData
										   encoding:NSUTF8StringEncoding ];
		
		// Uh-oh. Maybe Windows Latin?
		if(fileString == nil)
			fileString = [[NSString alloc] initWithData:fileData
											   encoding:NSISOLatin1StringEncoding ];
		
		// Yikes. Not even Windows. MacRoman will do it, even if it doesn't look 
		// right. 
		if(fileString == nil) 
			fileString = [[NSString alloc] initWithData:fileData
											   encoding:NSMacOSRomanStringEncoding ];
	}

	return [fileString autorelease];
	
}//end stringFromFileData:


#pragma mark -
#pragma mark WRITING
#pragma mark -

//---------- outputStringForColorCode:RGB: ---------------------------[static]--
//
// Purpose:		Returns the string representing the color code which should be 
//				written out in a file. 
//
// Notes:		This supports the non-standard custom RGB extension.
//
//------------------------------------------------------------------------------
+ (NSString *) outputStringForColor:(LDrawColor *)color
{
	NSString        *outputString   = nil;
	GLfloat			components[4]	= {};
	LDrawColorT		colorCode		= LDrawColorBogus;
	
	colorCode = [color colorCode];
	[color getColorRGBA:components];

	if(colorCode == LDrawColorCustomRGB)
	{
		// Opaque?
		if(components[3] == 1.0)
		{
			outputString = [NSString stringWithFormat:@"0x2%02X%02X%02X",
													   (uint8_t)(components[0] * 255),
													   (uint8_t)(components[1] * 255),
													   (uint8_t)(components[2] * 255) ];
		}
		else
		{
			outputString = [NSString stringWithFormat:@"0x3%02X%02X%02X",
													   (uint8_t)(components[0] * 255),
													   (uint8_t)(components[1] * 255),
													   (uint8_t)(components[2] * 255) ];
		}
	}
	else
	{
		if(ColumnizesOutput == YES)
		{
			outputString = [NSString stringWithFormat:@"%3d", colorCode];
		}
		else
		{
			outputString = [NSString stringWithFormat:@"%d", colorCode];
		}

	}
	
	return outputString;

}//end outputStringForColorCode:RGB:


//---------- outputStringForFloat: -----------------------------------[static]--
//
// Purpose:		Returns a formatted float appropriate for inserting into an 
//				LDraw file. 
//
//------------------------------------------------------------------------------
+ (NSString *) outputStringForFloat:(float)number
{
	NSString        *outputString   = nil;
	
	if(ColumnizesOutput == YES)
	{
		// Make a nice wide fixed-width string which will force the numbers into 
		// columns. 
		outputString = [NSString stringWithFormat:@"%12f", number];
	}
	else
	{
		// Remove all trailing zeroes (and the decimal point if an integer).
		
		char    formattedFloat[16]  = "";
		char    *endOfString        = NULL;
		size_t  fullLength          = 0;
		
		// First format the number into a string. We could wind up with 
		// something like "50.090000".
		snprintf(formattedFloat, sizeof(formattedFloat), "%f", number);
		fullLength  = strlen(formattedFloat);
		endOfString = &formattedFloat[fullLength - 1];
		
		// Back up past all the zeroes that may be at the end of the number
		while(*endOfString == '0')
		{
			endOfString--;
		}
		if(*endOfString != '.')
		{
			// We must be pointing at a non-zero digit, so lop off the 
			// subsequent character that is a zero. 
			endOfString++;
		}
		
		*endOfString = '\0';
		outputString = [NSString stringWithUTF8String:formattedFloat];
	}
	
	return outputString;

}//end outputStringForFloat:


#pragma mark -
#pragma mark DRAWING
#pragma mark -

//---------- boundingCube --------------------------------------------[static]--
//
// Purpose:		Returns a drawable unit cube which may be scaled to render 
//				bounding boxes using optimized OpenGL code. 
//
//------------------------------------------------------------------------------
+ (LDrawVertexes *) boundingCube
{
	if(boundingCube == nil)
	{
		// Create it for the first time.
		// It's easiest to co-opt existing LDraw objects for this.
		boundingCube = [[LDrawVertexes alloc] init];
		
		LDrawColor  *currentColor   = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor];
		Point3      vertices[8]     = {	
										V3Make(0, 0, 0),
										V3Make(0, 0, 1),
										V3Make(0, 1, 1),
										V3Make(0, 1, 0),
										
										V3Make(1, 0, 0),
										V3Make(1, 0, 1),
										V3Make(1, 1, 1),
										V3Make(1, 1, 0),
									  };

		LDrawQuadrilateral *side0 = [[LDrawQuadrilateral alloc] init];
		LDrawQuadrilateral *side1 = [[LDrawQuadrilateral alloc] init];
		LDrawQuadrilateral *side2 = [[LDrawQuadrilateral alloc] init];
		LDrawQuadrilateral *side3 = [[LDrawQuadrilateral alloc] init];
		LDrawQuadrilateral *side4 = [[LDrawQuadrilateral alloc] init];
		LDrawQuadrilateral *side5 = [[LDrawQuadrilateral alloc] init];
		
		[side0 setLDrawColor:currentColor];
		[side1 setLDrawColor:currentColor];
		[side2 setLDrawColor:currentColor];
		[side3 setLDrawColor:currentColor];
		[side4 setLDrawColor:currentColor];
		[side5 setLDrawColor:currentColor];
		
		[side0 setVertex1:vertices[0]];
		[side0 setVertex2:vertices[3]];
		[side0 setVertex3:vertices[2]];
		[side0 setVertex4:vertices[1]];
		
		[side1 setVertex1:vertices[0]];
		[side1 setVertex2:vertices[4]];
		[side1 setVertex3:vertices[7]];
		[side1 setVertex4:vertices[3]];
		
		[side2 setVertex1:vertices[3]];
		[side2 setVertex2:vertices[7]];
		[side2 setVertex3:vertices[6]];
		[side2 setVertex4:vertices[2]];
		
		[side3 setVertex1:vertices[2]];
		[side3 setVertex2:vertices[6]];
		[side3 setVertex3:vertices[5]];
		[side3 setVertex4:vertices[1]];
		
		[side4 setVertex1:vertices[1]];
		[side4 setVertex2:vertices[5]];
		[side4 setVertex3:vertices[4]];
		[side4 setVertex4:vertices[0]];
		
		[side5 setVertex1:vertices[4]];
		[side5 setVertex2:vertices[5]];
		[side5 setVertex3:vertices[6]];
		[side5 setVertex4:vertices[7]];
		
		[boundingCube addQuadrilateral:side0];
		[boundingCube addQuadrilateral:side1];
		[boundingCube addQuadrilateral:side2];
		[boundingCube addQuadrilateral:side3];
		[boundingCube addQuadrilateral:side4];
		[boundingCube addQuadrilateral:side5];
		
		[side0 release];
		[side1 release];
		[side2 release];
		[side3 release];
		[side4 release];
		[side5 release];
	}
	
	return boundingCube;
	
}//end boundingCube


#pragma mark -
#pragma mark HIT DETECTION
#pragma mark -

//---------- registerHitForObject:depth:creditObject:hits: -----------[static]--
//
// Purpose:		Adds a hit record to the hits dictionary such that only the 
//				nearest hits per credit object survive. 
//
// Parameters:	hitObject - the exact object whose geometry was hit
//				depth - the distance in the depth of field
//				creditObject - an object to which the hit should be attributed 
//						(instead of the hitObject itself) 
//				hits - the list of hit records to modify
//
//------------------------------------------------------------------------------
+ (void) registerHitForObject:(id)hitObject depth:(float)hitDepth creditObject:(id)creditObject hits:(NSMutableDictionary *)hits
{
	NSNumber    *existingRecord = [hits objectForKey:creditObject];
	float       existingDepth   = 0;
	NSValue     *key            = nil;
	
	// NSDictionary copies its keys (which we don't want to do!), so we'll just 
	// wrap the pointers. 
	if(creditObject == nil)
	{
		key = [NSValue valueWithPointer:hitObject];
	}
	else
	{
		key = [NSValue valueWithPointer:creditObject];
	}

	existingRecord = [hits objectForKey:key];
	if(existingRecord == nil)
	{
		existingDepth = INFINITY;
	}
	else
	{
		existingDepth = [existingRecord floatValue];
	}
	
	// Found a shallower intersection point? Record the hit.
	if(hitDepth < existingDepth)
	{
		[hits setObject:[NSNumber numberWithFloat:hitDepth] forKey:key];
	}
}

//---------- registerHitForObject:creditObject:hits: -----------------[static]--
//
// Purpose:		Same as above, but it adds its objects to a mutable set, 
//				and ignores depth.
//
// Parameters:	hitObject - the exact object whose geometry was hit
//				creditObject - an object to which the hit should be attributed 
//						(instead of the hitObject itself) 
//				hits - the hit set
//
//------------------------------------------------------------------------------
+ (void) registerHitForObject:(id)hitObject creditObject:(id)creditObject hits:(NSMutableSet *)hits
{
	NSValue     *key            = nil;
	
	// NSDictionary copies its keys (which we don't want to do!), so we'll just 
	// wrap the pointers. 
	if(creditObject == nil)
	{
		key = [NSValue valueWithPointer:hitObject];
	}
	else
	{
		key = [NSValue valueWithPointer:creditObject];
	}

	[hits addObject:key];

}


#pragma mark -
#pragma mark IMAGES
#pragma mark -

//---------- imageAtPath: --------------------------------------------[static]--
//
// Purpose:		Creates an image from the file at the given path.
//
//------------------------------------------------------------------------------
+ (CGImageRef) imageAtPath:(NSString *)imagePath
{
	NSURL				*fileURL	= nil;
	CGImageSourceRef	imageSource = NULL;
	CGImageRef			image		= NULL;
	
	if(imagePath)
	{
		fileURL	= [NSURL fileURLWithPath:imagePath];

		imageSource = CGImageSourceCreateWithURL( (CFURLRef)fileURL, NULL );
		if(imageSource != NULL)
		{
			image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
		}
	}
	
	if(imageSource) CFRelease(imageSource);
	
	return (CGImageRef)[(id)image autorelease];
}


#pragma mark -
#pragma mark MISCELLANEOUS
#pragma mark -
//This is stuff that didn't really go anywhere else.

//---------- angleForViewOrientation: --------------------------------[static]--
//
// Purpose:		Returns the viewing angle in degrees for the given orientation.
//
//------------------------------------------------------------------------------
+ (Tuple3) angleForViewOrientation:(ViewOrientationT)orientation
{
	Tuple3 angle	= ZeroPoint3;
	
	switch(orientation)
	{
		case ViewOrientation3D:
			// This is MLCad's default 3-D viewing angle, which is arrived at by 
			// applying these rotations in order: z=0, y=45, x=23. 
			angle = V3Make(30.976, 40.609, 21.342);
			break;
			
		case ViewOrientationFront:
			angle = V3Make(0, 0, 0);
			break;
			
		case ViewOrientationBack:
			angle = V3Make(0, 180, 0);
			break;
			
		case ViewOrientationLeft:
			angle = V3Make(0, -90, 0);
			break;
			
		case ViewOrientationRight:
			angle = V3Make(0, 90, 0);
			break;
			
		case ViewOrientationTop:
			angle = V3Make(90, 0, 0);
			break;
			
		case ViewOrientationBottom:
			angle = V3Make(-90, 0, 0);
			break;
	}
	
	return angle;
	
}//end angleForViewOrientation:


//---------- boundingBox3ForDirectives: ------------------------------[static]--
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains all the given objects. (Only objects which 
//				respond to -boundingBox3 will be tested.)
//
// Notes:		This method used to live in LDrawContainer, which was a very 
//				nice place. But I moved it here so that other interested parties 
//				could do bounds testing on ad-hoc collections of directives.
//
//------------------------------------------------------------------------------
+ (Box3) boundingBox3ForDirectives:(NSArray *)directives
{
	Box3        bounds              = InvalidBox;
	Box3        partBounds          = InvalidBox;
	id          currentDirective    = nil;
	NSUInteger  numberOfDirectives  = [directives count];
	NSUInteger  counter             = 0;
	
	for(counter = 0; counter < numberOfDirectives; counter++)
	{
		currentDirective = [directives objectAtIndex:counter];
//		if([currentDirective respondsToSelector:@selector(boundingBox3)])
		{
			partBounds	= [currentDirective boundingBox3];
			bounds		= V3UnionBox(bounds, partBounds);
		}
	}
	
	return bounds;
	
}//end boundingBox3ForDirectives


//---------- isLDrawFilenameValid: -----------------------------------[static]--
//
// Purpose:		The LDraw File Specification defines what makes a valid LDraw 
//				file name: http://www.ldraw.org/Article218.html#files 
//
//				Alas, these rules suck in MPD names too, thanks to the wording 
//				on Linetype 1 in the spec. 
//
// Notes:		The spec also has disparaging things to say about whitespace and 
//				special characters in filenames. To the spec I say: join the 
//				1990s. 
//
//------------------------------------------------------------------------------
+ (BOOL) isLDrawFilenameValid:(NSString *)fileName
{
	NSString	*extension	= [fileName pathExtension];
	BOOL		isValid		= NO;
	
	// Make sure it has a valid extension
	if(		extension == nil
	   ||	(	[extension isEqualToString:@"ldr"] == NO
			 &&	[extension isEqualToString:@"dat"] == NO )
	   )
	{
		isValid = NO;
	}
	else
		isValid = YES;
		
	return isValid;
	
}//end isLDrawFilenameValid:


//---------- updateNameForMovedPart: ---------------------------------[static]--
//
// Purpose:		If the specified part has been moved to a new number/name by 
//				LDraw.org, this method will update the part name to point to the 
//				new location.
//
//				Example:
//					193.dat (~Moved to 193a) becomes 193a.dat
//
//------------------------------------------------------------------------------
+ (void) updateNameForMovedPart:(LDrawPart *)movedPart
{
	NSString	*description	= [[PartLibrary sharedPartLibrary] descriptionForPart:movedPart];
	NSString	*newName		= nil;
	
	if([description hasPrefix:LDRAW_MOVED_DESCRIPTION_PREFIX])
	{
		//isolate the new number and add the .dat library suffix.
		newName = [description substringFromIndex:[LDRAW_MOVED_DESCRIPTION_PREFIX length]];
		newName = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		newName = [newName stringByAppendingString:@".dat"];
		
		[movedPart setDisplayName:newName];
	}
	
}//end updateNameForMovedPart:


//---------- viewOrientationForAngle: --------------------------------[static]--
//
// Purpose:		Returns the viewing orientation for the given angle. If the 
//				angle is not a recognized head-on view, ViewOrientation3D will 
//				be returned. 
//
//------------------------------------------------------------------------------
+ (ViewOrientationT) viewOrientationForAngle:(Tuple3)rotationAngle
{
	ViewOrientationT    viewOrientation     = ViewOrientation3D;
	NSUInteger          counter             = 0;
	Tuple3              testAngle           = ZeroPoint3;
	ViewOrientationT    testOrientation     = ViewOrientation3D;
	
	ViewOrientationT    orientations[]      = {	ViewOrientationFront,
		ViewOrientationBack,
		ViewOrientationLeft,
		ViewOrientationRight,
		ViewOrientationTop,
		ViewOrientationBottom
	};
	NSUInteger          orientationCount    = sizeof(orientations)/sizeof(ViewOrientationT);
	
	// See if the angle matches any of the head-on orientations.
	for(counter = 0; viewOrientation == ViewOrientation3D && counter < orientationCount; counter++)
	{
		testOrientation	= orientations[counter];
		testAngle		= [LDrawUtilities angleForViewOrientation:testOrientation];
		
		if( V3PointsWithinTolerance(rotationAngle, testAngle) == YES )
			viewOrientation = testOrientation;
	}
	
	return viewOrientation;
	
}//end viewOrientationForAngle:



//---------- unresolveLibraryParts: ----------------------------------[static]--
//
// Purpose:		This routine walks a directive tree and sends
//				unresolvePartIfPartLibrary to any parts it finds.  This has the
//				result of causing all parts to drop their weak reference to the
//				library.
//
//------------------------------------------------------------------------------
+ (void) unresolveLibraryParts:(LDrawDirective *) directive
{
	if ([directive respondsToSelector:@selector(allEnclosedElements)])
	{
		NSArray * subs = [directive allEnclosedElements];		
		for (LDrawDirective * d in subs)
		{
			[self unresolveLibraryParts:d];
		}
	}
	
	if([directive respondsToSelector:@selector(unresolvePartIfPartLibrary)])
		[directive unresolvePartIfPartLibrary];
}//end unresolveLibraryParts


@end
