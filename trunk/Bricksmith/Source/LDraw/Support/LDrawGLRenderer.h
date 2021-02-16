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

// Initialization
- (id) initWithBounds:(Size2)boundsIn;
- (void) prepareOpenGL;

// Drawing
- (void) draw;

// Accessors
- (LDrawDragHandle*) activeDragHandle;
- (BOOL) didPartSelection;
- (Matrix4) getMatrix;
- (BOOL) isTrackingDrag;
- (LDrawDirective *) LDrawDirective;
- (ProjectionModeT) projectionMode;
- (LocationModeT) locationMode;
- (Box2) selectionMarquee;
- (Tuple3) viewingAngle;
- (ViewOrientationT) viewOrientation;
- (CGFloat) zoomPercentage;
- (CGFloat) zoomPercentageForGL;

- (void) setAllowsEditing:(BOOL)flag;
- (void) setBackgroundColorRed:(float)red green:(float)green blue:(float)blue;
- (void) setDelegate:(id<LDrawGLRendererDelegate>)object withScroller:(id<LDrawGLCameraScroller>)scroller;
- (void) setDraggingOffset:(Vector3)offsetIn;
- (void) setGridSpacing:(float)newValue;
- (void) setLDrawDirective:(LDrawDirective *) newFile;
- (void) setGraphicsSurfaceSize:(Size2)size;						// This is how we find out that the visible frame of our window is bigger or smaller
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
- (BOOL) autoscrollPoint:(Point2)point_view relativeToRect:(Box2)viewRect;
//- (NSArray *) getDirectivesUnderPoint:(Point2)point_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
- (NSArray *) getDirectivesUnderRect:(Box2)rect_view amongDirectives:(NSArray *)directives fastDraw:(BOOL)fastDraw;
//- (NSArray *) getPartsFromHits:(NSDictionary *)hits;
- (void) publishMouseOverPoint:(Point2)viewPoint;
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point2)viewPoint;		// This and setZoomPercentage are how we zoom.
- (void) scrollBy:(Vector2)scrollDelta;
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


