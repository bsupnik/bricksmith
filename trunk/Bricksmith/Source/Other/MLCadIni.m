//==============================================================================
//
// File:		MLCadIni.m
//
// Purpose:		Parses the contents of LDraw/MLCad.ini, the file which defines 
//				settings for the minifigure generator.
//
//				MLCad.ini  has the following basic syntax:
//				
//				; comment
//
//				[SECTION]
//				; (section-dependent syntax)
//
//				The file is maintained independently of this project at 
//				www.holly-wood.it/mlcad-en.html. It was originally designed for 
//				the Windows-based LDraw tool MLCad; I simply appropriated it.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "MLCadIni.h"

#import "LDrawColor.h"
#import "LDrawPart.h"
#import "LDrawPaths.h"
#import "LDrawUtilities.h"

#import "MacLDraw.h"
#import "StringCategory.h"

//---------- Section Headers ---------------------------------------------------
// a section header in MLCad.ini is enclosed in brackets (i.e., [HATS])

// - Minifigure generator
#define MLCAD_SECTION_LSYNTH							@"LSYNTH"
#define MLCAD_SECTION_MINIFIGURE_HATS					@"HATS"
#define MLCAD_SECTION_MINIFIGURE_HEAD					@"HEAD"
#define MLCAD_SECTION_MINIFIGURE_TORSO					@"BODY"
#define MLCAD_SECTION_MINIFIGURE_PELVIS					@"BODY2"
#define MLCAD_SECTION_MINIFIGURE_NECK					@"NECK"
#define MLCAD_SECTION_MINIFIGURE_ARM_LEFT				@"RARM"
#define MLCAD_SECTION_MINIFIGURE_ARM_RIGHT				@"LARM"
#define MLCAD_SECTION_MINIFIGURE_HAND_LEFT				@"RHAND"   //MLCad's left is the minifigure's right!
#define MLCAD_SECTION_MINIFIGURE_HAND_LEFT_ACCESSORY	@"RHANDA"
#define MLCAD_SECTION_MINIFIGURE_HAND_RIGHT				@"LHAND"
#define MLCAD_SECTION_MINIFIGURE_HAND_RIGHT_ACCESSORY	@"LHANDA"
#define MLCAD_SECTION_MINIFIGURE_LEG_LEFT				@"RLEG"
#define MLCAD_SECTION_MINIFIGURE_LEG_LEFT_ACCESSORY		@"RLEGA"
#define MLCAD_SECTION_MINIFIGURE_LEG_RIGHT				@"LLEG"
#define MLCAD_SECTION_MINIFIGURE_LEG_RIGHT_ACCESSORY	@"LLEGA"          

@implementation MLCadIni

static MLCadIni *sharedIniFile = nil;

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- iniFile -------------------------------------------------[static]--
//
// Purpose:		Parses the MLCad.ini file at the standard location (installing 
//				it if necessary) and returns an object containing all the known
//				information therein.
//
//------------------------------------------------------------------------------
+ (MLCadIni *) iniFile
{
	MLCadIni	*mlcadini	= nil;
	NSString	*filePath	= nil;
	
	//only parse MLCad.ini once; future invocations will just reuse the shared 
	// object.
	if(sharedIniFile == nil)
	{
		mlcadini	= [MLCadIni new];
		filePath	= [[LDrawPaths sharedPaths] MLCadIniPath];
		
		[mlcadini parseFromPath:filePath];
		
		sharedIniFile = mlcadini;
	}
	else
		mlcadini = sharedIniFile;
	
	return mlcadini;
	
}//end iniFile

