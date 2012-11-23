//==============================================================================
//
// File:		DimensionsPanel.m
//
// Purpose:		Dialog to display the dimensions for a model.
//
//  Created by Allen Smith on 8/21/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "DimensionsPanel.h"

#import "LDrawFile.h"
#import "LDrawMPDModel.h"
#import <math.h>

@implementation DimensionsPanel

#define STUDS_ROW_INDEX			0
#define INCHES_ROW_INDEX		1
#define CENTIMETERS_ROW_INDEX	2
#define LEGONIAN_FEET_ROW_INDEX	3
#define LDU_ROW_INDEX           4

#define NUMBER_OF_UNITS			5

#define UNITS_COLUMN		@"UnitsIdentifier"
#define WIDTH_COLUMN		@"WidthIdentifier"
#define LENGTH_COLUMN		@"LengthIdentifier"
#define HEIGHT_COLUMN		@"HeightIdentifier"


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- dimensionPanelForFile: ----------------------------------[static]--
//
// Purpose:		Creates a panel which displays the dimensions for the specified 
//				file. 
//
//------------------------------------------------------------------------------
+ (DimensionsPanel *) dimensionPanelForFile:(LDrawFile *)fileIn
{
	DimensionsPanel *dimensions = nil;
	
	dimensions = [[DimensionsPanel alloc] initWithFile:fileIn];
	
	return [dimensions autorelease];
	
}//end dimensionPanelForFile:


//========== initWithFile: =====================================================
//
// Purpose:		Make us an object. Load us our window.
//
// Notes:		Memory management is a bit tricky here. The receiver here is a 
//				throwaway object that exists soley to load a Nib file. We then 
//				junk the receiver and return a reference to the panel it loaded 
//				in the Nib. Tricky, huh?
//
//==============================================================================
- (id) initWithFile:(LDrawFile *)fileIn
{
	self = [super init];
	
	[self setFile:fileIn];
	
	return self;
	
}//end initWithFile:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== activeModel =======================================================
//
// Purpose:		Returns the name of the submodel in the file whose dimensions we 
//				are currently analyzing.
//
//==============================================================================
- (LDrawMPDModel *) activeModel
{
	return self->activeModel;
	
}//end activeModel


//========== file ==============================================================
//
// Purpose:		Returns the file whose dimensions we are analyzing.
//
//==============================================================================
- (LDrawFile *) file
{
	return self->file;
	
}//end file


//========== panelNibName ======================================================
//
// Purpose:		For the benefit of our superclass, we need to identify the name 
//				of the Nib where my dialog comes from.
//
//==============================================================================
- (NSString *) panelNibName
{
	return @"Dimensions";
	
}//end panelNibName


#pragma mark -

//========== setActiveModel: ===================================================
//
// Purpose:		Sets the name of the submodel in the file whose dimensions we 
//				are currently analyzing and updates the data view.
//
//==============================================================================
- (void) setActiveModel:(LDrawMPDModel *)newModel
{
	[newModel retain];
	[self->activeModel release];
	self->activeModel = newModel;
	
	[dimensionsTable reloadData];
	
}//end setActiveModel:


//========== setFile: ==========================================================
//
// Purpose:		Sets the file whose dimensions we are analyzing.
//
//==============================================================================
- (void) setFile:(LDrawFile *)newFile
{
	[newFile retain];
	[self->file release];
	
	file = newFile;
	[self setActiveModel:[newFile activeModel]];
	
}//end setFile:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== legonianRulerButtonClicked: =======================================
//
// Purpose:		Explain those Legonian units!
//
//==============================================================================
- (IBAction) legonianRulerButtonClicked:(id)sender
{
	NSString *path = [[NSBundle mainBundle] pathForResource:@"Legonian Ruler" ofType:@"pdf"];
	
	[[NSWorkspace sharedWorkspace] openFile:path];
}


#pragma mark -
#pragma mark DELEGATES

#pragma mark -
#pragma mark NSTableDataSource

//**** NSTableDataSource ****
//========== numberOfRowsInTableView: ==========================================
//
// Purpose:		End the sheet (we are the sheet!)
//
//==============================================================================
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return NUMBER_OF_UNITS;
	
}//end numberOfRowsInTableView:


