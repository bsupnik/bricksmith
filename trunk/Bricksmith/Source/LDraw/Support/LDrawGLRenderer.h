//==============================================================================
//
// File:		LDrawGLRenderer.h
//
// Purpose:		Draws an LDrawFile with OpenGL.
//
// Modified:	4/17/05 Allen Smith. Creation Date.
//
//==============================================================================
#import <Foundation/Foundation.h>
#import OPEN_GL_HEADER

#import "MacLDraw.h"
#import "ColorLibrary.h"
#import "LDrawUtilities.h"
#import "MatrixMath.h"
#import "LDrawGLCamera.h"

//Forward declarations
@class LDrawDirective;
@class LDrawDragHandle;
@protocol LDrawGLRendererDelegate;
@protocol LDrawGLCameraScroller;


////////////////////////////////////////////////////////////////////////////////
//
//		Types
//
////////////////////////////////////////////////////////////////////////////////


// Draw Mode
typedef enum
{
	LDrawGLDrawNormal			= 0,	//full draw
	LDrawGLDrawExtremelyFast	= 1		//bounds only
	
} RotationDrawModeT;


////////////////////////////////////////////////////////////////////////////////
//
//		LDrawGLRenderer
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawGLRenderer : NSObject <LDrawColorable>
{
	id<LDrawGLRendererDelegate> delegate;
	id<LDrawGLCameraScroller>	scroller;
	id							target;
	SEL 						backAction;
	SEL 						forwardAction;
	SEL 						nudgeAction;
	BOOL						allowsEditing;
	
	LDrawDirective          *fileBeingDrawn;		// Should only be an LDrawFile or LDrawModel.
													// if you want to do anything else, you must 
													// tweak the selection code in LDrawDrawableElement
													// and here in -mouseUp: to handle such cases.
	
	LDrawGLCamera *			camera;
	
	// Drawing Environment
	LDrawColor				*color;					// default color to draw parts if none is specified
	GLfloat                 glBackgroundColor[4];
	Box2					selectionMarquee;		// in view coordinates. ZeroBox2 means no marquee.
	RotationDrawModeT       rotationDrawMode;		// drawing detail while rotating.
	ViewOrientationT        viewOrientation;		// our orientation
	NSTimeInterval			fpsStartTime;
	NSInteger				framesSinceStartTime;
	
	// Event Tracking
	float					gridSpacing;
	BOOL                    isGesturing;			// true if performing a multitouch trackpad gesture.
	BOOL                    isTrackingDrag;			// true if the last mousedown was followed by a drag, and we're tracking it (drag-and-drop doesn't count)
	BOOL					isStartingDrag;			// this is the first event in a drag
	NSTimer                 *mouseDownTimer;		// countdown to beginning drag-and-drop
	BOOL                    canBeginDragAndDrop;	// the next mouse-dragged will initiate a drag-and-drop.
	BOOL                    didPartSelection;		// tried part selection during this click
	BOOL                    dragEndedInOurDocument;	// YES if the drag we initiated ended in the document we display
	Vector3                 draggingOffset;			// displacement between part 0's position and the initial click point of the drag
	Point3                  initialDragLocation;	// point in model where part was positioned at draggingEntered
	Vector3					nudgeVector;			// direction of nudge action (valid only in nudgeAction callback)
	LDrawDragHandle			*activeDragHandle;		// drag handle hit on last mouse-down (or nil)
}

// Initialization
- (id) initWithBounds:(Size2)boundsIn;
- (void) prepareOpenGL;

// Drawing
- (void) draw;

// Accessors
- (LDrawDragHandle*) activeDragHandle;
- (Point2) centerPoint;
- (BOOL) didPartSelection;
- (Matrix4) getMatrix;
- (BOOL) isTrackingDrag;
- (LDrawDirective *) LDrawDirective;
- (Vector3) nudgeVector;
- (ProjectionModeT) projectionMode;
- (LocationModeT) locationMode;
- (Box2) selectionMarquee;
- (Tuple3) viewingAngle;
- (ViewOrientationT) viewOrientation;
- (Box2) viewport;
- (CGFloat) zoomPercentage;
- (CGFloat) zoomPercentageForGL;

- (void) setAllowsEditing:(BOOL)flag;
- (void) setBackAction:(SEL)newAction;
- (void) setBackgroundColorRed:(float)red green:(float)green blue:(float)blue;
- (void) setDelegate:(id<LDrawGLRendererDelegate>)object withScroller:(id<LDrawGLCameraScroller>)scroller;
- (void) setDraggingOffset:(Vector3)offsetIn;
- (void) setForwardAction:(SEL)newAction;
- (void) setGridSpacing:(float)newValue;
- (void) setLDrawDirective:(LDrawDirective *) newFile;
- (void) setMaximumVisibleSize:(Size2)size;						// This is how we find out that the visible frame of our window is bigger or smaller
- (void) setNudgeAction:(SEL)newAction;
- (void) setProjectionMode:(ProjectionModeT) newProjectionMode;
- (void) setLocationMode:(LocationModeT) newLocationMode;
- (void) setSelectionMarquee:(Box2)newBox;
- (void) setTarget:(id)target;
- (void) setViewingAngle:(Tuple3)newAngle;
- (void) setViewOrientation:(ViewOrientationT) newAngle;
- (void) setZoomPercentage:(CGFloat) newPercentage;
- (void) moveCamera:(Vector3)delta;

