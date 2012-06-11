//==============================================================================
//
// File:		PartBrowserPanelController.h
//
// Purpose:		Presents a PartBrower in a panel.
//
//  Created by Allen Smith on 4/3/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@class ExtendedSplitView;
@class PartBrowserDataSource;

@interface PartBrowserPanelController : NSWindowController
{
	IBOutlet	PartBrowserDataSource	   *partsBrowser;
	IBOutlet	ExtendedSplitView		   *splitView;
}

//Initialization
+ (PartBrowserPanelController *) sharedPartBrowserPanel;

//Accessors
- (PartBrowserDataSource *) partBrowser;

@end
