//==============================================================================
//
// File:		ViewportArranger.m
//
// Purpose:		Displays a configurable grid of viewports. The user can add or 
//				remove viewports by clicking buttons embedded in the scrollers 
//				of each viewport. 
//
// Modified:	10/02/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "ViewportArranger.h"

#import "ExtendedScrollView.h"


const NSString *VIEWS_PER_COLUMN				= @"ViewsPerColumn";


@implementation ViewportArranger

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithFrame: ====================================================
//
// Purpose:		Raw initialization.
//
// Notes:		Due to the way this class is programmed, it makes no sense to 
//				have a pre-popluated split view in Interface Builder. Just use a 
//				custom-classed NSView. For that reason, we don't need 
//				-initWithCoder: 
//
//==============================================================================
- (id) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
	[self setVertical:YES];
	
	return self;

}//end initWithCoder:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== allViewports ======================================================
//
// Purpose:		Returns an array of all the scroll views managed by this 
//				viewport arranger. 
//
//==============================================================================
- (NSArray *) allViewports
{
	NSUInteger      columnCounter   = 0;
	NSUInteger      rowCounter      = 0;
	NSArray         *columns        = [self subviews];
	NSArray         *rows           = nil;
	NSSplitView     *column         = nil;
	NSScrollView    *row            = nil;
	NSMutableArray  *viewports      = [NSMutableArray array];
	
	// Count up all the GL views in each column
	for(columnCounter = 0; columnCounter < [columns count]; columnCounter++)
	{
		column  = [columns objectAtIndex:columnCounter];
		rows    = [column subviews];
		
		for(rowCounter = 0; rowCounter < [rows count]; rowCounter++)
		{
			row = [rows objectAtIndex:rowCounter];
			[viewports addObject:row];
		}
	}
	
	return viewports;
	
}//end allViewports


//========== delegate ==========================================================
//==============================================================================
- (id<ViewportArrangerDelegate>) delegate
{
	return self->delegate;
}


//========== setAutosaveName: ==================================================
//
// Purpose:		Sets the name under which this split view is saved.
//
//==============================================================================
- (void) setAutosaveName:(NSString *)newName
{
	[self restoreViewportsWithAutosaveName:newName];

	// Autosave for column widths
	[super setAutosaveName:newName];
	
	// Autosaves for row heights in each column.
	[self updateAutosaveNames];
	
	[self doFrameSanityCheck];
	
}//end setAutosaveName:


