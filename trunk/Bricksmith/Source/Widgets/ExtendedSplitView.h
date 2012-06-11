//==============================================================================
//
// File:		ExtendedSplitView.m
//
// Purpose:		Fills in some of the many blanks Apple left in NSSplitView.
//
//  Created by Allen Smith on 11/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface ExtendedSplitView : NSSplitView {
	NSString *autosaveName;
}

//Accessors
- (NSString *) autosaveName;
- (void) setAutosaveName:(NSString *)newName;

//Persistence
- (void) restoreConfiguration;
- (void) saveConfiguration;

@end
