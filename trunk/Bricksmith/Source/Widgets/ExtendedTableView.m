//==============================================================================
//
// File:		ExtendedTableView.m
//
// Purpose:		Provide additional table-view features that Apple forgot.
//
// Modified:	03/7/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "ExtendedTableView.h"


@implementation ExtendedTableView


//========== menuForEvent: =====================================================
//
// Purpose:		Return the contextual menu for the given click event on a 
//				particular row. 
//
// Notes:		NSTableView allows you to control-click on unselected rows and 
//				have them remain unselected. This is undesirable for any table 
//				in which the only actions which may be performed are those 
//				pertaining to the current selection. 
//
//				This method selects the clicked row if not already selected. If 
//				the event did not originate on a row, this does not return a 
//				menu. 
//
//==============================================================================
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
	NSPoint		clickedPoint	= [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger   clickedRow      = 0;
	NSIndexSet  *selectedRows   = [self selectedRowIndexes];
	NSMenu      *contextualMenu = nil;
	
	// We can't do [self clickedRow] without calling [super menuForEvent:theEvent]. 
	// However, that causes the tableview to get stuck in outline-highlight mode 
	// if we control-double-click on an empty row. So we'll get the clicked row 
	// manually. Another side effect is that the row highlight stays solid 
	// instead of turning to an outline, which looks better anyway. 
	clickedRow = [self rowAtPoint:clickedPoint];
	
	if(clickedRow != -1)
	{
		// Call this to get the outline-highlight which is ordinarily provided.
		//contextualMenu  = [super menuForEvent:theEvent];
	
		// If the click occurred outside the selection, replace the current 
		// selection with the clicked row. Now downstream code can simply ask 
		// for the selected row. 
		if([selectedRows containsIndex:clickedRow] == NO)
		{
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:clickedRow]
			  byExtendingSelection:NO];
		}
		
		contextualMenu = [self menu];
	}
	else
	{
		// Not clicking on a row is meaningless, because the contextual menu 
		// only contains items related to a row. 
		contextualMenu = nil;
	}
	
	return contextualMenu;

}//end menuForEvent:


@end
