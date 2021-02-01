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

@class LDrawViewerContainer;
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
- (NSArray<LDrawViewerContainer*> *) allViewports;
- (id<ViewportArrangerDelegate>) delegate;

- (void) setDelegate:(id<ViewportArrangerDelegate>)delegate;

@end


////////////////////////////////////////////////////////////////////////////////
//
// ViewportArrangerDelegate
//
////////////////////////////////////////////////////////////////////////////////
@protocol ViewportArrangerDelegate <NSObject>

@optional
- (void) viewportArranger:(ViewportArranger *)viewportArranger didAddViewport:(LDrawViewerContainer *)newViewport sourceViewport:(LDrawViewerContainer *)sourceViewport;
- (void) viewportArranger:(ViewportArranger *)viewportArranger willRemoveViewports:(NSSet<LDrawViewerContainer*> *)removingViewports;
- (void) viewportArrangerDidRemoveViewports:(ViewportArranger *)viewportArranger;

@end
