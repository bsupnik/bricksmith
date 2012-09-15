//==============================================================================
//
// File:		PartReport.m
//
// Purpose:		Part Reports provide a way to do bulk queries or updates to all 
//				the parts in the model. 
//
//				Part Reports can generate a report of the parts in a model, with 
//				the quantities and colors of each type of part included. Along 
//				with statistics, this class can also report on things like 
//				missing or moved parts. 
//
//				A newly-allocated copy of this object should be passed into a 
//				model. The model will then register all its parts in the report.
//				The information in the report can then be analyzed. The idea 
//				here is that the logic for traversing an LDraw hiearchy will be 
//				encapsulated in the containers themselves (steps, etc.); this 
//				class provides a way for the containers to flatten their 
//				internal structure without revealing too many details about how 
//				it is organized. 
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartReport.h"

#import "LDrawContainer.h"
#import "LDrawKeywords.h"
#import "LDrawPart.h"
#import "PartLibrary.h"

NSString    *PART_REPORT_NUMBER_KEY     = @"Part Number";
NSString    *PART_REPORT_NAME_KEY       = @"Part Name";
NSString    *PART_REPORT_LDRAW_COLOR    = @"LDraw Color";
NSString    *PART_REPORT_COLOR_NAME     = @"Color Name";
NSString    *PART_REPORT_PART_QUANTITY  = @"QuantityKey";


@implementation PartReport

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- partReportForContainer: ---------------------------------[static]--
//
// Purpose:		Returns an empty part report object, ready to be passed to a 
//				model to be filled up with information.
//
//------------------------------------------------------------------------------
+ (PartReport *) partReportForContainer:(LDrawContainer *)container
{
	PartReport *partReport = [PartReport new];
	
	[partReport setLDrawContainer:container];
	
	return [partReport autorelease];
	
}//end partReportForContainer


//========== init ==============================================================
//
// Purpose:		Creates a new part report object, ready to be passed to a model 
//				to be filled up with information.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	partsReport = [NSMutableDictionary new];
	
	return self;
	
}//end init


#pragma mark -
#pragma mark COLLECTING INFORMATION
#pragma mark -

//========== setLDrawContainer: ================================================
//
// Purpose:		Sets the object on which we will collect report data.
//
//==============================================================================
- (void) setLDrawContainer:(LDrawContainer *)newContainer
{
	[newContainer			retain];
	[self->reportedObject	release];
	
	self->reportedObject = newContainer;
	
}//end setLDrawContainer:


//========== getPieceCountReport ===============================================
//
// Purpose:		Produces a report detailing the number of pieces in the current
//				Container, as well as the attributes of those parts.
//
//==============================================================================
- (void) getPieceCountReport
{
	// Unfortunately, the reporting responsibility falls on the container 
	// itself. The reason is that the parts we are reporting might wind up being 
	// MPD references, in which case we need to merge the report for the 
	// referenced submodel into *this* report. 
	[reportedObject collectPartReport:self];
	
}//end getPieceCountReport


//========== getMissingPiecesReport ============================================
//
// Purpose:		Collects information about all the parts in the model which 
//				can't be found or have been moved.
//
//==============================================================================
- (void) getMissingPiecesReport
{
	PartLibrary		*partLibrary		= [PartLibrary sharedPartLibrary];
	NSArray			*elements			= [self->reportedObject allEnclosedElements];
	id				 currentElement		= nil;
//	LDrawModel		*partModel			= nil;
	NSString		*category			= nil;
	NSUInteger		 elementCount		= [elements count];
	NSUInteger		 counter			= 0;
	
	//clear out any previous reports.
	if(self->missingParts != nil)
		[missingParts release];
	if(self->movedParts != nil)
		[movedParts release];
		
	self->missingParts  = [[NSMutableArray alloc] init];
	self->movedParts    = [[NSMutableArray alloc] init];
	
	for(counter = 0; counter < elementCount; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		
		if( [currentElement isKindOfClass:[LDrawPart class]] )
		{
			//Missing?
			if ([currentElement partIsMissing])
//			partModel = [partLibrary modelForPart:currentElement];
//			if(partModel == nil)
				[missingParts addObject:currentElement];
			
			//Moved?
			category = [partLibrary categoryForPartName:[currentElement referenceName]];
			if([category isEqualToString:LDRAW_MOVED_CATEGORY]) 
			   [movedParts addObject:currentElement];
		}
	}
}//end getMissingPiecesReport


