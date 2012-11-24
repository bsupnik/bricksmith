//==============================================================================
//
// File:		PartReport.h
//
// Purpose:		Holds the data necessary to generate a report of the parts in a 
//				model. We are interested in the quantities and colors of each 
//				type of part included.
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

@class LDrawPart;
@class LDrawContainer;


extern NSString *PART_REPORT_NUMBER_KEY;
extern NSString *PART_REPORT_NAME_KEY;
extern NSString *PART_REPORT_LDRAW_COLOR;	// LDrawColor object
extern NSString *PART_REPORT_COLOR_NAME;	// NSString representing localized name
extern NSString *PART_REPORT_PART_QUANTITY;	// NSNumber of how many of this part there are


////////////////////////////////////////////////////////////////////////////////
//
// class PartReport
//
////////////////////////////////////////////////////////////////////////////////
@interface PartReport : NSObject
{
	LDrawContainer		*reportedObject;
	NSMutableDictionary	*partsReport;			//see -registerPart: for a description of this data
	NSMutableArray		*missingParts;
	NSMutableArray		*movedParts;
	NSUInteger			 totalNumberOfParts;	//how many parts are in the model.
}

//Initialization
+ (PartReport *) partReportForContainer:(LDrawContainer *)container;

//Collecting Information
- (void) setLDrawContainer:(LDrawContainer *)newContainer;
- (void) getPieceCountReport;
- (void) registerPart:(LDrawPart *)part;

//Accessing Information
- (NSArray *) allParts;
- (NSArray *) flattenedReport;
- (NSArray *) missingParts;
- (NSArray *) movedParts;
- (NSUInteger) numberOfParts;
- (NSString *) textualRepresentationWithSortDescriptors:(NSArray *)sortDescriptors;

@end