//========== setDelegate: ======================================================
//
// Purpose:		Sets the object which is notified on viewport changes.
//
//==============================================================================
- (void) setDelegate:(id<ViewportArrangerDelegate>)delegateIn
{
	self->delegate = delegateIn;
	
}//end setDelegate:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== splitViewportClicked: =============================================
//
// Purpose:		Cleave the viewport in half, and add a new viewport in the new 
//				half. 
//
// Notes:		Option-click the button to split horizontally instead of 
//				vertically. 
//
//==============================================================================
- (IBAction) splitViewportClicked:(id)sender
{
	NSView              *placardView        = [sender superview];
	ExtendedScrollView  *sourceViewport     = (ExtendedScrollView*)[placardView superview]; // enclosingScrollView won't work here.
	NSSplitView         *sourceColumn       = (NSSplitView*)[sourceViewport superview];
	NSSplitView         *arrangementView    = (NSSplitView*)[sourceColumn superview];
	
	ExtendedSplitView   *newColumn          = nil;
	ExtendedScrollView  *newViewport        = [[self newViewport] autorelease];
	
	NSRect              sourceViewFrame     = NSZeroRect;
	NSRect              newViewFrame        = NSZeroRect;
	BOOL                makeNewColumn       = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	
	if(makeNewColumn == YES)
	{
		sourceViewFrame = [sourceColumn frame];
		newColumn       = [[[ExtendedSplitView alloc] initWithFrame:NSMakeRect(0,0,12,12)] autorelease];
		[newColumn setDelegate:self];
		
		
		// Split the current viewport frame in two.
		newViewFrame                = sourceViewFrame;
		newViewFrame.size.width     = (NSWidth(sourceViewFrame) - [arrangementView dividerThickness]) / 2;
		newViewFrame.origin.x       += NSWidth(newViewFrame) + [arrangementView dividerThickness];
		newViewFrame				= NSIntegralRect(newViewFrame);
		
		sourceViewFrame.size.width  = NSWidth(newViewFrame);
		
		[sourceColumn	setFrame:sourceViewFrame];
		[newColumn		setFrame:newViewFrame];
		
		// Add Views
		[newColumn addSubview:newViewport];
		[arrangementView addSubview:newColumn positioned:NSWindowAbove relativeTo:sourceColumn];
		[arrangementView adjustSubviews];
	}
	// Make a new row within the column.
	else
	{
		sourceViewFrame = [sourceViewport frame];
		
		// Split the current viewport frame in two.
		newViewFrame                = sourceViewFrame;
		newViewFrame.size.height    = (NSHeight(sourceViewFrame) - [sourceColumn dividerThickness]) / 2;
		newViewFrame				= NSIntegralRect(newViewFrame);
		
		sourceViewFrame.origin.y    += NSHeight(newViewFrame) + [sourceColumn dividerThickness];
		sourceViewFrame.size.height = NSHeight(newViewFrame);
		
		[sourceViewport	setFrame:sourceViewFrame];
		[newViewport	setFrame:newViewFrame];
		
		// Add the new viewport.
		// (Note that "Above" ordering means spatially below in a split view.)
		[sourceColumn addSubview:newViewport positioned:NSWindowAbove relativeTo:sourceViewport];
		[sourceColumn adjustSubviews];
	}
	
	if([self->delegate respondsToSelector:@selector(viewportArranger:didAddViewport:sourceViewport:)])
		[self->delegate viewportArranger:self didAddViewport:newViewport sourceViewport:sourceViewport];
		
	[self updatePlacardsForViewports];
	[self storeViewports];
	
}//end splitViewportClicked:


