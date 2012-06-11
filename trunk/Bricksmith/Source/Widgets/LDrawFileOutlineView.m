//==============================================================================
//
// File:		LDrawFileOutlineView.m
//
// Purpose:		Outline view which displays the contents of an LDrawFile.
//
//  Created by Allen Smith on 4/10/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawFileOutlineView.h"


@implementation LDrawFileOutlineView

//========== draggingSourceOperationMaskForLocal: ==============================
//
// Purpose:		Due to a bug (as of 10.3) in NSTableView, I need this method to 
//				enable interapplication drags.
//
//==============================================================================
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	if(isLocal == NO)
		return NSDragOperationCopy;
	else
		return [super draggingSourceOperationMaskForLocal:isLocal];
		
}//end draggingSourceOperationMaskForLocal:


//========== selectObjects: ====================================================
//
// Purpose:		Conveniently selects all the the objects in the array which are 
//				visible. Returns the indexes of the selected objects.
//
//==============================================================================
- (NSIndexSet *) selectObjects:(NSArray *)objects
{
	//Select all the objects which have been added.
	id                  currentObject       = nil;
	NSUInteger          indexOfObject       = 0;
	NSMutableIndexSet   *indexesToSelect    = [NSMutableIndexSet indexSet];
	NSInteger           counter             = 0;
	
	//Gather up the indices of the pasted objects.
	for(counter = 0; counter < [objects count]; counter++)
	{
		currentObject = [objects objectAtIndex:counter];
		indexOfObject = [self rowForItem:currentObject];
		[indexesToSelect addIndex:indexOfObject];
	}
	[self selectRowIndexes:indexesToSelect byExtendingSelection:NO];

	return indexesToSelect;
	
}//end selectObjects:


@end