//========== registerPart ======================================================
//
// Purpose:		We are being told to the add the specified part into our report.
//				
//				Our partReport dictionary is arranged as follows:
//				
//				Keys: Part Numbers <NSString>
//				Values: NSMutableDictionaries.
//					|
//					|-> Keys: LDrawColorT <NSNumber>
//						Values: NSNumbers indicating the quantity of parts
//							of this type and color
//
//==============================================================================
- (void) registerPart:(LDrawPart *)part
{
	NSString			*partName			= [part referenceName];
	LDrawColor			*partColor			= [part LDrawColor];
	
	NSMutableDictionary	*partRecord			= [self->partsReport objectForKey:partName];
	NSUInteger			 numberColoredParts	= 0;

	
	if(partRecord == nil)
	{
		//We haven't encountered one of these parts yet. Start counting!
		partRecord = [NSMutableDictionary dictionary];
		[self->partsReport setObject:partRecord forKey:partName];
	}
	
	// Now let's see how many parts with this color we have so far. If we don't 
	// have any, this call will conveniently return 0. 
	numberColoredParts = [[partRecord objectForKey:partColor] integerValue];
	
	// Update our tallies.
	self->totalNumberOfParts += 1;
	numberColoredParts += 1;
	
	[partRecord setObject:[NSNumber numberWithUnsignedInteger:numberColoredParts]
				   forKey:partColor];
				   
}//end registerPart:


#pragma mark -
#pragma mark ACCESSING INFORMATION
#pragma mark -

//========== allParts ==========================================================
//
// Purpose:		Returns all the LDrawParts contained in this model.
//
//==============================================================================
- (NSArray *) allParts
{
	NSArray			*elements			= [self->reportedObject allEnclosedElements];
	id				 currentElement		= nil;
	NSUInteger		 elementCount		= [elements count];
	NSUInteger		 counter			= 0;
	NSMutableArray	*parts				= [NSMutableArray array];
	
	// Find all LDrawPart instances in the contained elements
	for(counter = 0; counter < elementCount; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		
		if( [currentElement isKindOfClass:[LDrawPart class]] )
		{
			[parts addObject:currentElement];
		}
	}
	
	return parts;
	
}//end allParts


//========== flattenedReport ===================================================
//
// Purpose:		Returns an array a part records ideally suited for displaying in 
//				a table view.
//
//				Each entry in the array is a dictionary containing the keys:
//				PART_REPORT_NUMBER_KEY, LDRAW_COLOR, PART_QUANTITY
//
//==============================================================================
- (NSArray *) flattenedReport
{
	NSMutableArray  *flattenedReport        = [NSMutableArray array];
	NSArray         *allPartNames           = [partsReport allKeys];
	NSDictionary    *quantitiesForPart      = nil;
	NSArray         *allColors              = nil;
	
	PartLibrary     *partLibrary            = [PartLibrary sharedPartLibrary];
	
	NSDictionary    *currentPartRecord      = nil;
	NSString        *currentPartNumber      = nil;
	LDrawColor      *currentPartColor       = nil;
	NSNumber        *currentPartQuantity    = nil;
	NSString        *currentPartName        = nil; //for convenience.
	NSString        *currentColorName       = nil;
	
	NSUInteger      counter                 = 0;
	NSUInteger      colorCounter            = 0;
	
	//Loop through every type of part in the report
	for(counter = 0; counter < [allPartNames count]; counter++)
	{
		currentPartNumber	= [allPartNames objectAtIndex:counter];
		quantitiesForPart	= [partsReport objectForKey:currentPartNumber];
		allColors			= [quantitiesForPart allKeys];
		
		//For each type of part, find each color/quantity pair recorded for it.
		for(colorCounter = 0; colorCounter < [allColors count]; colorCounter++)
		{
			currentPartColor	= [allColors objectAtIndex:colorCounter];
			currentPartQuantity	= [quantitiesForPart objectForKey:currentPartColor];
			
			currentPartName		= [partLibrary descriptionForPartName:currentPartNumber];
			currentColorName	= [currentPartColor localizedName];
			
			//Now we have all the information we need. Flatten it into a single
			// record.
			currentPartRecord = [NSDictionary dictionaryWithObjectsAndKeys:
						currentPartNumber,		PART_REPORT_NUMBER_KEY,
						currentPartName,		PART_REPORT_NAME_KEY,
						currentPartColor,		PART_REPORT_LDRAW_COLOR,
						currentColorName,		PART_REPORT_COLOR_NAME,
						currentPartQuantity,	PART_REPORT_PART_QUANTITY,
						nil ];
			[flattenedReport addObject:currentPartRecord];
		}//end loop for color/quantity pairs within each part
	}//end part loop
	
	return flattenedReport;

}//end flattenedReport


