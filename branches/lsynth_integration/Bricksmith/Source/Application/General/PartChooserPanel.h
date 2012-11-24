//==============================================================================
//
// File:		PartChooserPanel.h
//
// Purpose:		Presents a PartBrower in a dialog.
//
//  Created by Allen Smith on 4/3/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@class PartBrowserDataSource;

@interface PartChooserPanel : NSPanel
{
	IBOutlet	PartChooserPanel		*partChooserPanel;
	IBOutlet	PartBrowserDataSource	*partsBrowser;
	IBOutlet	NSSearchField			*searchField;
	id oldSelf; //when this class is created, it reassigns itself to 
				// a nib object. This reference will point to the original 
				// allocation, which will then be releasable when the dialog 
				// closes.
}

//Initialization
+ (PartChooserPanel *) partChooserPanel;

//Accessors
- (NSString *) selectedPartName;

//Actions
- (NSInteger) runModal;
- (IBAction) insertPartClicked:(id)sender;
- (IBAction) cancelClicked:(id)sender;

@end
