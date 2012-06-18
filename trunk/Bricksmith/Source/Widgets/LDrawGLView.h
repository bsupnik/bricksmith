//==============================================================================
//
// File:		LDrawGLView.h
//
// Purpose:		This is the intermediary between the operating system (events 
//				and view hierarchy) and the LDrawGLRenderer (responsible for all 
//				platform-independent drawing logic).
//
// Modified:	4/17/05 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "BricksmithUtilities.h"
#import "ColorLibrary.h"
#import "LDrawGLRenderer.h"
#import "LDrawUtilities.h"
#import "MatrixMath.h"
#import "ToolPalette.h"

//Forward declarations
@class FocusRingView;
@class LDrawDirective;
@class LDrawDragHandle;
@class LDrawGLRenderer;


////////////////////////////////////////////////////////////////////////////////
//
//		LDrawGLView
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawGLView : NSOpenGLView <LDrawColorable, LDrawGLRendererDelegate>
{
@private
	// The renderer is responsible for viewport math and OpenGL calls. Because 
	// of the latter, there is NO PUBLIC ACCESS, since each OpenGL call must be 
	// preceeded by activating the correct context. Thus any renderer-modifying 
	// calls must pass through the LDrawOpenGLView first. 
	LDrawGLRenderer			*renderer;
	
	FocusRingView			*focusRingView;
	
	IBOutlet id             delegate;
	id                      target;
	SEL                     backAction;
	SEL                     forwardAction;
	SEL						nudgeAction;
	
	BOOL                    acceptsFirstResponder;	// YES if we can become key
	NSString                *autosaveName;
	
	// Threading
	NSConditionLock			*canDrawLock;			// when condition is YES, render thread will wake up and draw.
	BOOL					keepDrawThreadAlive;	// when it has no items in it, the thread will die
	NSUInteger              numberDrawRequests;		// how many threaded draws are piling up in the queue.
	BOOL					hasThread;
	
	// Event Tracking
	NSTimer                 *mouseDownTimer;		// countdown to beginning drag-and-drop
	BOOL                    canBeginDragAndDrop;	// the next mouse-dragged will initiate a drag-and-drop.  This is based on the timeout for delayed drag mode.
	BOOL                    dragEndedInOurDocument;	// YES if the drag we initiated ended in the document we display
	BOOL					selectionIsMarquee;		// Remembers when a select-click misses and can thus start a marquee.  Only if we HIT an object can we start dragging.
	SelectionModeT			marqueeSelectionMode;
	NSEventType				startingGestureType;
	Vector3					nudgeVector;			// direction of nudge action (valid only in nudgeAction callback)
}

- (void) internalInit;

// Drawing
- (void) draw;
- (void) drawFocusRing;
- (void) strokeInsideRect:(NSRect)rect thickness:(CGFloat)borderWidth;

// Accessors
- (LDrawDirective *) LDrawDirective;
- (Vector3) nudgeVector;
- (ProjectionModeT) projectionMode;
- (Tuple3) viewingAngle;
- (ViewOrientationT) viewOrientation;
- (CGFloat) zoomPercentage;

- (void) setAcceptsFirstResponder:(BOOL)flag;
- (void) setAutosaveName:(NSString *)newName;
- (void) setBackAction:(SEL)newAction;
- (void) setDelegate:(id)object;
- (void) setForwardAction:(SEL)newAction;
- (void) setGridSpacingMode:(gridSpacingModeT)newMode;
- (void) setLDrawDirective:(LDrawDirective *) newFile;
- (void) setNudgeAction:(SEL)newAction;
- (void) setProjectionMode:(ProjectionModeT) newProjectionMode;
- (void) setTarget:(id)target;
- (void) setViewingAngle:(Tuple3)newAngle;
- (void) setViewOrientation:(ViewOrientationT) newAngle;
- (void) setZoomPercentage:(CGFloat) newPercentage;

// Actions
- (IBAction) viewOrientationSelected:(id)sender;
- (IBAction) zoomIn:(id)sender;
- (IBAction) zoomOut:(id)sender;
- (IBAction) zoomToFit:(id)sender;

// Events
- (void) resetCursor;

- (void) nudgeKeyDown:(NSEvent *)theEvent;

- (void) directInteractionDragged:(NSEvent *)theEvent;
- (void) dragAndDropDragged:(NSEvent *)theEvent;
- (void) dragHandleDragged:(NSEvent *)theEvent;

- (void) mousePartSelection:(NSEvent *)theEvent;
- (void) mouseZoomClick:(NSEvent*)theEvent;

- (void) cancelClickAndHoldTimer;

// Notifications

// Utilities
- (void) restoreConfiguration;
- (void) saveConfiguration;
- (void) saveImageToPath:(NSString *)path;
- (void) scrollCenterToModelPoint:(Point3)modelPoint;
- (void) takeBackgroundColorFromUserDefaults;

@end



////////////////////////////////////////////////////////////////////////////////
//
//		Delegate Methods
//
////////////////////////////////////////////////////////////////////////////////
@interface NSObject (LDrawGLViewDelegate)

- (void) LDrawGLViewBecameFirstResponder:(LDrawGLView *)glView;

- (BOOL) LDrawGLView:(LDrawGLView *)glView writeDirectivesToPasteboard:(NSPasteboard *)pasteboard asCopy:(BOOL)copyFlag;
- (void) LDrawGLView:(LDrawGLView *)glView acceptDrop:(id < NSDraggingInfo >)info directives:(NSArray *)directives;
- (void) LDrawGLViewPartsWereDraggedIntoOblivion:(LDrawGLView *)glView;

- (TransformComponents) LDrawGLViewPreferredPartTransform:(LDrawGLView *)glView;

// Delegate method is called when the user has changed the selection of parts 
// by clicking in the view. This does not actually do any selecting; that is 
// left entirely to the delegate. Some may rightly question the design of this 
// system.
- (void) LDrawGLView:(LDrawGLView *)glView wantsToSelectDirective:(LDrawDirective *)directiveToSelect byExtendingSelection:(BOOL) shouldExtend;
- (void) LDrawGLView:(LDrawGLView*)glView wantsToSelectDirectives:(NSArray *)directivesToSelect selectionMode:(SelectionModeT) selectionMode;
- (void) LDrawGLView:(LDrawGLView *)glView willBeginDraggingHandle:(LDrawDragHandle *)dragHandle;
- (void) LDrawGLView:(LDrawGLView *)glView dragHandleDidMove:(LDrawDragHandle *)dragHandle;
- (void) LDrawGLView:(LDrawGLView *)glView mouseIsOverPoint:(Point3)modelPoint confidence:(Tuple3)confidence;
- (void) LDrawGLViewMouseNotPositioning:(LDrawGLView *)glView;
- (void) markPreviousSelection;
- (void) unmarkPreviousSelection;


@end


////////////////////////////////////////////////////////////////////////////////
//
//		Currently-private API
//		which might just be released in an upcoming OS...
//
////////////////////////////////////////////////////////////////////////////////
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface NSEvent (GestureMethods)
- (CGFloat) magnification;
@end
#endif