//========== closeViewportClicked: =============================================
//
// Purpose:		Remove the current viewport. If it is the last viewport in its 
//				column, removes the entire column. 
//
//==============================================================================
- (IBAction) closeViewportClicked:(id)sender
{
	NSView              *placardView        = [sender superview];
	ExtendedScrollView  *sourceViewport     = (ExtendedScrollView*)[placardView superview]; // enclosingScrollView won't work here.
	NSSplitView         *sourceColumn       = (NSSplitView*)[sourceViewport superview];
	NSSplitView         *arrangementView    = (NSSplitView*)[sourceColumn superview];
	
	NSArray             *columns            = [arrangementView subviews];
	NSArray             *rows               = [sourceColumn subviews];
	NSUInteger          sourceViewIndex     = 0;
	NSSplitView         *preceedingColumn   = nil;
	ExtendedScrollView  *preceedingRow      = nil;
	
	NSRect              newViewFrame        = NSZeroRect;
	BOOL                removingColumn      = [rows count] == 1; // last row in column?
	BOOL                isFirstResponder    = NO;
	NSResponder         *newFirstResponder  = nil;
	NSSet				*viewportsToRemove	= nil;
	
	// If the doomed viewport is the first responder, then the view which 
	// inherits the source's real estate should also inherit responder status. 
	// (In Bricksmith, the first responder gl view is observed via KVO, so it is 
	// doubly important to relinquish responder status before deallocation.) 
	isFirstResponder    = ([[sourceViewport window] firstResponder] == [sourceViewport documentView]);
	
	if(removingColumn == YES)
	{
		sourceViewIndex     = [columns indexOfObjectIdenticalTo:sourceColumn];
		viewportsToRemove   = [NSSet setWithArray:[sourceColumn subviews]];
		
		// If removing the first column, the column to the right grows leftward 
		// to fill the empty space. Otherwise, the column to the left grows 
		// rightward. 
		if(sourceViewIndex == 0)
		{
			preceedingColumn	= [columns objectAtIndex:(sourceViewIndex + 1)];
		}
		else
		{
			preceedingColumn	= [columns objectAtIndex:(sourceViewIndex - 1)];
		}

		newViewFrame            = [preceedingColumn frame];
		newViewFrame.size.width += [arrangementView dividerThickness] + NSWidth([sourceColumn frame]);
		
		if(isFirstResponder == YES)
		{
			// Bequeath responder status to the first view in the column which 
			// inherits the real estate.
			newFirstResponder = [[[preceedingColumn subviews] objectAtIndex:0] documentView];
			[[sourceViewport window] makeFirstResponder:newFirstResponder];
		}
		
		// Remove the View
		if([self->delegate respondsToSelector:@selector(viewportArranger:willRemoveViewports:)])
		{
			[self->delegate viewportArranger:self willRemoveViewports:viewportsToRemove];
		}
		[sourceColumn removeFromSuperview];
		[preceedingColumn setFrame:newViewFrame];
	}
	else // removing row
	{
		sourceViewIndex     = [rows indexOfObjectIdenticalTo:sourceViewport];
		viewportsToRemove   = [NSSet setWithObject:sourceViewport];
		
		// If removing the first row, the row underneath it grows upward to fill 
		// the empty space. Otherwise, the row above it grows downward. 
		if(sourceViewIndex == 0)
		{
			preceedingRow	= [rows objectAtIndex:(sourceViewIndex + 1)];
		}
		else
		{
			preceedingRow	= [rows objectAtIndex:(sourceViewIndex - 1)];
		}
				
		newViewFrame                = [preceedingRow frame];
		newViewFrame.size.height	+= NSHeight([sourceViewport frame]) + [sourceColumn dividerThickness];
		
		if(isFirstResponder == YES)
		{
			// Bequeath responder status to the view which inherits the real 
			// estate. 
			newFirstResponder = [preceedingRow documentView];
			[[sourceViewport window] makeFirstResponder:newFirstResponder];
		}
		
		// Remove the View
		if([self->delegate respondsToSelector:@selector(viewportArranger:willRemoveViewports:)])
		{
			[self->delegate viewportArranger:self willRemoveViewports:viewportsToRemove];
		}
		[sourceViewport removeFromSuperview];
		[preceedingRow setFrame:newViewFrame];
	}
	// For some reason, setting the frame isn't enough to retile scrollviews 
	// contained within, but this is. 
	[self adjustSubviews];
	
	if([self->delegate respondsToSelector:@selector(viewportArrangerDidRemoveViewports:)])
		[self->delegate viewportArrangerDidRemoveViewports:self];
		
	[self doFrameSanityCheck];
	[self updatePlacardsForViewports];
	[self storeViewports];

}//end closeViewportClicked:


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//**** NSSplitView ****
//========== splitView:canCollapseSubview: =====================================
//
// Purpose:		Collapsing is good if we don't like this multipane view deal.
//
//==============================================================================
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
	
}//end splitView:canCollapseSubview:


//**** NSSplitView ****
//========== splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex: ===
//
// Purpose:		Allow split views to collapse when their divider is 
//				double-clicked. 
//
//==============================================================================
- (BOOL)              splitView:(NSSplitView *)splitView
		  shouldCollapseSubview:(NSView *)subview
 forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	return YES;
	
}//end splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== newCloseButton ====================================================
//
// Purpose:		Returns a new button for closing the current viewport. The 
//				caller is responsible for releasing the button. 
//
//==============================================================================
- (NSButton *) newCloseButton
{
	NSButton    *closeButton    = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 12, 12)];
	
	[closeButton setBezelStyle:NSShadowlessSquareBezelStyle];
	[closeButton setButtonType:NSMomentaryPushInButton];
	[closeButton setBordered:NO];
	[closeButton setImagePosition:NSImageOnly];
	[closeButton setImage:[NSImage imageNamed:@"PlacardButtonClose12"]];
	[closeButton setToolTip:NSLocalizedString(@"ViewportArrangerCloseButtonTooltip", nil)];
	[closeButton setTarget:self];
	[closeButton setAction:@selector(closeViewportClicked:)];
	
	return closeButton;
	
}//end newCloseButton


