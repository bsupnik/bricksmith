//==============================================================================
//
// File:		TableViewCategory.m
//
// Purpose:		NSTableView added functionality.
//
// Modified:	04/01/2012 Allen Smith. Creation Date.
//
//==============================================================================
#import "TableViewCategory.h"

#import <math.h>


@implementation NSTableView (TableViewCategory)

//========== scrollRowToCenter: ================================================
//
// Purpose:		Scrolls the table view's clip view such that the row is centered 
//				in the scroll view. 
//
//==============================================================================
- (void) scrollRowToCenter:(NSInteger)rowIndex
{
	NSRect	rowRect 	= [self rectOfRow:rowIndex];
	NSRect	scrollFrame = [[self enclosingScrollView] documentVisibleRect];
	NSPoint scrollPoint = NSZeroPoint;
	
	scrollFrame = [self convertRect:scrollFrame fromView:[[self enclosingScrollView] documentView]];
	scrollPoint = rowRect.origin;
	
	scrollPoint.y -= NSHeight(scrollFrame) / 2;
	scrollPoint.y += NSHeight(rowRect) / 2;
	
	scrollPoint.y = floor(scrollPoint.y);
	scrollPoint.y = MAX(0, scrollPoint.y);
	
	[self scrollPoint:scrollPoint];
}


@end
