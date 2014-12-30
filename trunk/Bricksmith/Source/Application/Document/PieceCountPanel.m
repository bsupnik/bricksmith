//==============================================================================
//
// File:		PieceCountPanel.m
//
// Purpose:		Dialog to display the dimensions for a model.
//
//  Created by Allen Smith on 8/21/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PieceCountPanel.h"

#import "LDrawApplication.h"
#import "LDrawColor.h"
#import "LDrawColorCell.h"
#import "LDrawFile.h"
#import "LDrawGLView.h"
#import "LDrawMPDModel.h"
#import "LDrawPart.h"
#import "MacLDraw.h"
#import "PartLibrary.h"
#import "PartReport.h"


@implementation PieceCountPanel

//========== awakeFromNib ======================================================
//
// Purpose:		Readies things that need to be readied. 
//
//==============================================================================
- (void) awakeFromNib
{
	LDrawColorCell  *colorCell      = [[[LDrawColorCell alloc] init] autorelease];
	NSTableColumn   *colorColumn    = [pieceCountTable tableColumnWithIdentifier:PART_REPORT_LDRAW_COLOR];
	
	[colorColumn setDataCell:colorCell];
	
	[partPreview setAcceptsFirstResponder:NO];
	
	//Remember, this method is called twice for an LDrawColorPanelController; the first time 
	// is for the File's Owner, which is promptly overwritten.
	
}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- pieceCountPanelForFile: ---------------------------------[static]--
//
// Purpose:		Creates a panel which displays the dimensions for the specified 
//				file. 
//
//------------------------------------------------------------------------------
+ (PieceCountPanel *) pieceCountPanelForFile:(LDrawFile *)fileIn
{
	PieceCountPanel *panel = nil;
	
	panel = [[PieceCountPanel alloc] initWithFile:fileIn];
	
	return [panel autorelease];
	
}//end pieceCountPanelForFile:


//========== initWithFile: =====================================================
//
// Purpose:		Make us an object. The superclass loads us our window.
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


//========== container =========================================================
//
// Purpose:		Returns the container whose dimensions we are analyzing.
//
//==============================================================================
- (LDrawFile *) file
{
	return self->file;
	
}//end file


//========== panelNibName ======================================================
//
// Purpose:		Returns the name of the Nib which contains the desired panel.
//				Called by our superclass.
//
//==============================================================================
- (NSString *) panelNibName
{
	return @"PieceCountPanel";
	
}//end panelNibName


//========== partReport: =======================================================
//
// Purpose:		Sets the name of the submodel in the file whose dimensions we 
//				are currently analyzing and updates the data view.
//
//==============================================================================
- (PartReport *) partReport
{
	return self->partReport;
	
}//end partReport


#pragma mark -

//========== setActiveModel: ===================================================
//
// Purpose:		Sets the name of the submodel in the file whose dimensions we 
//				are currently analyzing, and also updates the data view.
//
//==============================================================================
- (void) setActiveModel:(LDrawMPDModel *)newModel
{
	PartReport		*modelReport	= nil;
	
	//Update the model name.
	[newModel retain];
	[self->activeModel release];
	self->activeModel = newModel;
	
	//Get the report for the new model.
	modelReport = [PartReport partReportForContainer:self->activeModel];
	[modelReport getPieceCountReport];
	
	[self setPartReport:modelReport];
	
}//end setActiveModel:


//========== setFile: ==========================================================
//
// Purpose:		Sets the file we are reporting on.
//
//==============================================================================
- (void) setFile:(LDrawFile *)newFile
{
	[newFile retain];
	[self->file release];
	
	file = newFile;
	[self setActiveModel:[newFile activeModel]];
	
}//end setFile:


//========== setPartReport: ====================================================
//
// Purpose:		Sets the part report (containing all piece/color/quantity info)
//				that we are displaying.
//
// Notes:		You should never call this method directly.
//
//==============================================================================
- (void) setPartReport:(PartReport *)newPartReport
{
	NSMutableArray *flattened = nil;
	
	//Update the part report
	[newPartReport retain];
	[self->partReport release];
	partReport = newPartReport;
	
	//Prepare some new data for the table view:
	flattened = [NSMutableArray arrayWithArray:[partReport flattenedReport]];
	[self setTableDataSource:flattened];
	
	[pieceCountTable reloadData];
	
}//end setPartReport:


//========== setTableDataSource: ===============================================
//
// Purpose:		The table displays a list of the parts in a category. The array
//				here is an array of part records containg names and 
//				descriptions.
//
//				The new parts are then displayed in the table.
//
//==============================================================================
- (void) setTableDataSource:(NSMutableArray *) newReport
{	
	//Sort the parts based on whatever the current sort order is for the table.
	[newReport sortUsingDescriptors:[pieceCountTable sortDescriptors]];
	
	//Swap out the variable
	[newReport retain];
	[flattenedReport release];
	
	flattenedReport = newReport;
	
	//Update the table
	[pieceCountTable reloadData];
	[self syncSelectionAndPartDisplayed];
	
}//end setTableDataSource


