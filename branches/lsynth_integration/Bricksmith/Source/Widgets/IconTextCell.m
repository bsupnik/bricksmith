//==============================================================================
//
// File:		IconTextCell.m
//
// Purpose:		Shows both text and an icon in a cell.
//
//				Adopted from an Apple example.
//
//  Created by Allen Smith on 2/24/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "IconTextCell.h"


@implementation IconTextCell

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize the object.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	image           = nil;
	imagePadding    = 3.0;
	
	return self;
	
}//end init


//========== initWithCoder: ====================================================
//
// Purpose:		Called by objects in a Nib file. They still need some defaults.
//
//==============================================================================
- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	image           = nil;
	imagePadding    = 3.0;
	
	return self;
	
}//end initWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this cell. NSTableView calls this all the 
//				time. 
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	IconTextCell *cell = (IconTextCell *)[super copyWithZone:zone];
	
	//The pitfall is that it releases it too. So we have to  retain our 
	// instance variables here.
    cell->image = [image retain];
	
	return cell;
	
}//end copyWithZone:


#pragma mark -
#pragma mark CELL OVERRIDES
#pragma mark -

//========== cellSize ==========================================================
//
// Purpose:		Returns the minimum size for the cell. We need to take into 
//				account the image we have added.
//
//==============================================================================
- (NSSize) cellSize
{
    NSSize cellSize = [super cellSize];
	
	if(image != nil)
		cellSize.width += [image size].width;
    cellSize.width += 2 * imagePadding;
	
    return cellSize;
	
}//end cellSize


//========== titleRectForBounds: ===============================================
//
// Purpose:		Return a vertically-centered title.
//
//==============================================================================
- (NSRect) titleRectForBounds:(NSRect)theRect
{
	NSRect titleRect = [super titleRectForBounds:theRect];
	NSSize titleSize = NSZeroSize;
	
	if(self->verticallyCentersTitle)
	{
		titleSize = [[self attributedStringValue] size];
	
		titleRect.size.height	= titleSize.height;
		titleRect.origin.y		= NSMinY(theRect) + floor((NSHeight(theRect) - NSHeight(titleRect)) / 2);
	}
	
	return titleRect;
}


//========== drawInteriorWithFrame:inView: =====================================
//
// Purpose:		Draw the image we have added, then let the superclass draw the 
//				text.
//
//==============================================================================
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect				textFrame	= cellFrame;
	NSSize				imageSize	= NSZeroSize;
	NSRect				imageFrame	= NSZeroRect;
	NSAffineTransform	*inverter	= [NSAffineTransform transform];
	
    if (image != nil)
	{
		//Divide the cell frame into the image portion and the text portion.
        imageSize = [image size];
        NSDivideRect(cellFrame,
					 &imageFrame, &textFrame,
					 imageSize.width + 2*imagePadding, NSMinXEdge);

		//Shift the image over by the amount of margins we need.
        imageFrame.origin.x	+= imagePadding;
        imageFrame.size		= imageSize;
		
		//now center the image in the frame afforded us.
        if ([controlView isFlipped])
            imageFrame.origin.y += ceil( (NSHeight(cellFrame) + NSHeight(imageFrame)) / 2 );
        else
            imageFrame.origin.y += ceil( (NSHeight(cellFrame) - NSHeight(imageFrame)) / 2 );
				
		//Finally, draw the image. In a flipped view, we must invert the 
		//coordinate system and relocate it appropriately so that the image will 
		//be drawn right-side up. 
        if ([controlView isFlipped])
		{
			[inverter scaleXBy:1.0 yBy:-1.0];
			[inverter translateXBy:0 yBy: -2 * NSMinY(imageFrame)];
		}
		[inverter concat];
		{
			[image drawAtPoint:imageFrame.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		}
		[inverter invert];
 		[inverter concat];
   }
	
	//Now draw the text.
	NSRect titleRect = [self titleRectForBounds:textFrame];
	[super drawInteriorWithFrame:titleRect inView:controlView];

}//end drawInteriorWithFrame:inView:


//========== selectWithFrame:inView:editor:delegate:start:length: ==============
//
// Purpose:		Selects the text to edit; much like editWithFrame
//
//==============================================================================
- (void)selectWithFrame:(NSRect)cellFrame
				 inView:(NSView *)controlView
				 editor:(NSText *)textObject
			   delegate:(id)anObject
				  start:(NSInteger)selectionStart
				 length:(NSInteger)selectionLength
{
	NSRect	textFrame = cellFrame;

    if (image != nil)
	{
        NSSize	imageSize;
        NSRect	imageFrame;
		
		//Divide the cell frame into the image portion and the text portion.
        imageSize = [image size];
        NSDivideRect(cellFrame,
					 &imageFrame, &textFrame,
					 imageSize.width + 2*imagePadding, NSMinXEdge);
	}


    [super selectWithFrame: textFrame
					inView: controlView
					editor: textObject
				  delegate: anObject
					 start: selectionStart
					length: selectionLength];
					
}//end selectWithFrame:inView:editor:delegate:start:length:


//========== editWithFrame:inView:editor:delegate:start:length: ================
//
// Purpose:		Edits the text in the cell. We want to only create an editing 
//				area as big as the text, so we have to subtract out the part 
//				devoted to the image.
//
//==============================================================================
- (void)editWithFrame:(NSRect)cellFrame
			   inView:(NSView *)controlView
			   editor:(NSText *)textObject
			 delegate:(id)anObject
				event:(NSEvent *)theEvent
{
	NSRect	textFrame = cellFrame;
	
	if (image != nil) {
        NSSize	imageSize;
        NSRect	imageFrame;
		
		//Divide the cell frame into the image portion and the text portion.
        imageSize = [image size];
        NSDivideRect(cellFrame,
					 &imageFrame, &textFrame,
					 imageSize.width + 2*imagePadding, NSMinXEdge);
	}
	
	
    [super editWithFrame: textFrame
				  inView: controlView
				  editor: textObject
				delegate: anObject
				   event:(NSEvent *)theEvent ];
				   
}//end editWithFrame:inView:editor:delegate:start:length:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== image ==============================================================
//==============================================================================
- (NSImage *)  image
{
	return image;
	
}//end image


//========== imagePadding ======================================================
//==============================================================================
- (CGFloat) imagePadding
{
	return imagePadding;
	
}//end imagePadding


//========== verticallyCentersTitle ============================================
//==============================================================================
- (BOOL) verticallyCentersTitle
{
	return self->verticallyCentersTitle;
}

#pragma mark -

//========== setImage: =========================================================
//
// Purpose:		Changes the image displayed along with the text in this cell.
//
//==============================================================================
- (void) setImage:(NSImage *)newImage
{
	[newImage retain];
	[image release];
	image = newImage;
	
}//end setImage:


//========== setImagePadding: ==================================================
//
// Purpose:		Sets the number of pixels left blank on the left and right of 
//				the cell's image.
//
//==============================================================================
- (void) setImagePadding:(CGFloat)newAmount
{
	imagePadding = newAmount;
	
}//end setImagePadding:


//========== setVerticallyCentersTitle: ========================================
//
// Purpose:		Forces the title to be drawn centered along the y-axis of the 
//				cell.
//
// Notes:		This is also provided by AppKit, but only via private ivars. 
//				Source List tables, for example, magically use the private 
//				flag to achive the same result. However, there is a bug where it 
//				is not applied when the list is scrolled such that a group 
//				header is out of sight before the view appears.
//
//==============================================================================
- (void) setVerticallyCentersTitle:(BOOL)flag
{
	self->verticallyCentersTitle = flag;
}


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//==============================================================================
- (void) dealloc
{
	[image release];
	[super dealloc];
	
}//end dealloc


@end
