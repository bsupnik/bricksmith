//==============================================================================
//
// File:		LDrawMPDModel.m
//
// Purpose:		LDraw MPD (Multi-Part Document) models are the basic components 
//				of an LDrawFile. An MPD model is a discreet collection of parts 
//				(such as a car or a minifigure); each file can be composed of 
//				multiple models.
//
//				An MPD model is an extension of a basic LDraw model, with the 
//				addition of a name which can be used to refer to the entire 
//				model as a single part. (This is used, for instance, to insert 
//				the entire minifigure driver into his car.)
//
//				While the LDraw file format accommodates documents with only one 
//				(non-MPD) model, Bricksmith does not make such a distinction 
//				until the file is actually written to disk. For the sake of 
//				simplicity, all logical models within an LDrawFile *must* be 
//				MPD models.
//				
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawMPDModel.h"

#import "LDrawFile.h"
#import "LDrawKeywords.h"
#import "LDrawUtilities.h"
#import "StringCategory.h"


@implementation LDrawMPDModel

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- model ---------------------------------------------------[static]--
//
// Purpose:		Creates a new model ready to be edited.
//
//------------------------------------------------------------------------------
+ (id) model
{
	LDrawMPDModel   *newModel   = [super model];
	NSString        *name       = nil;
	
	// Set the spec-compliant model name with extension
	name = NSLocalizedString(@"UntitledModel", nil);
	[newModel setModelDisplayName:name];
	
	return newModel;
	
}//end model


//========== init ==============================================================
//
// Purpose:		Creates a blank submodel.
//
//==============================================================================
- (id) init
{
	[super init];
	
	modelName = @"";
	
	return self;
	
}//end init


//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Creates a new model file based on the lines from a file.
//				These lines of strings should only describe one model, not 
//				multiple ones.
//
//				The first line does not need to be an MPD file delimiter. If 
//				you pass in a non-mpd submodel, this method simply wraps it in 
//				an MPD submodel object.
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString	*mpdFileCommand 	= [lines objectAtIndex:range.location];
	NSString	*lastLine			= nil;
	NSString	*mpdSubmodelName	= @"";
	BOOL		isMPDModel			= NO;
	BOOL		hasSubmodelEnd		= NO;
	NSRange 	nonMPDRange 		= range;

	// The first line should be 0 FILE modelName
	isMPDModel = [[self class] lineIsMPDModelStart:mpdFileCommand modelName:&mpdSubmodelName];
	
	// Strip out the MPD commands for model parsing, and read in the model name.
	if(isMPDModel == YES)
	{
		// Strip out the first line and the NOFILE command, if there is one.
		lastLine = [lines lastObject];
		
		hasSubmodelEnd = [[self class] lineIsMPDModelEnd:lastLine];
		if(hasSubmodelEnd)
		{
			// strip out 0 FILE and 0 NOFILE
			nonMPDRange = NSMakeRange(range.location + 1, range.length - 2);
		}
		else
		{
			// strip out 0 FILE only
			nonMPDRange = NSMakeRange(range.location + 1, range.length - 1);
		}
	}
	else
	{
		nonMPDRange = range;
	}

	// Create a basic model.
	[super initWithLines:lines inRange:nonMPDRange parentGroup:parentGroup]; //parses model into header and steps.
	
	// If it wasn't MPD, we still need a model name. We can get that via the 
	// parsed model.
	if(isMPDModel == NO)
	{
		mpdSubmodelName = [self modelDescription];
	}

	// And now set the MPD-specific attributes.
	[self setModelName:mpdSubmodelName];
	
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
	self = [super initWithCoder:decoder];
	
	modelName = [[decoder decodeObjectForKey:@"modelName"] retain];
	
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
	
	[encoder encodeObject:modelName forKey:@"modelName"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawMPDModel	*copied	= (LDrawMPDModel *)[super copyWithZone:zone];
	
	[copied setModelName:[self modelName]];
	
	return copied;
	
}//end copyWithZone:


