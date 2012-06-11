//==============================================================================
//
// File:		DimensionsPanel.h
//
// Purpose:		Dialog to display the dimensions for a model.
//
//  Created by Allen Smith on 8/21/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "DialogPanel.h"

@class LDrawFile;
@class LDrawMPDModel;

@interface DimensionsPanel : DialogPanel
{
	LDrawFile		*file;
	LDrawMPDModel	*activeModel;
	
	IBOutlet NSTableView		*dimensionsTable;
}

//Initialization
+ (DimensionsPanel *) dimensionPanelForFile:(LDrawFile *)fileIn;
- (id) initWithFile:(LDrawFile *)file;

//Accessors
- (LDrawMPDModel *) activeModel;
- (LDrawFile *) file;
- (void) setActiveModel:(LDrawMPDModel *)newModel;
- (void) setFile:(LDrawFile *)newFile;

@end