//========== init ==============================================================
//
// Purpose:		Creates an empty, unparsed MLCad.ini database.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	//these are mutable simply so I can fill them easier. Their mutability is 
	// not exposed via the accessors.
	minifigureHats					= [[NSMutableArray alloc] init];
	minifigureHeads					= [[NSMutableArray alloc] init];
	minifigureTorsos				= [[NSMutableArray alloc] init];
	minifigureHips					= [[NSMutableArray alloc] init];
	minifigureNecks					= [[NSMutableArray alloc] init];
	minifigureArmsLeft				= [[NSMutableArray alloc] init];
	minifigureArmsRight				= [[NSMutableArray alloc] init];
	minifigureHandsLeft				= [[NSMutableArray alloc] init];
	minifigureHandsLeftAccessories	= [[NSMutableArray alloc] init];
	minifigureHandsRight			= [[NSMutableArray alloc] init];
	minifigureHandsRightAccessories	= [[NSMutableArray alloc] init];
	minifigureLegsLeft				= [[NSMutableArray alloc] init];
	minifigureLegsLeftAcessories	= [[NSMutableArray alloc] init];
	minifigureLegsRight				= [[NSMutableArray alloc] init];
	minifigureLegsRightAccessories	= [[NSMutableArray alloc] init];

	return self;
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== lsynthVisibleTypes ================================================
//
// Purpose:		Returns the type names of LSynth elements which we should show 
//				in the UI. The LSynth.mpd configuration file includes 
//				definitions for a number of deprecated names that we don't want 
//				to show, so this list should be the authoritative filter.
//
//==============================================================================
- (NSArray *) lsynthVisibleTypes
{
	return lsynthVisibleTypes;
}

//========== minifigureHats ====================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHats
{
	return minifigureHats;
	
}//end minifigureHats


//========== minifigureHeads ===================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHeads
{
	return minifigureHeads;
	
}//end minifigureHeads


//========== minifigureNecks ===================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureNecks
{
	return minifigureNecks;
	
}//end minifigureNecks


//========== minifigureTorsos ==================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureTorsos
{
	return minifigureTorsos;
	
}//end minifigureTorsos


//========== minifigureHips ====================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHips
{
	return minifigureHips;
	
}//end minifigureHips


//========== minifigureArmsLeft ================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureArmsLeft
{
	return minifigureArmsLeft;
	
}//end minifigureArmsLeft


//========== minifigureArmsRight ===============================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureArmsRight
{
	return minifigureArmsRight;
	
}//end minifigureArmsRight


//========== minifigureHandsLeft ===============================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHandsLeft
{
	return minifigureHandsLeft;
	
}//end minifigureHandsLeft


//========== minifigureHandsLeftAccessories ====================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHandsLeftAccessories
{
	return minifigureHandsLeftAccessories;
	
}//end minifigureHandsLeftAccessories


//========== minifigureHandsRight ==============================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHandsRight
{
	return minifigureHandsRight;
	
}//end minifigureHandsRight


//========== minifigureHandsRightAccessories ===================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureHandsRightAccessories
{
	return minifigureHandsRightAccessories;
	
}//end minifigureHandsRightAccessories


//========== minifigureLegsLeft ================================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureLegsLeft
{
	return minifigureLegsLeft;
	
}//end minifigureLegsLeft


//========== minifigureLegsLeftAcessories ======================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureLegsLeftAcessories
{
	return minifigureLegsLeftAcessories;
	
}//end minifigureLegsLeftAcessories


//========== minifigureLegsRight ===============================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureLegsRight
{
	return minifigureLegsRight;
	
}//end minifigureLegsRight


//========== minifigureLegsRightAccessories ====================================
//
// Purpose:		Returns the specified list of parts for the minifigure 
//				generator.
//
//==============================================================================
- (NSArray *) minifigureLegsRightAccessories
{
	return minifigureLegsRightAccessories;
	
}//end minifigureLegsRightAccessories


#pragma mark -

//========== armAngleForTorsoName: =============================================
//
// Purpose:		Returns the absolute value of the angle at which arms should be 
//				rotated in order to fit on the torso.
//
// Notes:		If I had my way, this information would be part of MLCad.ini so 
//				I didn't need to do this cheezy hard-coding.
//
//==============================================================================
- (float) armAngleForTorsoName:(NSString *)torsoName
{
	// Mechanical torso. No arm rotation
	if(		[torsoName isEqualToString:@"30375.dat"] == YES
	   ||	[torsoName isEqualToString:@"54275.dat"] == YES)
	{
		return 0.0;
	}
	else
	{
		// Regular torso. 
		//		-- this value is derived from a little trig on the torso surface.
		return 9.791;
	}
		
}//end armAngleForTorsoName:


#pragma mark -

//========== setParts:intoMinifigurePartList: ==================================
//
// Purpose:		Assigns the partList variable to the new list of parts.
//
// Notes:		This is me being lazy rather than writing 15 set-methods that 
//				all do exactly the same thing.
//
//==============================================================================
- (void)			setParts:(NSArray *)parts
	  intoMinifigurePartList:(NSMutableArray *)partList
{
	[partList removeAllObjects];
	[partList addObjectsFromArray:parts];
	
}//end setParts:intoMinifigurePartList:


#pragma mark -
#pragma mark PARSING
#pragma mark -

//========== parseFromPath: ====================================================
//
// Purpose:		Reads the MLCad.ini file at the given path.
//
//==============================================================================
- (void) parseFromPath:(NSString *) path
{
	NSString		*fileString 		= [LDrawUtilities stringFromFile:path];
	NSArray 		*rawLines			= [fileString separateByLine];
	NSDictionary	*sections			= 0;
	
	NSDictionary	*listsForSections	= nil;
	NSArray 		*sectionKeys		= nil;
	NSString		*currentSectionKey	= nil;
	NSArray 		*sectionLines		= nil;
	NSArray 		*sectionParts		= nil;
	
	//---------- cull out all the comments and blank lines ---------------------
	
	sections = [self sectionsFromLines:rawLines];

	
	//---------- Parse Minifigure Sections -------------------------------------

					//this array associates the key for each section with the list 
					// into which its parts should be stored.
	listsForSections = [NSDictionary dictionaryWithObjectsAndKeys:
						minifigureHats,						MLCAD_SECTION_MINIFIGURE_HATS,
						minifigureHeads,					MLCAD_SECTION_MINIFIGURE_HEAD,
						minifigureTorsos,					MLCAD_SECTION_MINIFIGURE_TORSO,
						minifigureHips,						MLCAD_SECTION_MINIFIGURE_PELVIS,
						minifigureNecks,					MLCAD_SECTION_MINIFIGURE_NECK,
						minifigureArmsLeft,					MLCAD_SECTION_MINIFIGURE_ARM_LEFT,
						minifigureArmsRight,				MLCAD_SECTION_MINIFIGURE_ARM_RIGHT,
						minifigureHandsLeft,				MLCAD_SECTION_MINIFIGURE_HAND_LEFT,
						minifigureHandsLeftAccessories,		MLCAD_SECTION_MINIFIGURE_HAND_LEFT_ACCESSORY,
						minifigureHandsRight,				MLCAD_SECTION_MINIFIGURE_HAND_RIGHT,
						minifigureHandsRightAccessories,	MLCAD_SECTION_MINIFIGURE_HAND_RIGHT_ACCESSORY,
						minifigureLegsLeft,					MLCAD_SECTION_MINIFIGURE_LEG_LEFT,
						minifigureLegsLeftAcessories,		MLCAD_SECTION_MINIFIGURE_LEG_LEFT_ACCESSORY,
						minifigureLegsRight,				MLCAD_SECTION_MINIFIGURE_LEG_RIGHT,
						minifigureLegsRightAccessories,		MLCAD_SECTION_MINIFIGURE_LEG_RIGHT_ACCESSORY,
						nil	];
	sectionKeys		= [listsForSections allKeys];
	
	for(currentSectionKey in sectionKeys)
	{
		sectionLines		= [sections objectForKey:currentSectionKey];
		sectionParts		= [self partsFromMinifigureLines:sectionLines];
		
		[self				setParts:sectionParts
			  intoMinifigurePartList:[listsForSections objectForKey:currentSectionKey]];
	}
	
	//---------- Parse LSynth Section ------------------------------------------
	
	sectionLines = [sections objectForKey:MLCAD_SECTION_LSYNTH];
	self->lsynthVisibleTypes = [self lsynthTypesFromLines:sectionLines];

}//end parseFromPath:


#pragma mark -