#pragma mark -
#pragma mark TABLE VIEW
#pragma mark -

//========== exportButtonClicked: ==============================================
//
// Purpose:		Export a tab-delimited text file of the part list.
//
//==============================================================================
- (IBAction) exportButtonClicked:(id)sender
{
	NSSavePanel *savePanel          = [NSSavePanel savePanel];
	NSURL       *savePath           = nil;
	NSString    *exported           = nil;
	NSArray     *sortDescriptors    = [self->pieceCountTable sortDescriptors];
	NSInteger   result              = 0;
	
	//set up the save panel
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setTitle:NSLocalizedString(@"PieceCountSaveDialogTitle", nil)];
	[savePanel setMessage:NSLocalizedString(@"PieceCountSaveDialogMessage", nil)];
	[savePanel setNameFieldStringValue:NSLocalizedString(@"untitled", nil)];
	
	//run it and export the file if needed
	result = [savePanel runModal];
	if(result == NSFileHandlingPanelOKButton)
	{
		savePath	= [savePanel URL];
		exported	= [self->partReport textualRepresentationWithSortDescriptors:sortDescriptors];
		
		[exported writeToURL:savePath
				  atomically:YES
					encoding:NSUTF8StringEncoding
					   error:NULL ];
	}

}//end exportButtonClicked:


#pragma mark -
#pragma mark TABLE VIEW
#pragma mark -

//**** NSTableDataSource ****
//========== numberOfRowsInTableView: ==========================================
//
// Purpose:		How many parts?
//
//==============================================================================
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [flattenedReport count];
	
}//end numberOfRowsInTableView:


//**** NSTableDataSource ****
//========== tableView:objectValueForTableColumn:row: ==========================
//
// Purpose:		Provide the information for each part row.
//
//==============================================================================
- (id)				tableView:(NSTableView *)tableView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
						  row:(NSInteger)rowIndex
{
	NSString		*identifier	= [tableColumn identifier];
	NSDictionary	*partRecord	= [flattenedReport objectAtIndex:rowIndex];
	id				 object		= nil;
	
	object = [partRecord objectForKey:identifier];
	
//	if(		[identifier isEqualToString:PART_NUMBER_KEY]
//		||	[identifier isEqualToString:PART_QUANTITY]
//		||	[identifier isEqualToString:LDRAW_COLOR] )
//	{
//		object = [partRecord objectForKey:identifier];
//	}
//	
//	else if([identifier isEqualToString:PART_NAME_KEY])
//		object = [[PartLibrary sharedPartLibrary] descriptionForPartName:[partRecord objectForKey:PART_NUMBER_KEY]];
//	
//	else if([identifier isEqualToString:COLOR_NAME])
//		object = [LDrawColor nameForLDrawColor:[[partRecord objectForKey:LDRAW_COLOR] intValue]];
	
	return object;
	
}//end tableView:objectValueForTableColumn:row:


//**** NSTableDataSource ****
//========== tableView:sortDescriptorsDidChange: ===============================
//
// Purpose:		Resort the table elements.
//
//==============================================================================
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *newDescriptors = [tableView sortDescriptors];
	
	[flattenedReport sortUsingDescriptors:newDescriptors];
	[tableView reloadData];
	
}//end tableView:sortDescriptorsDidChange:


//**** NSTableDataSource ****
//========== tableViewSelectionDidChange: ======================================
//
// Purpose:		A new selection! Update the part preview accordingly.
//
//==============================================================================
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self syncSelectionAndPartDisplayed];
	
}//end tableViewSelectionDidChange:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== syncSelectionAndPartDisplayed =====================================
//
// Purpose:		Makes the current part displayed match the part selected in the 
//				table.
//
//==============================================================================
- (void) syncSelectionAndPartDisplayed
{
	NSDictionary   *partRecord    = nil;
	NSString       *partName      = nil;
	LDrawColor     *partColor     = nil;
	LDrawPart      *newPart       = nil;
	NSInteger      rowIndex       = [pieceCountTable selectedRow];
	
	if(rowIndex >= 0)
	{
		partRecord	= [flattenedReport objectAtIndex:rowIndex];
		partName	= [partRecord objectForKey:PART_REPORT_NUMBER_KEY];
		partColor	= [partRecord objectForKey:PART_REPORT_LDRAW_COLOR];
		
		newPart		= [[[LDrawPart alloc] init] autorelease];
		
		// Not this simple anymore. We have to make sure to draw the optimized 
		// vertexes. The easiest way to do that is to create a part referencing 
		// the model. 
//		modelToView = [partLibrary modelForName:partName];

		//Set up the part attributes
		[newPart setLDrawColor:partColor];
		[newPart setDisplayName:partName];
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		[newPart optimizeOpenGL];

		[partPreview setLDrawDirective:newPart];
		[partPreview setLDrawColor:partColor];
	}
	
}//end syncSelectionAndPartDisplayed


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
	[file				release];
	[activeModel		release];
	[partReport			release];
	[flattenedReport	release];
	
	[super dealloc];
	
}//end dealloc


@end