//**** NSTableDataSource ****
//========== tableView:objectValueForTableColumn:row: ==========================
//
// Purpose:		Return the appropriate dimensions.
//
//				This is downright ugly. Studs are different depending on whether 
//				they are horizontal or vertical. Oh yeah, and we want to display 
//				integers, floats, and strings in one table.
//
//==============================================================================
- (id)				tableView:(NSTableView *)tableView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
						  row:(NSInteger)rowIndex
{
	NSNumberFormatter   *floatFormatter = [[NSNumberFormatter new] autorelease];
	id                  object          = nil;
	Box3                bounds          = [self->activeModel boundingBox3];
	double              width           = 0;
	double              height          = 0;
	double              length          = 0;
	double              value           = 0;
	
	 // 1 stud = 3/8" = 20 LDraw units.
	double	studsPerLDU				= 1 / 20.0; //HORIZONTAL studs!
	double	inchesPerStud			= 5 / 16.0; //HORIZONTAL studs!
	double	inchesPerVerticalStud	= 3 / 8.0  +  1 / 16.0; //brick height + stud height.
	double	cmPerInch				= 2.54;
	double	legoInchPerInch			= 128 / 3.0; // Legonian Imperial Feet are a 3:128 scale.
	
	
	[floatFormatter setPositiveFormat:@"0.0"];
	
	//If we got valid bounds, analyze them.
	if(V3EqualBoxes(bounds, InvalidBox) == NO)
	{
		width	= bounds.max.x - bounds.min.x;
		height	= bounds.max.y - bounds.min.y;
		length	= bounds.max.z - bounds.min.z;
	}

	//Units Label?
	if([[tableColumn identifier] isEqualToString:UNITS_COLUMN])
	{
		switch(rowIndex)
		{
			case STUDS_ROW_INDEX:			object = NSLocalizedString(@"Studs", nil);			break;
			case INCHES_ROW_INDEX:			object = NSLocalizedString(@"Inches", nil);			break;
			case CENTIMETERS_ROW_INDEX:		object = NSLocalizedString(@"Centimeters", nil);	break;
			case LEGONIAN_FEET_ROW_INDEX:	object = NSLocalizedString(@"LegonianFeet", nil);	break;
			case LDU_ROW_INDEX:             object = NSLocalizedString(@"LDU", nil);            break;
		}
	}
	//Dimension value, then.
	else
	{
		// Width, Height, or Length?
		if([[tableColumn identifier] isEqualToString:WIDTH_COLUMN])
			value = width;
		else if([[tableColumn identifier] isEqualToString:LENGTH_COLUMN])
			value = length;
		else if([[tableColumn identifier] isEqualToString:HEIGHT_COLUMN])
			value = height;
			
		// We have the value in LDraw Units; convert to display units.
		switch(rowIndex)
		{
			//oh dear. Studs are difficult.
			case STUDS_ROW_INDEX:
				if([[tableColumn identifier] isEqualToString:HEIGHT_COLUMN])
					value *= (studsPerLDU * inchesPerStud) / inchesPerVerticalStud; //get vertical studs.
				else
					value *= studsPerLDU; //get horizontal studs
				break;
				
			case INCHES_ROW_INDEX:			value *= studsPerLDU * inchesPerStud;					break;
			case CENTIMETERS_ROW_INDEX:		value *= studsPerLDU * inchesPerStud * cmPerInch;		break;
			case LEGONIAN_FEET_ROW_INDEX:	value *= studsPerLDU * inchesPerStud * legoInchPerInch;	break;
			case LDU_ROW_INDEX:				value *= 1;												break; // nothing to convert for LDU
		}
		
		// Format output.
		switch(rowIndex)
		{
			case STUDS_ROW_INDEX:
				object = [NSNumber numberWithInteger:ceil(value)];
				break;
			
			case INCHES_ROW_INDEX:
				object = [NSNumber numberWithDouble:value];
				object = [floatFormatter stringForObjectValue:object];
				break;
			
			case CENTIMETERS_ROW_INDEX:
				object = [NSNumber numberWithDouble:value];
				object = [floatFormatter stringForObjectValue:object];
				break;
			
			//This one's a doozy--format in feet and inches.
			case LEGONIAN_FEET_ROW_INDEX:
				object = [NSString stringWithFormat:	NSLocalizedString(@"FeetAndInchesFormat", nil),
														(int) floor(value / 12),	//feet
														(int) fmod(value, 12)		//inches
						];
				break;
			
			case LDU_ROW_INDEX:
				object = [NSNumber numberWithInteger:ceil(value)];
				break;
		}
		
	}
		
	return object;
	
}//end tableView:objectValueForTableColumn:row:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The end is nigh.
//
//==============================================================================
- (void) dealloc
{
	[file			release];
	[activeModel	release];
	
	[super dealloc];
	
}//end dealloc


@end