//========== newSplitButton ====================================================
//
// Purpose:		Returns a new button to split the current viewport. The caller 
//				is responsible for releasing it. 
//
//==============================================================================
- (NSButton *) newSplitButton
{
	NSButton    *splitButton    = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 12, 12)];
	
	[splitButton setBezelStyle:NSShadowlessSquareBezelStyle];
	[splitButton setButtonType:NSMomentaryPushInButton];
	[splitButton setBordered:NO];
	[splitButton setImagePosition:NSImageOnly];
	[splitButton setImage:[NSImage imageNamed:@"PlacardButtonSplit12"]];
	[splitButton setToolTip:NSLocalizedString(@"ViewportArrangerSplitButtonTooltip", nil)];
	[splitButton setTarget:self];
	[splitButton setAction:@selector(splitViewportClicked:)];
	
	return splitButton;
	
}//end newSplitButton


//========== newSplitPlacard ===================================================
//
// Purpose:		Create a view containing a pane-splitter button.
//
// Notes:		We do this programmatically rather than by a prototype from a 
//				nib file because it's not possible to fully duplicate views by 
//				archiving/unarchiving--the target and tooltip are getting lost. 
//
//==============================================================================
- (NSView *) newSplitPlacard
{
	NSButton    *splitButton        = [[self newSplitButton] autorelease];
	NSView      *placardContainer   = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 12, 12)];
	
	[placardContainer addSubview:splitButton];
	
	return placardContainer;
	
}//end newSplitPlacard


//========== newSplitClosePlacard ==============================================
//
// Purpose:		Create a view containing a pane-splitter button and a close 
//				button. 
//
// Notes:		We do this programmatically rather than by a prototype from a 
//				nib file because it's not possible to fully duplicate views by 
//				archiving/unarchiving--the target and tooltip are getting lost. 
//
//==============================================================================
- (NSView *) newSplitClosePlacard
{
	NSButton    *splitButton        = [[self newSplitButton] autorelease];
	NSButton    *closeButton        = [[self newCloseButton] autorelease];
	NSView      *placardContainer   = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 12, 24)];
	
	[placardContainer addSubview:splitButton];
	[placardContainer addSubview:closeButton];
	
	[splitButton setFrameOrigin:NSMakePoint(0, NSMaxY([closeButton frame]))];
	[closeButton setFrameOrigin:NSMakePoint(0, 0)];
	
	return placardContainer;
	
}//end newSplitClosePlacard


//========== newViewport =======================================================
//
// Purpose:		Creates a new 3D viewport nested in a scroll view.
//
// Notes:		Per Cocoa naming conventions, the caller is responsible for 
//				releasing the returned object. 
//
//==============================================================================
- (ExtendedScrollView *) newViewport
{
	ExtendedScrollView  *rowView            = nil;
	
	// container scrollview
	rowView = [[ExtendedScrollView alloc] initWithFrame:NSMakeRect(0, 0, 256, 256)];
	[rowView setHasHorizontalScroller:YES];
	[rowView setHasVerticalScroller:YES];
	[rowView setDrawsBackground:YES];
	[rowView setBorderType:NSBezelBorder];
	[[rowView horizontalScroller] setControlSize:NSSmallControlSize];
	[[rowView verticalScroller]   setControlSize:NSSmallControlSize];
	[[rowView contentView] setCopiesOnScroll:NO];
	
	return rowView;
	
}//end newViewport


#pragma mark -

//========== doFrameSanityCheck ================================================
//
// Purpose:		It's possible to have no views visible, and Cocoa will blithely 
//				restore this bad state across saves. Here's how it happens:
//				 * Create two rows in a column
//				 * Collapse a row by dragging the divider to the top or bottom. 
//				   (Do not double click!) 
//				 * Close the remaining visible view.
//
//				Poof! Now nothing is visible in the column. Ahh, an Apple bug!
//
//==============================================================================
- (void) doFrameSanityCheck
{
	NSArray     *columns        = [self subviews];
	NSSplitView	*currentColumn	= nil;
	NSUInteger  columnCounter   = 0;
	
	// Fix column sanity
	[self doFrameSanityCheckForSplitView:self];
	
	// Fix row sanity
	for(columnCounter = 0; columnCounter < [columns count]; columnCounter++)
	{
		currentColumn   = [columns objectAtIndex:columnCounter];
		[self doFrameSanityCheckForSplitView:currentColumn];
	}
	
}//end doFrameSanityCheck


