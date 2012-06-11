//==============================================================================
//
// File:		DialogPanel.h
//
// Purpose:		Abstract superclass which facilitates creating dialogs that 
//				extend NSPanel. This handles the weirdo memory management 
//				associated with doing that.
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface DialogPanel : NSPanel {
	
	//A referece to the actual panel which will become "us."
	IBOutlet DialogPanel		*dialogPanel;
	
	//All following outlets should be connected to dialogPanel, 
	// NOT to File's Owner. File's Owner will be deallocated as 
	// soon as the Nib is loaded; only dialogPanel will survive.
	IBOutlet NSObjectController	*objectController;
}

//Accessors
- (NSString *) panelNibName;

//Actions
- (IBAction) okButtonClicked:(id)sender;

@end
