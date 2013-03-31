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

//Forward declarations
@class LDrawDirective;
@class LDrawDragHandle;
@protocol LDrawGLRendererDelegate;


////////////////////////////////////////////////////////////////////////////////
//
//		Types
//
////////////////////////////////////////////////////////////////////////////////

// Projection Mode
typedef enum
{
	ProjectionModePerspective	= 0,
	ProjectionModeOrthographic	= 1
	
} ProjectionModeT;


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
	id							target;
	SEL 						backAction;
	SEL 						forwardAction;
	SEL 						nudgeAction;
	BOOL						allowsEditing;
	
	LDrawDirective          *fileBeingDrawn;		// Should only be an LDrawFile or LDrawModel.
													// if you want to do anything else, you must 
													// tweak the selection code in LDrawDrawableElement
													// and here in -mouseUp: to handle such cases.
	
	// Drawing Environment
	Size2					bounds;
	Box2					visibleRect;
	Size2					maximumVisibleSize;
	BOOL					viewportExpandsToAvailableSize;
	float					zoomFactor;
	
	GLfloat                 cameraDistance;			// location of camera on the z-axis; distance from (0,0,0);
	Point3					rotationCenter;
	Size2					snugFrameSize;
	LDrawColor				*color;					// default color to draw parts if none is specified
	GLfloat                 glBackgroundColor[4];
	Box2					selectionMarquee;		// in view coordinates. ZeroBox2 means no marquee.
	ProjectionModeT         projectionMode;
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
- (Matrix4) getInverseMatrix;
- (Matrix4) getMatrix;
- (BOOL) isTrackingDrag;
- (LDrawDirective *) LDrawDirective;
- (Vector3) nudgeVector;
- (ProjectionModeT) projectionMode;
- (Box2) selectionMarquee;
- (Tuple3) viewingAngle;
- (ViewOrientationT) viewOrientation;
- (Box2) viewport;
- (Box2) visibleRect;
- (CGFloat) zoomPercentage;

- (void) setAllowsEditing:(BOOL)flag;
- (void) setBackAction:(SEL)newAction;
- (void) setBackgroundColorRed:(float)red green:(float)green blue:(float)blue;
- (void) setBounds:(Size2)boundsIn;
- (void) setDelegate:(id<LDrawGLRendererDelegate>)object;
- (void) setDraggingOffset:(Vector3)offsetIn;
- (void) setForwardAction:(SEL)newAction;
- (void) setGridSpacing:(float)newValue;
- (void) setLDrawDirective:(LDrawDirective *) newFile;
- (void) setMaximumVisibleSize:(Size2)size;
- (void) setNudgeAction:(SEL)newAction;
- (void) setProjectionMode:(ProjectionModeT) newProjectionMode;
- (void) setSelectionMarquee:(Box2)newBox;
- (void) setTarget:(id)target;
- (void) setViewingAngle:(Tuple3)newAngle;
- (void) setViewOrientation:(ViewOrientationT) newAngle;
- (void) setViewportExpandsToAvailableSize:(BOOL)flag;
- (void) setZoomPercentage:(CGFloat) newPercentage;

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
- (void) rotationDragged:(Vector2)viewDirection;
- (void) zoomDragged:(Vector2)viewDirection;
- (void) mouseSelectionDragToPoint:(Point2)point_view selectionMode:(SelectionModeT) selectionMode;
- (void) beginGesture;
- (void) endGesture;
- (void) rotateByDegrees:(float)angle;

// Drag and Drop
- (void) draggingEnteredAtPoint:(Point2)point_view directives:(NSArray *)directives setTransform:(BOOL)setTransform originatedLocally:(BOOL)originatedLocally;
- (void) endDragging;
- (void) updateDragWithPosition:(Point2)point_view constrainAxis:(BOOL)constrainAxis;
- (BOOL) updateDirectives:(NSArray *)directives withDragPosition:(Point2)point_view depthReferencePoint:(Point3)modelReferencePoint constrainAxis:(BOOL)constrainAxis;

// Notifications
- (void) displayNeedsUpdating:(NSNotification *)notification;
- (void) reshape;

// Utilities
//- (NSArray *) getDirectivesUnderPoint:(Point2)point_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
- (NSArray *) getDirectivesUnderRect:(Box2)rect_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
//- (NSArray *) getPartsFromHits:(NSDictionary *)hits;
- (void) publishMouseOverPoint:(Point2)viewPoint;
- (void) resetFrameSize;
- (void) resetVisibleRect;
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point2)viewPoint;
- (void) scrollCenterToModelPoint:(Point3)modelPoint;
- (void) scrollModelPoint:(Point3)modelPoint toViewportProportionalPoint:(Point2)viewportPoint;
- (void) scrollCenterToPoint:(Point2)newCenter;
- (void) scrollRectToVisible:(Box2)aRect notifyDelegate:(BOOL)notify;
- (void) updateRotationCenter;

// - Geometry
- (Point2) convertPointFromViewport:(Point2)viewportPoint;
- (Point2) convertPointToViewport:(Point2)point_view;
- (float) fieldDepth;
- (void) getModelAxesForViewX:(Vector3 *)outModelX Y:(Vector3 *)outModelY Z:(Vector3 *)outModelZ;
- (void) makeProjection;
- (Point3) modelPointForPoint:(Point2)viewPoint;
- (Point3) modelPointForPoint:(Point2)viewPoint depthReferencePoint:(Point3)depthPoint;
- (Box2) nearOrthoClippingRectFromVisibleRect:(Box2)visibleRect;
- (Box2) nearFrustumClippingRectFromVisibleRect:(Box2)visibleRect;
- (Box2) nearOrthoClippingRectFromNearFrustumClippingRect:(Box2)visibilityPlane;
- (Box2) visibleRectFromNearOrthoClippingRect:(Box2)visibilityPlane;
- (Box2) visibleRectFromNearFrustumClippingRect:(Box2)visibilityPlane;

@end


////////////////////////////////////////////////////////////////////////////////
//
//		Delegate Methods
//
////////////////////////////////////////////////////////////////////////////////
@protocol LDrawGLRendererDelegate <NSObject>

@required
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer scrollToRect:(Box2)scrollRect;
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer didSetBoundsToSize:(Size2)newBoundsSize;
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer didSetZoomPercentage:(CGFloat)newZoomPercent;
- (void) LDrawGLRendererNeedsCurrentContext:(LDrawGLRenderer *)renderer;
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