//========== doFrameSanityCheckForSplitView: ===================================
//
// Purpose:		Ensure there is at least one visible subview in the split view. 
//				See -doFrameSanityCheck for discussion. 
//
//==============================================================================
- (void) doFrameSanityCheckForSplitView:(NSSplitView *)splitView
{
	NSArray     *subviews       = [splitView subviews];
	BOOL        isSane          = NO;
	NSSplitView *currentView    = nil;
	NSUInteger  counter         = 0;
	
	// Try to find a sane row
	for(counter = 0; counter < [subviews count] && isSane == NO; counter++)
	{
		currentView = [subviews objectAtIndex:counter];
		if([splitView isSubviewCollapsed:currentView] == NO)
		{
			isSane = YES;
		}
	}
	
	if(isSane == NO)
	{
		// We use an quasi-documented trick, mentioned only in the Leopard 
		// release notes, that collapsed subviews are merely hidden. 
		[currentView setHidden:NO];
		[splitView adjustSubviews];
	}
}//end doFrameSanityCheckForSplitView:


//========== restoreViewports ==================================================
//
// Purpose:		Restores the number, layout, and sizes of the user-configurable 
//				LDrawGLViews displayed on the document. 
//
// Notes:		The autosave name must be passed to this method because it 
//				cannot be set in the superclass until AFTER this method has 
//				completed. Calling -[super setAutosaveName:] instantly restores 
//				the viewports, but they won't exist until they're created here. 
//
//==============================================================================
- (void) restoreViewportsWithAutosaveName:(NSString *)autosaveNameIn
{
	NSUserDefaults      *userDefaults       = [NSUserDefaults standardUserDefaults];
	NSString			*preferenceKey		= [NSString stringWithFormat:@"%@_%@", autosaveNameIn, VIEWS_PER_COLUMN];
	NSArray             *viewCountPerColumn = [userDefaults objectForKey:preferenceKey];
	ExtendedSplitView   *columnView         = nil;
	ExtendedScrollView  *rowView            = nil;
	NSUInteger          rows                = 0;
	NSUInteger          columnCounter       = 0;
	NSUInteger          rowCounter          = 0;
	
	// Defaults: 1 main viewer; 3 detail views to the right
	if(viewCountPerColumn == nil || [viewCountPerColumn count] == 0)
	{
		viewCountPerColumn = [NSArray arrayWithObjects:
								  [NSNumber numberWithInt:1],
								  [NSNumber numberWithInt:3],
								  nil ];
	}
	
	// Remove all existing views
	while([[self subviews] count] > 0)
	{
		[[[self subviews] objectAtIndex:0] removeFromSuperview];
	}
	
	// Recreate whatever was in use last
	for(columnCounter = 0; columnCounter < [viewCountPerColumn count]; columnCounter++)
	{
		rows = [[viewCountPerColumn objectAtIndex:columnCounter] integerValue];
		
		// The Column. 
		columnView = [[[ExtendedSplitView alloc] initWithFrame:NSMakeRect(0, 0, 256, 256)] autorelease];
		[columnView setDelegate:self];
		[self addSubview:columnView];
		
		// The Rows
		for(rowCounter = 0; rowCounter < rows; rowCounter++)
		{
			rowView = [[self newViewport] autorelease];
			[columnView addSubview:rowView];
			
			if([self->delegate respondsToSelector:@selector(viewportArranger:didAddViewport:sourceViewport:)])
				[self->delegate viewportArranger:self didAddViewport:rowView sourceViewport:nil];
		}
		[columnView adjustSubviews];
	}
	
	// The default initial view should have one viewport occupying 2/3rds of the 
	// viewing area. (This code will get overridden if the splitviews have been 
	// autosaved, which is good.)
	if([[self subviews] count] >= 2)
	{
		NSRect  firstColumnFrame    = [[[self subviews] objectAtIndex:0] frame];
		NSRect  secondColumnFrame   = [[[self subviews] objectAtIndex:1] frame];
		
		firstColumnFrame.size.width     = NSWidth([self frame]) * 0.66;
		secondColumnFrame.size.width    = NSWidth([self frame]) * 0.34;
		
		firstColumnFrame    = NSIntegralRect(firstColumnFrame);
		secondColumnFrame   = NSIntegralRect(secondColumnFrame);
		
		[[[self subviews] objectAtIndex:0] setFrame:firstColumnFrame];
		[[[self subviews] objectAtIndex:1] setFrame:secondColumnFrame];
	}
	
	[self adjustSubviews];
	[self updatePlacardsForViewports];
	
}//end restoreViewports