// Actions
- (IBAction) zoomIn:(id)sender;
- (IBAction) zoomOut:(id)sender;
- (IBAction) zoomToFit:(id)sender;

// Events
- (void) mouseMoved:(Point2)point_view;
- (void) mouseDown;
- (void) mouseDragged;
- (void) mouseUp;

- (void) mouseCenterClick:(Point2)viewClickedPoint;
- (BOOL) mouseSelectionClick:(Point2)point_view selectionMode:(SelectionModeT)selectionMode;						// Returns TRUE if we hit any parts at all.
- (void) mouseZoomInClick:(Point2)viewClickedPoint;
- (void) mouseZoomOutClick:(Point2)viewClickedPoint;

- (void) dragHandleDraggedToPoint:(Point2)point_view constrainDragAxis:(BOOL)constrainDragAxis;
- (void) panDragged:(Vector2)viewDirection location:(Point2)point_view;
- (void) rotationDragged:(Vector2)viewDirection;																	// This is how we get track-balled
- (void) zoomDragged:(Vector2)viewDirection;
- (void) mouseSelectionDragToPoint:(Point2)point_view selectionMode:(SelectionModeT) selectionMode;
- (void) beginGesture;
- (void) endGesture;
- (void) rotateByDegrees:(float)angle;																				// Track-pad twist gesture

// Drag and Drop
- (void) draggingEnteredAtPoint:(Point2)point_view directives:(NSArray *)directives setTransform:(BOOL)setTransform originatedLocally:(BOOL)originatedLocally;
- (void) endDragging;
- (void) updateDragWithPosition:(Point2)point_view constrainAxis:(BOOL)constrainAxis;
- (BOOL) updateDirectives:(NSArray *)directives withDragPosition:(Point2)point_view depthReferencePoint:(Point3)modelReferencePoint constrainAxis:(BOOL)constrainAxis;

// Notifications
- (void) displayNeedsUpdating:(NSNotification *)notification;

// Utilities
//- (NSArray *) getDirectivesUnderPoint:(Point2)point_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
- (NSArray *) getDirectivesUnderRect:(Box2)rect_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
//- (NSArray *) getPartsFromHits:(NSDictionary *)hits;
- (void) publishMouseOverPoint:(Point2)viewPoint;
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point2)viewPoint;		// This and setZoomPercentage are how we zoom.
- (void) scrollCenterToModelPoint:(Point3)modelPoint;									// These two are how we do gesture-based scrolls
- (void) scrollModelPoint:(Point3)modelPoint toViewportProportionalPoint:(Point2)viewportPoint;
- (void) updateRotationCenter;															// A camera "property change"

// - Geometry
- (Point2) convertPointFromViewport:(Point2)viewportPoint;
- (Point2) convertPointToViewport:(Point2)point_view;
- (void) getModelAxesForViewX:(Vector3 *)outModelX Y:(Vector3 *)outModelY Z:(Vector3 *)outModelZ;
- (Point3) modelPointForPoint:(Point2)viewPoint;
- (Point3) modelPointForPoint:(Point2)viewPoint depthReferencePoint:(Point3)depthPoint;

@end


////////////////////////////////////////////////////////////////////////////////
//
//		Delegate Methods
//
////////////////////////////////////////////////////////////////////////////////
@protocol LDrawGLRendererDelegate <NSObject>

@required
- (void) LDrawGLRendererNeedsFlush:(LDrawGLRenderer*)renderer;
- (void) LDrawGLRendererNeedsRedisplay:(LDrawGLRenderer*)renderer;

@optional
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer mouseIsOverPoint:(Point3)modelPoint confidence:(Tuple3)confidence;
- (void) LDrawGLRendererMouseNotPositioning:(LDrawGLRenderer*)renderer;

- (TransformComponents) LDrawGLRendererPreferredPartTransform:(LDrawGLRenderer*)renderer;

- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer wantsToSelectDirective:(LDrawDirective *)directiveToSelect byExtendingSelection:(BOOL) shouldExtend;
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer wantsToSelectDirectives:(NSArray *)directivesToSelect selectionMode:(SelectionModeT) selectionMode;
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer willBeginDraggingHandle:(LDrawDragHandle *)dragHandle;
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer dragHandleDidMove:(LDrawDragHandle *)dragHandle;

- (void) markPreviousSelection:(LDrawGLRenderer*)renderer;
- (void) unmarkPreviousSelection:(LDrawGLRenderer*)renderer;



@end


