//==============================================================================
//
// File:		LDrawColorWell.m
//
// Purpose:		Widget to provide a means of choosing an LDraw color for an 
//				element.
//
//				LDrawColorWell has two modes:
//
//				1)	merely summons a global color panel to make generic color 
//					changes (such as changing the default color, or changing the 
//					color of the active part).
//
//					To enable this mode, set the color well to 
//					"Momentary Push In" in Interface Builder.
//
//				2)	Controls the color of a specific object by tying itself to 
//					the color panel and dispatching actions when the color 
//					changes. (Behaves like NSColorWell.)
//
//					To enable this mode, set the color well to 
//					"Push On/Push Off" in Interface Builder.
//
//  Created by Allen Smith on 2/27/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawColorWell.h"

#import "LDrawColor.h"
#import "LDrawColorPanelController.h"

@implementation LDrawColorWell

static LDrawColorWell *sharedActiveColorWell = nil;

#pragma mark -
#pragma mark ACTIVE COLOR WELL
#pragma mark -

//---------- activeColorWell -----------------------------------------[static]--
//
// Purpose:		Returns the single application-wide color well which is 
//				currently depressed and functioning as the sole recipient of 
//				color-change messages from the shared Color Panel.
//
//				Returns nil if no color well is active.
//
//------------------------------------------------------------------------------
+ (LDrawColorWell *) activeColorWell
{
	return sharedActiveColorWell;
	
}//end activeColorWell


//---------- setActiveColorWell: -------------------------------------[static]--
//
// Purpose:		Sets the single application-wide active color well.
//
//				Pass nil if no color well is active.
//
//------------------------------------------------------------------------------
+ (void) setActiveColorWell:(LDrawColorWell *)newWell
{
	//change the appearence
	[sharedActiveColorWell	setState:NSOffState];
	[newWell				setState:NSOnState];

	//trade out variable
	[newWell				retain];
	[sharedActiveColorWell	release];
	
	sharedActiveColorWell = newWell;
	
	// The color panel must now reflect this Color Well
    // If there's no Color Well, well... perhaps we don't want to change the selection's color
    // An example is the search dialog, where the colour well is explicitly unset when the
    // dialog resigns key, and we thereby avoid changing the selection's color.
    if (newWell) {
        [[LDrawColorPanelController sharedColorPanel] setLDrawColor:[newWell LDrawColor]];
    }
	
}//end setActiveColorWell:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code represented by this button.
//
//==============================================================================
-(LDrawColor *) LDrawColor
{
	return color;
	
}//end LDrawColor


//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the LDraw color code of the receiver to newColorCode and 
//				redraws the receiever.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *)newColor
{
	GLfloat		 components[4];
	
	// assign ivar
	[newColor retain];
	[self->color release];
	self->color = newColor;
	
	// Set cached NSColor too
	[newColor getColorRGBA:components];
	
	[self->nsColor release];
	self->nsColor = [[NSColor colorWithCalibratedRed:components[0]
											   green:components[1]
												blue:components[2]
											   alpha:1.0 ] retain];
	
	[self setNeedsDisplay:YES];
	
}//end setLDrawColor:


#pragma mark -
#pragma mark DRAWING
#pragma mark -

//========== drawRect: =========================================================
//
// Purpose:		Paints the represented color inside the button.
//
//==============================================================================
- (void) drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	
	NSRect	 colorRect = NSInsetRect(aRect, 4, 4);
	
	[self->nsColor set];
	NSRectFill(colorRect);
	
}//end drawRect:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== changeLDrawColorWell: =============================================
//
// Purpose:		This is a special action called specifically by the 
//				LDrawColorPanelController to inform the active color well that 
//				it should change its current color. The color well's action 
//				should be sent in response to this message. 
//
//==============================================================================
- (void) changeLDrawColorWell:(id)sender
{
	LDrawColor *newColor = [sender LDrawColor];
	
	[self setLDrawColor:newColor];
	
	[self sendAction:[self action] to:[self target]];
	
}//end changeLDrawColorWell:


//========== sendAction:to: ====================================================
//
// Purpose:		Whenever this color well is clicked, we want to pull up the 
//				color panel. We may also want to dispatch an action message.
//
// Notes:		A color well functions in one of two modes:
//
//				1)	shows the color panel for sending global (nil-targeted) 
//					color-change messages. In this case, the color well's action 
//					is fired immediately, and simply indicates that the color 
//					panel was activated.
//				2)	Makes itself "active," in which case it becomes the sole 
//					recipient of color-changes messages from the color panel. In
//					this case, the color well's action is sent each time (and 
//					only when) the color panel changes. (Like NSColorWell.)
//
//				Unfortunately, the active well is tracked here because the 
//				override of -[NSButton setState:] is never called (presumably it 
//				happens at the cell level).
//
//==============================================================================
- (BOOL)sendAction:(SEL)theAction to:(id)theTarget
{	
	BOOL handledAction	= NO;
	
	//in any event open the color panel.
	[[[LDrawColorPanelController sharedColorPanel] window] orderFront:self];
	

	if([[self cell] showsStateBy] == NSNoCellMask) //not a toggle button
	{
        // Why are these *two* lines needed?  It works, but I'm not entirely sure why.
        [LDrawColorWell setActiveColorWell:self];
        [LDrawColorWell setActiveColorWell:nil];
		
		//just pass the action along.
		handledAction = [super sendAction:theAction to:theTarget];
	}
	else
	{
		//---------- Track Active Color Well -----------------------------------
		
		if([self state] == NSOnState)
		{
			//did we just become active?
			if([LDrawColorWell activeColorWell] != self)
			{
				[LDrawColorWell setActiveColorWell:self];
				handledAction = YES;
			}
				
			//already active; this must be a color-change action!
			else
				handledAction = [super sendAction:theAction to:theTarget];
		}
		//we deactivate?
		else if([self state] == NSOffState && [LDrawColorWell activeColorWell] == self)
		{
			[LDrawColorWell setActiveColorWell:nil];
			handledAction = YES;
		}
	}
	
	return handledAction;

}//end sendAction:to:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		It's like we were displaying Harvest Gold and Olive Green or 
//				something.
//
//==============================================================================
- (void) dealloc
{
	//if we are the active color well, it's time we ceased to be such!
	if([LDrawColorWell activeColorWell] == self)
		[LDrawColorWell setActiveColorWell:nil];
	
	[self->nsColor	release];
	
	[super dealloc];
	
}//end dealloc

@end
