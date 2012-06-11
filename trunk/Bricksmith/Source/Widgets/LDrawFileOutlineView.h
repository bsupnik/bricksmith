//==============================================================================
//
// File:		LDrawFileOutlineView.h
//
// Purpose:		Outline view which displays the contents of an LDrawFile.
//
//  Created by Allen Smith on 4/10/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface LDrawFileOutlineView : NSOutlineView {

}

- (NSIndexSet *) selectObjects:(NSArray *)objects;

@end