//========== sectionsFromLines: ================================================
//
// Purpose:		Returns a dictionary with each section name as a keys, and lines 
//				as values.
//
//==============================================================================
- (NSDictionary *) sectionsFromLines:(NSArray *)lines
{
	NSString			*currentLine			= nil;
	NSCharacterSet		*whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString			*currentSectionName 	= nil;
	NSMutableArray		*currentSectionLines	= nil;
	NSMutableDictionary *sections				= [NSMutableDictionary dictionary];
	
	for(currentLine in lines)
	{
		// cull out all the comments and blank lines
		currentLine = [currentLine stringByTrimmingCharactersInSet:whitespaceCharacterSet];
		if([currentLine length] > 0 && [currentLine hasPrefix:@";"] == NO)
		{
			//once we pass the start of the section, start including lines.
			if([currentLine hasPrefix:@"["])
			{
				// Finish previous section
				if(currentSectionName)
					[sections setObject:currentSectionLines forKey:currentSectionName];
				
				// Start new section
				NSScanner *scanner = [NSScanner scannerWithString:currentLine];
				[scanner scanString:@"[" intoString:NULL];
				[scanner scanUpToString:@"]" intoString:&currentSectionName];
				currentSectionLines = [NSMutableArray array];
			}
			else
			{
				[currentSectionLines addObject:currentLine];
			}
		}
	}
	
	// Finish last section
	if(currentSectionName)
		[sections setObject:currentSectionLines forKey:currentSectionName];
	
	return sections;
}


//========== lsynthTypesFromLines: =============================================
//
// Purpose:		Reads LSynth types out of the LSynth info block. Lines have the 
//				following format: 
//				02 - ELECTRIC_NXT_CABLE = SYNTH BEGIN ELECTRIC_NXT_CABLE 16
//
//				We return the type name after SYNTH BEGIN.
//
// Notes:		There are a few other things in the MLCad.ini [LSYNTH] section 
//				that we don't care about. This method current returns only those 
//				lines which start with a number, denoting supported synthesis 
//				types.
//
//==============================================================================
- (NSArray *) lsynthTypesFromLines:(NSArray *)lines
{
	NSMutableArray	*namesInList	= [NSMutableArray arrayWithCapacity:[lines count]];
	NSString		*currentLine	= nil;
	NSScanner		*scanner		= nil;
	NSInteger		typeNumber		= 0;
	NSString		*displayName	= nil;
	NSString		*actualName 	= nil;
	NSCharacterSet	*whitespaceSet	= [NSCharacterSet whitespaceCharacterSet];
	BOOL			success 		= NO;
	
	for(currentLine in lines)
	{
		scanner		= [NSScanner scannerWithString:currentLine];
		
		success = [scanner scanInteger:&typeNumber];
		if(success)
		{
			success = [scanner scanString:@"-" intoString:NULL];
			success = [scanner scanUpToCharactersFromSet:whitespaceSet intoString:&displayName];
			success = [scanner scanString:@"= SYNTH BEGIN" intoString:NULL];
			if(success) // ignore 00 - VERSION 3.1 line
			{
				[scanner scanUpToCharactersFromSet:whitespaceSet intoString:&actualName];
				
				[namesInList addObject:actualName];
			}
		}
	}
	
	return namesInList;
	
}//end lsynthTypesFromLines:


