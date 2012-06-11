//==============================================================================
//
// File:		PieceCountPanel.h
//
// Purpose:		Dialog to display the dimensions for a model.
//
//  Created by Allen Smith on 8/21/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "DialogPanel.h"

@class LDrawFile;
@class LDrawGLView;
@class LDrawMPDModel;
@class PartReport;

@interface PieceCountPanel : DialogPanel
{
	LDrawFile		*file;
	LDrawMPDModel	*activeModel;
	PartReport		*partReport;
	NSMutableArray	*flattenedReport;
	
	IBOutlet NSTableView		*pieceCountTable;
	IBOutlet LDrawGLView		*partPreview;
}

//Initialization
+ (PieceCountPanel *) pieceCountPanelForFile:(LDrawFile *)fileIn;
- (id) initWithFile:(LDrawFile *)file;

//Accessors
- (LDrawMPDModel *) activeModel;
- (LDrawFile *) file;
- (PartReport *) partReport;

- (void) setActiveModel:(LDrawMPDModel *)newModel;
- (void) setFile:(LDrawFile *)newFile;
- (void) setPartReport:(PartReport *)newPartReport;
- (void) setTableDataSource:(NSMutableArray *) newReport;

//Actions
- (IBAction) exportButtonClicked:(id)sender;

//Utilities
- (void) syncSelectionAndPartDisplayed;

@end
