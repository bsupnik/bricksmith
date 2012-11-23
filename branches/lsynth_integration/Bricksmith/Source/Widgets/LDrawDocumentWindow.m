//==============================================================================
//
// File:		LDrawDocumentWindow.m
//
// Purpose:		Window for LDraw. Provides minor niceties.
//
//  Created by Allen Smith on 4/4/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawDocumentWindow.h"


@implementation LDrawDocumentWindow


#pragma mark -
#pragma mark EVENTS
#pragma mark -

//========== keyDown: ==========================================================
//
// Purpose:		Time to do something exciting in response to a keypress.
//
//==============================================================================
- (void)keyDown:(NSEvent *)theEvent
{
	// You can trap certain key events here. But really, why?

	[super keyDown:theEvent];
		
}//end keyDown:


#pragma mark -
#pragma mark GRAPHICS
#pragma mark -


//========== disableUpdatesUntilFlush ==========================================
//
// Purpose:		Prevents the window from being visually until it is flushed. 
//				This is critically important for our OpenGL-in-SplitView setup, 
//				because the Quartz window and the OpenGL viewport seem to be 
//				getting flushed at different times. The syncs them up. 
//
// Note:		This solution was provided in Apple sample code. I don't quite 
//				understand it.
//
//				These should be obsoleted in Tiger by 
//				-[NSWindow disableScreenUpdatesUntilFlush]
//
//==============================================================================
- (void)disableUpdatesUntilFlush
{
	if(needsEnableUpdate == NO)
		NSDisableScreenUpdates(); //or DisableScreenUpdates() in Carbon.
		
	needsEnableUpdate = YES;
	
}//end disableUpdatesUntilFlush


//========== flushWindow =======================================================
//
// Purpose:		Our window is ready to be flushed, and apparently everything has
//				been collected in the same place now. Reenable screen updates if 
//				they've been turned off.
//
//==============================================================================
- (void)flushWindow
{
	[super flushWindow];
	if(needsEnableUpdate)
	{
		needsEnableUpdate = NO;
		NSEnableScreenUpdates(); //or EnableScreenUpdates() in Carbon.
	}
}//end flushWindow


@end
