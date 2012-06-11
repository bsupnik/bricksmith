//==============================================================================
//
// File:		BricksmithApplication.h
//
// Purpose:		Subclass of NSApplication allows us to do tricky things with 
//				events.
//
//  Created by Allen Smith on 11/29/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface BricksmithApplication : NSApplication
{

}

- (BOOL) shouldPropogateEvent:(NSEvent *)event;

@end