//========== storeViewports ====================================================
//
// Purpose:		Stores the layout of the viewports so it can be restored next 
//				time. 
//
//==============================================================================
- (void) storeViewports
{
	NSUserDefaults  *userDefaults       = [NSUserDefaults standardUserDefaults];
	NSString		*preferenceKey		= nil;
	NSMutableArray  *viewCountPerColumn = [NSMutableArray array];
	NSArray         *columns            = [self subviews];
	NSSplitView     *currentColumn      = nil;
	NSUInteger      rowCount            = 0;
	NSUInteger      counter             = 0;
	
	// Save rows per column
	for(counter = 0; counter < [columns count]; counter++)
	{
		currentColumn   = [columns objectAtIndex:counter];
		rowCount        = [[currentColumn subviews] count];
		[viewCountPerColumn addObject:[NSNumber numberWithInteger:rowCount]];
	}
	
	// Save it
	preferenceKey = [NSString stringWithFormat:@"%@_%@", [self autosaveName], VIEWS_PER_COLUMN];
	[userDefaults setObject:viewCountPerColumn forKey:preferenceKey];
	
}//end storeViewports


//========== updateAutosaveNames ===============================================
//
// Purpose:		Sets the autosave name for each column in the viewport. (This is 
//				what saves the size of each row in each column.) 
//
//==============================================================================
- (void) updateAutosaveNames
{
	NSString            *baseAutosaveName   = [self autosaveName];
	NSString            *columnAutosaveName = nil;
	ExtendedSplitView   *currentColumn      = nil;
	NSArray             *columns            = [self subviews];
	NSUInteger          counter             = 0;
	
	for(counter = 0; counter < [columns count]; counter++)
	{
		currentColumn       = [columns objectAtIndex:counter];
		columnAutosaveName  = [NSString stringWithFormat:@"%@_Column%d", baseAutosaveName, counter];
		
		[currentColumn setAutosaveName:columnAutosaveName];
	}
	
}//end updateAutosaveNames


//========== updatePlacardsForViewports ========================================
//
// Purpose:		Sets the appropriate spliting control buttons in the scrollbar 
//				area for each viewport. 
//
//==============================================================================
- (void) updatePlacardsForViewports
{
	NSArray             *columns                = [self subviews];
	NSArray             *rows                   = nil;
	NSSplitView         *currentColumn          = nil;
	ExtendedScrollView  *currentRow             = nil;
	NSView              *placard                = nil;
	NSUInteger			columnCount				= [columns count];
	NSUInteger          rowCount                = 0;
	NSUInteger          columnCounter           = 0;
	NSUInteger          rowCounter              = 0;
	
	for(columnCounter = 0; columnCounter < columnCount; columnCounter++)
	{
		currentColumn   = [columns objectAtIndex:columnCounter];
		rows            = [currentColumn subviews];
		rowCount        = [rows count];
		
		// Set the correct placard for each viewport
		for(rowCounter = 0; rowCounter < rowCount; rowCounter++)
		{
			currentRow = [rows objectAtIndex:rowCounter];
			
			// If there only one viewport in the column, disable the close box.
			if(columnCount == 1 && rowCount == 1)
			{
				placard = [[self newSplitPlacard] autorelease];
			}
			else
			{
				placard = [[self newSplitClosePlacard] autorelease];
			}
			
			[currentRow setVerticalPlacard:placard];
		}
	}
}//end updatePlacardsForViewports


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Making our final arrangements.
//
//==============================================================================
- (void) dealloc
{
	[super dealloc];
	
}//end dealloc


@end