//========== partsFromMinifigureLines: =========================================
//
// Purpose:		Reads LDrawParts out of an array of strings specifying elements 
//				for MLCad's minifigure generator. 
//
//				Each line has the following format:
//				"<Display name>" "<DAT/LDR file name>" <Flags> <Matrix> <Offset>
//
//				<Display name>		The name of the element as it is displayed 
//									in the element list. Bricksmith ignores this 
//									name!
//				<DAT/LDR file name>	The file name of the element or "" for 
//									hidden element 
//				<Flags>				always 0 reserved for future use
//				<Matrix>			a rotation matrix a11 a12 a13 ... a33 for 
//									optimal appearance at 0 degree rotation angle
//				<Offset>			The offset of the part to be in place
//
// Note:		The position of the matrix and the offset is reversed from the 
//				standard order of a type 1 part line.
//
//==============================================================================
- (NSArray *) partsFromMinifigureLines:(NSArray *)lines
{
	NSMutableArray	*parts			= [NSMutableArray arrayWithCapacity:[lines count]];
	NSMutableArray	*namesInList	= [NSMutableArray arrayWithCapacity:[lines count]];
	NSString		*currentLine	= nil;
	NSScanner		*scanner		= nil;
	
	NSString		*partName		= nil;
	NSString		*flags			= nil;
	Matrix4			transformation  = IdentityMatrix4;
	LDrawPart		*currentPart	= nil;
	
	NSCharacterSet	*quoteSet		= [NSCharacterSet characterSetWithCharactersInString:@"\""];
	NSCharacterSet	*whitespaceSet	= [NSCharacterSet whitespaceCharacterSet];
	NSUInteger		lineCount		= [lines count];
	BOOL			gotName			= NO;
	NSUInteger		counter			= 0;
	
	for(counter = 0; counter< lineCount; counter++)
	{
		//---------- Extract the textual part info -----------------------------
		
		currentLine	= [lines objectAtIndex:counter];
		scanner		= [NSScanner scannerWithString:currentLine];
		
		//skip the display name. We just don't care.
		[scanner scanUpToCharactersFromSet:quoteSet intoString:NULL];
		[scanner scanString:@"\""					intoString:NULL];
		[scanner scanUpToCharactersFromSet:quoteSet intoString:NULL];
		[scanner scanString:@"\""					intoString:NULL]; //so we scan "" as two separate characters
		
		//scan the part name, skipping the first quote.
		[scanner scanUpToCharactersFromSet:quoteSet intoString:NULL];
		[scanner scanString:@"\""					intoString:NULL];
		gotName = [scanner scanUpToCharactersFromSet:quoteSet intoString:&partName];
		[scanner scanString:@"\""					intoString:NULL];
		
		//skip the flags; they don't mean anything yet anyway
		[scanner scanUpToCharactersFromSet:whitespaceSet intoString:&flags];
		
		//the rest is the transformation matrix, but in a different order from 
		// an LDraw type 1 part line.
		[scanner scanFloat:&transformation.element[0][0]];
		[scanner scanFloat:&transformation.element[1][0]];
		[scanner scanFloat:&transformation.element[2][0]];
		[scanner scanFloat:&transformation.element[0][1]];
		[scanner scanFloat:&transformation.element[1][1]];
		[scanner scanFloat:&transformation.element[2][1]];
		[scanner scanFloat:&transformation.element[0][2]];
		[scanner scanFloat:&transformation.element[1][2]];
		[scanner scanFloat:&transformation.element[2][2]];

		[scanner scanFloat:&transformation.element[3][0]];
		[scanner scanFloat:&transformation.element[3][1]];
		[scanner scanFloat:&transformation.element[3][2]];
		
		
		//---------- Create an LDrawPart for the line --------------------------
		
		// Some entries have an empty string for a part name. Stupidly, NSScanner 
		// only indicates this by returning NO when scanning through ""; the 
		// string pointer still points to whatever it did before the scan call.
		// In any event, we want to discard these non-entries.
		if(gotName == YES)
		{
			currentPart = [[LDrawPart alloc] init];
			
			[currentPart setTransformationMatrix:&transformation];
			[currentPart setDisplayName:partName parse:NO inGroup:NULL];
		
			if(currentPart != nil)
			{
				//add the part-- but don't allow duplicate names, even if they 
				// are specified in the ini file. Not only is it bad form, but 
				// it seriously messes up binding the array to an NSPopUpButton, 
				// which filters out identically-named menu items.
				if([namesInList containsObject:[currentPart referenceName]] == NO)
				{
					[parts			addObject:currentPart];
					[namesInList	addObject:[currentPart referenceName]];
				}
				else
					NSLog(@"%@ %@ is already in the list", [currentPart referenceName], [currentPart browsingDescription]);
			}
		}
	}
	
	//---------- Sort list by part name ----------------------------------------
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"browsingDescription" ascending:YES];
	[parts sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	return parts;
	
}//end partsFromMinifigureLines:


@end
