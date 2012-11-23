//==============================================================================
//
// File:		BricksmithApplication.m
//
// Purpose:		Subclass of NSApplication allows us to do tricky things with 
//				events. I feel uncomfortable at best with the existence of this 
//				hacked subclass, so as little as possible should be in here.
//
// Notes:		Cocoa knows to use this subclass because we have specified its 
//				name in our Info.plist file.
//
//				Do not confuse this with LDrawApplication, an earlier class 
//				which should have been called LDrawApplicationController.
//
//  Created by Allen Smith on 11/29/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "BricksmithApplication.h"

#import "MacLDraw.h"

@implementation BricksmithApplication


//========== sendEvent =========================================================
//
// Purpose:		This is the central point for all events dispatched in the 
//				application.
//
//				We need to override it to grab NSKeyUp events generated while 
//				the command key is held down. We need those events so we can 
//				track keys properly for LDrawGLView's tool mode. Unfortunately, 
//				Cocoa seems to supress command-keyup events--at least, I never 
//				see them anywhere. All we do here is dispatch them to a custom 
//				method before they vanish into the ether. And we want other 
//				tool-mode key events to be processed whether or not the view is 
//				first responder. 
//
//==============================================================================
- (void)sendEvent:(NSEvent *)theEvent
{
	// We want to track keyboard events in our own little place, completely 
	// separate from the responder chain.
	if(		[theEvent type] == NSKeyDown
		||	[theEvent type] == NSKeyUp
		||	[theEvent type] == NSFlagsChanged )
	{
		[[NSNotificationCenter defaultCenter]
							postNotificationName:LDrawKeyboardDidChangeNotification
										  object:theEvent ];
	}
	// Tablet Proximity usually gets routed to a black hole in the responder 
	// chain. Make this global like it should be. Cocoa kindly sends us 
	// tablet-prox messages when the application activates, so we'll 
	// actually be correct as we track this now. 
	else if( [theEvent type] == NSTabletProximity )
	{
		[[NSNotificationCenter defaultCenter]
							postNotificationName:LDrawPointingDeviceDidChangeNotification
										  object:theEvent ];
	}
	
	
	// Deliver all events except for Command-space. That has special meaning to 
	// the Bricksmith tool palette, but it is never actually processed by 
	// Bricksmith's responder chain. That mean it generates a beep when pressed. 
	if( [self shouldPropogateEvent:theEvent] == YES )
	{
		// Send all events, even command-keyups, to the application to do 
		// whatever it expects to do with them. 
		[super sendEvent:theEvent];
	}
	
}//end sendEvent:


//========== shouldPropogateEvent: =============================================
//
// Purpose:		Returns whether the normal responder chain should be allowed to 
//				get a crack at processing theEvent. 
//
// Notes:		Command-space has special meaning to the Bricksmith tool 
//				palette, but it is never actually processed by Bricksmith's 
//				responder chain. That mean it generates a beep when pressed. So 
//				we kill it here. 
//
//				I guess we could handle this in LDrawGLView, but that would only 
//				work if the view is first responder. In places like the 
//				minifigure dialog or part browser, that is not the case. 
//
//==============================================================================
- (BOOL) shouldPropogateEvent:(NSEvent *)theEvent
{
	if(		[theEvent type] == NSKeyDown
	   &&	[[theEvent characters] isEqualToString:@" "] == YES
	   &&	([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask
	   )
		return NO;
	else
		return YES;
		
}//end shouldPropogateEvent:


@end
