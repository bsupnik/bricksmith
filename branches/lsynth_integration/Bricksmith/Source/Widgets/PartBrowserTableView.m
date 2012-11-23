//==============================================================================
//
// File:		PartBrowserTableView.m
//
// Purpose:		Table-view extensions specific to the tables used in the 
//			    Bricksmith Part Browser. 
//
//  Created by Allen Smith on 6/11/07.
//  Copyright 2007. All rights reserved.
//==============================================================================
#import "PartBrowserTableView.h"

#import "BricksmithUtilities.h"

@implementation PartBrowserTableView

//========== dragImageForRowsWithIndexes:tableColumns:event:offset: ============
//
// Purpose:		Return a better image for part drag-and-drop.
//
// Notes:		Unfortunately, we can't just return an image of the part itself, 
//			    since its orientation or size can change depending on what view 
//			    it is dragged into. 
//
//==============================================================================
- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows
							tableColumns:(NSArray *)tableColumns
								   event:(NSEvent *)dragEvent
								  offset:(NSPointPointer)dragImageOffset
{
	NSPoint	 offset				= NSZeroPoint;
	NSImage	*dragImage			= [BricksmithUtilities dragImageWithOffset:&offset];
	
	// The NSTableView drag code automatically centers the drag image at the 
	// mouse cursor. Start by counteracting that so it appears directly above 
	// the cursor, as it would if you passed the mouse location directly to 
	// -[NSView dragImage:...]:
	*dragImageOffset = NSMakePoint([dragImage size].width/2, [dragImage size].height/2);
	
	// Now move the image over so it looks like a badge next to the cursor:
	//   ...Turns out the arrow cursor image is a 24 x 24 picture, and the arrow 
	//   itself occupies only a small part of the lefthand side of that space. 
	//   We have to resort to a hardcoded assumption that the actual arrow 
	//   picture fills only half the full image.  
	//   ...We subtract from y; it seems the table view is compensating for the 
	//   flippedness of its coordinate system by accepting a natural offset. 
	(*dragImageOffset).x += offset.x;
	(*dragImageOffset).y += offset.y;

	
	return dragImage;
	
}//end dragImageForRows:event:dragImageOffset:


//========== keyDown: ==========================================================
//
// Purpose:		Intercept keyboard events so we can translate Return into a 
//			    double-click. 
//
//==============================================================================
- (void)keyDown:(NSEvent *)theEvent
{
	NSString	*characters = [theEvent charactersIgnoringModifiers];
	unichar		 firstChar	= '\0';
	
	if([characters length] > 0)
		firstChar = [characters characterAtIndex:0];
	
	switch(firstChar)
	{
		case NSEnterCharacter:			// Enter key
		case NSCarriageReturnCharacter:	// Return key
		case NSNewlineCharacter:		// ???
			if([self doubleAction] != NULL)
				[[self target] performSelector:[self doubleAction] withObject:self];
			break;
		
		default:
			[super keyDown:theEvent];
	}
		
}//end keyDown:


@end
