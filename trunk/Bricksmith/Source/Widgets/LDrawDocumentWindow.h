//==============================================================================
//
// File:		LDrawDocumentWindow.h
//
// Purpose:		Window for LDraw. Provides minor niceties.
//
//  Created by Allen Smith on 4/4/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface LDrawDocumentWindow : NSWindow {

	BOOL needsEnableUpdate;
}
- (void)disableUpdatesUntilFlush;

@end
