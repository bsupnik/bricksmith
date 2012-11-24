//==============================================================================
//
// File:		ViewportArranger.h
//
// Purpose:		Displays a configurable grid of viewports. The user can add or 
//				remove viewports by clicking buttons embedded in the scrollers 
//				of each viewport. 
//
// Modified:	10/03/2009 Allen Smith. Creation Date.
//
//==============================================================================

#import <Cocoa/Cocoa.h>

#import "ExtendedSplitView.h"

@class ExtendedScrollView;
@protocol ViewportArrangerDelegate;

////////////////////////////////////////////////////////////////////////////////
//
// class ViewportArranger
//
////////////////////////////////////////////////////////////////////////////////
@interface ViewportArranger : ExtendedSplitView <NSSplitViewDelegate>
{
	id<ViewportArrangerDelegate>    delegate;
}

// Accessors
- (NSArray *) allViewports;
- (id<ViewportArrangerDelegate>) delegate;

- (void) setDelegate:(id<ViewportArrangerDelegate>)delegate;

// Actions
- (IBAction) splitViewportClicked:(id)sender;
- (IBAction) closeViewportClicked:(id)sender;

// Utilities
- (NSButton *) newCloseButton;
- (NSButton *) newSplitButton;
- (NSView *) newSplitPlacard;
- (NSView *) newSplitClosePlacard;
- (ExtendedScrollView *) newViewport;
- (void) doFrameSanityCheck;
- (void) doFrameSanityCheckForSplitView:(NSSplitView *)splitView;
- (void) restoreViewportsWithAutosaveName:(NSString *)autosaveName;
- (void) storeViewports;
- (void) updateAutosaveNames;
- (void) updatePlacardsForViewports;

@end


////////////////////////////////////////////////////////////////////////////////
//
// ViewportArrangerDelegate
//
////////////////////////////////////////////////////////////////////////////////
@protocol ViewportArrangerDelegate <NSObject>

@optional
- (void) viewportArranger:(ViewportArranger *)viewportArranger didAddViewport:(ExtendedScrollView *)newViewport sourceViewport:(ExtendedScrollView *)sourceViewport;
- (void) viewportArranger:(ViewportArranger *)viewportArranger willRemoveViewports:(NSSet *)removingViewports;
- (void) viewportArrangerDidRemoveViewports:(ViewportArranger *)viewportArranger;

@end