//========== missingParts ======================================================
//
// Purpose:		Returns an array of the LDrawParts in this file which are 
//				~Moved aliases to new files.
//
//==============================================================================
- (NSArray *) missingParts
{
	//haven't gotten the report yet; get it.
	if(self->missingParts == nil)
		[self getMissingPiecesReport];
	
	return self->missingParts;
	
}//end missingParts


//========== movedParts ========================================================
//
// Purpose:		Returns an array of the LDrawParts in this file which are 
//				~Moved aliases to new files.
//
//==============================================================================
- (NSArray *) movedParts
{
	//haven't gotten the report yet; get it.
	if(self->movedParts == nil)
		[self getMissingPiecesReport];
		
	return self->movedParts;
	
}//end movedParts


//========== numberOfParts =====================================================
//
// Purpose:		Returns the total number of parts registered in this report.
//
//==============================================================================
- (NSUInteger) numberOfParts
{
	return self->totalNumberOfParts;
	
}//end numberOfParts


//========== textualRepresentation =============================================
//
// Purpose:		Returns a string containing the part report as tab-delimited 
//				plain text. Output appears as follows:
//				
//					Part		Description		Quantity	Color
//					3001.dat	Brick 2 x 4		5			Red
//					3710.dat	Plate 1 x 4		17			Blue
//
// Parameters:	sortDescriptors	- sort order of the data columns. Part reports 
//								  have no intrinsic sorting, so we must impose 
//								  it from the outside.
//
// Notes:		We should also (or instead) support Bricklink XML format.
//
//==============================================================================
- (NSString *) textualRepresentationWithSortDescriptors:(NSArray *)sortDescriptors
{
	NSArray         *flattenedReport    = [self flattenedReport];
	NSMutableString *text               = [NSMutableString stringWithCapacity:1024];
	NSString        *lineFormat         = @"%@\t%@\t%@\t%@\n";
	NSDictionary    *partRecord         = nil;
	NSUInteger      counter             = 0;
	
	//rely on someone outside us providing a sort order
	if(sortDescriptors != nil)
		flattenedReport = [flattenedReport sortedArrayUsingDescriptors:sortDescriptors];

	//the Header
	[text appendFormat: lineFormat,
									NSLocalizedString(@"PieceCountQuantityColumnName", nil),
									NSLocalizedString(@"PieceCountPartNumberColumnName", nil),
									NSLocalizedString(@"PieceCountDescriptionColumnName", nil),
									NSLocalizedString(@"PieceCountColorColumnName", nil) ];
	//Part Rows
	for(counter = 0; counter < [flattenedReport count]; counter++)
	{
		partRecord	= [flattenedReport objectAtIndex:counter];
		
		[text appendFormat: lineFormat,
									[partRecord objectForKey:PART_REPORT_PART_QUANTITY],
									[partRecord objectForKey:PART_REPORT_NUMBER_KEY],
									[partRecord objectForKey:PART_REPORT_NAME_KEY],
									[partRecord objectForKey:PART_REPORT_COLOR_NAME] ];
	}
	
	return text;
	
}//end textualRepresentationWithSortDescriptors:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Quoth the Raven: "Nevermore!"
//
//==============================================================================
- (void) dealloc
{
	[reportedObject	release];
	[partsReport	release];
	[missingParts	release];
	[movedParts		release];
	
	[super dealloc];
	
}//end dealloc

@end
