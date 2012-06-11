//==============================================================================
//
// File:		IconTextCell.h
//
// Purpose:		Shows both text and an icon in a cell.
//
//  Created by Allen Smith on 2/24/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


////////////////////////////////////////////////////////////////////////////////
//
// class IconTextCell
//
////////////////////////////////////////////////////////////////////////////////
@interface IconTextCell : NSTextFieldCell
{
	@private
		NSImage *image;
		CGFloat imagePadding; //amount of space to the left and right of the image.
		BOOL	verticallyCentersTitle;
}

//Accessors
- (NSImage *)image;
- (CGFloat) imagePadding;
- (BOOL) verticallyCentersTitle;

- (void) setImage:(NSImage *)newImage;
- (void) setImagePadding:(CGFloat)newAmount;
- (void) setVerticallyCentersTitle:(BOOL)flag;

@end