#pragma mark -

//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
//
// Purpose:		Returns the range from the beginning to the end of the model.
//
//------------------------------------------------------------------------------
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
									 inLines:(NSArray *)lines
									maxIndex:(NSUInteger)maxIndex
{
	NSString    *firstLine      = nil;
	BOOL        isMPDModel      = NO;
	NSString    *currentLine    = nil;
	NSRange     testRange       = NSMakeRange(index, maxIndex - index + 1);
	NSRange     modelRange      = testRange;
	NSUInteger	counter			= 0;
	NSUInteger	modelEndIndex	= 0;
	
	if(testRange.length > 1)
	{
		// See if we have to look for MPD syntax.
		firstLine = [lines objectAtIndex:testRange.location];
		isMPDModel = [[self class] lineIsMPDModelStart:firstLine modelName:NULL];
		
		// Find the end of the MPD model. MPD models can end with 0 NOFILE, or 
		// they can just stop where the next model starts. 
		if(isMPDModel == YES)
		{
			// Assume the model extends for the rest of the file unless proven 
			// otherwise. 
			modelEndIndex = NSMaxRange(testRange) - 1;
		
			for(counter = testRange.location + 1; counter < NSMaxRange(testRange); counter++)
			{
				currentLine = [lines objectAtIndex:counter];
				
				if([[self class] lineIsMPDModelEnd:currentLine])
				{
					modelEndIndex = counter;
					break;
				}
				else if([[self class] lineIsMPDModelStart:currentLine modelName:NULL])
				{
					modelEndIndex = counter - 1;
					break;
				}
			}
			modelRange = NSMakeRange(testRange.location, modelEndIndex - testRange.location + 1);
		}
		else
		{
			// Non-MPD models just go to the end of the file.
			modelRange = testRange;
		}
	}
	
	return modelRange;

}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== write =============================================================
//
// Purpose:		Writes out the MPD submodel, wrapped in the MPD file commands.
//
//==============================================================================
- (NSString *) write
{
	NSString *CRLF = [NSString CRLF]; //we need a DOS line-end marker, because 
									  //LDraw is predominantly DOS-based.
	
	NSMutableString *written = [NSMutableString string];
	
	//Write it out as:
	//		0 FILE model_name
	//			....
	//		   model text
	//			....
	//		0 NOFILE
	[written appendFormat:@"0 %@ %@%@", LDRAW_MPD_SUBMODEL_START, [self modelName], CRLF];
	[written appendFormat:@"%@%@", [super write], CRLF];
	[written appendFormat:@"0 %@", LDRAW_MPD_SUBMODEL_END];
	
	return written;
	
}//end write


//========== writeModel =============================================================
//
// Purpose:		Writes out the submodel, without the MPD file commands.
//
//==============================================================================
- (NSString *) writeModel
{
	return [super write];
	
}//end writeModel


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
	return [self modelDisplayName];
	
}//end browsingDescription


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionMPDModel";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) modelDisplayName
{
	// Chop off that hideous un-Maclike .ldr extension that the LDraw File 
	// Specification forces us to add. 
	return [[self modelName] stringByDeletingPathExtension];
	
}//end modelDisplayName


//========== modelName =========================================================
//
// Purpose:		Retuns the name for this MPD file. The MPD name functions as 
//				the part name to describe the entire submodel.
//
//==============================================================================
- (NSString *) modelName
{
	return modelName;
	
}//end modelName


//========== setModelName: =====================================================
//
// Purpose:		Updates the name for this MPD file. The MPD name functions as 
//				the part name to describe the entire submodel.
//
//==============================================================================
- (void) setModelName:(NSString *)newModelName
{
	[newModelName retain];
	[modelName release];
	
	modelName = newModelName;
	
	[[self enclosingFile] updateModelLookupTable];
	
}//end setModelName:


//========== setModelDisplayName: ==============================================
//
// Purpose:		Unfortunately, we can't accept any old input for model names. 
//				This method accepts a user-entered string with arbitrary 
//				characters, and sets the model name to the closest 
//				representation thereof which is still LDraw-compliant. 
//
//				After calling this method, -browsingDescription will return a 
//				value as close to newDisplayName as possible. 
//
//==============================================================================
- (void) setModelDisplayName:(NSString *)newDisplayName
{
	NSString	*acceptableName	= [LDrawMPDModel ldrawCompliantNameForName:newDisplayName];
	
	[self setModelName:acceptableName];
	
}//end setModelDisplayName:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//---------- ldrawCompliantNameForName: ------------------------------[static]--
//
// Purpose:		Unfortunately, we can't accept any old input for model names. 
//				This method accepts a user-entered string with arbitrary 
//				characters, and returns the model name or the closest 
//				representation thereof which is still LDraw-compliant. 
//
//------------------------------------------------------------------------------
+ (NSString *) ldrawCompliantNameForName:(NSString *)newDisplayName
{
	NSString	*acceptableName	= nil;
	
	// Since LDraw is space-delimited, we can't have whitespace at the beginning 
	// of the name. We'll chop of ending whitespace for good measure.
	acceptableName = [newDisplayName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// The LDraw spec demands that the model name end with a valid LDraw 
	// extension. Yuck! 
	if([LDrawUtilities isLDrawFilenameValid:acceptableName] == NO)
	{
//		acceptableName = [acceptableName stringByAppendingPathExtension:@"ldr"];
		acceptableName = [acceptableName stringByAppendingString:@".ldr"];
	}
	
	return acceptableName;
	
}//end ldrawCompliantNameForName:


//========== lineIsMPDModelStart:modelName: ====================================
//
// Purpose:		Returns if the line is a 0 FILE submodelName line.
//
//				If it is, optionally returns the submodelName
//
// Note:		Any line can have leading whitespace, which is why this is not 
//				as simple as [line hasPrefix:@"0 FILE"] 
//
//==============================================================================
+ (BOOL) lineIsMPDModelStart:(NSString*)line modelName:(NSString**)modelNamePtr
{
	NSString	*parsedField		= nil;
	NSString	*workingLine		= line;
	BOOL		isMPDModel			= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_MPD_SUBMODEL_START])
			isMPDModel = YES;
	}
	
	//Strip out the MPD commands for model parsing, and read in the model name.
	if(isMPDModel == YES && modelNamePtr != NULL)
	{
		// Extract MPD-specific data: the submodel name.
		// Leading and trailing whitespace is ignored, in keeping with the rules 
		// for parsing file references (type 1 lines) 
		*modelNamePtr = [workingLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	}
	
	return isMPDModel;
}


//========== lineIsMPDModelEnd: ================================================
//
// Purpose:		Returns if the line is a 0 NOFILE line.
//
//==============================================================================
+ (BOOL) lineIsMPDModelEnd:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isMPDModelEnd	= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_MPD_SUBMODEL_END])
			isMPDModelEnd = YES;
	}
	
	return isMPDModelEnd;
}


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	LDrawFile		*enclosingFile		= [self enclosingFile];
	NSString		*oldName			= [self modelName];
	
	[super registerUndoActions:undoManager];
	
	// Changing the name of the model in an undo-aware way is pretty bothersome, 
	// because we have to track down any references to the model and change 
	// their names too. That operation is the responsibility of the LDrawFile, 
	// not us. 
	if(enclosingFile != nil)
	{
		[[undoManager prepareWithInvocationTarget:enclosingFile]
									 renameModel: self
										  toName: oldName ];
	}
	else
		[[undoManager prepareWithInvocationTarget:self] setModelName:oldName];
	
}//end registerUndoActions:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Time to send the cows home.
//
//==============================================================================
- (void) dealloc
{
	[modelName	release];

	[super dealloc];
	
}//end dealloc


@end
