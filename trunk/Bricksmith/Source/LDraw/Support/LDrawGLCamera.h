//
//  LDrawGLCamera.h
//  Bricksmith
//
//  Created by bsupnik on 9/23/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MatrixMath.h"

// Projection Mode
typedef enum
{
	ProjectionModePerspective	= 0,
	ProjectionModeOrthographic	= 1
	
} ProjectionModeT;

typedef enum
{
	LocationModeModel = 0,
	LocationModeWalkthrough = 1
} LocationModeT;

@protocol LDrawGLCameraScroller;


//------------------------------------------------------------------------------
///
/// @class		LDrawGLCamera
///
/// @abstract	Computes the modelview and projection matrices based off current
/// 			viewport dimensions and user viewing options.
///
///			   	Who owns what data?
///
///			   	Things appkit knows about:
///
///			   	Scroll position
///				   owned by the camera.
///
///			   	Zoom
///				   owned by camera.
///
///			   	Document Size - a fiction that could be used to represent scroll bar positions
///				   owned by camera
///
///			   	Viewport (View) Size
///				   owned by AppKit
///				   camera must be told
///
///			   	Things OpenGL knows about:
///				   viewport - always set to visible area of GL drawable by view code - the camera assumes this is true.
///				   transform matrices - always owned by camera.
///
///				The coordinate system is rather weird.
///
///				At zoom=100% (1.0), one point on the screen is equal to one
/// 			LDrawUnit (model unit) in an orthographic projection. In a
/// 			perspective projection, the equivalence is maintained at the
/// 			model origin.
///
///				Scrolling occurs by sliding the visible rect around an infinite
/// 			plane. The coordinate system origin is that of a rectangle with
/// 			size of the viewport, whose *center* is on the model origin. At
/// 			100% zoom, the size of the visible rect is the same as the
/// 			viewport. It is scaled according to the zoom factor.
///
//------------------------------------------------------------------------------
@interface LDrawGLCamera : NSObject

@property (nonatomic, assign) Size2	graphicsSurfaceSize;

- (void)	setScroller:(id<LDrawGLCameraScroller>)newScroller;

// Output - the official OpenGL transform.
- (GLfloat*)getProjection;
- (GLfloat*)getModelView;

// Output - camera meta-data for UI/persistence.  The camera outpust perspective/orthographic and a Euler viewing angle; 
// the client code creates the "known" views.
- (CGFloat) zoomPercentage;
- (ProjectionModeT) projectionMode;
- (LocationModeT) locationMode; 
- (Tuple3) viewingAngle;
- (Point3) rotationCenter;

// These change the cached representation of the 3-d "thing" the camera is looking at.
- (void) setModelSize:(Box3)modelSize;
- (void) setRotationCenter:(Point3)point;

// These change the camera-controllable aspects of the scroller via the camera.
- (void) setZoomPercentage:(CGFloat)newPercentage;
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point3)modelPoint;
- (void) scrollModelPoint:(Point3)modelPoint toViewportProportionalPoint:(Point2)viewportPoint;
- (void) scrollBy:(Vector2)scrollDelta;
- (void) scrollToPoint:(Point2)visibleRectOrigin;

// These change the camera by sending 'rotation' commands of various kinds to the camera.
- (void) setViewingAngle:(Tuple3)newAngle;
- (void) setProjectionMode:(ProjectionModeT)newProjectionMode;
- (void) setLocationMode:(LocationModeT)newLocationMode;
- (void) rotationDragged:(Vector2)viewDirection;
- (void) rotateByDegrees:(float)angle;

@end



//---------- LDrawGLCameraScroller ---------------------------------------------
///
/// The camera scroller protocol abstracts a scrolling view that the camera
///	works within.  The camera owns scrolling information. It has to be told
///	about the view size, and works out the rest. The view container can be
///	notified of scroll/zoom changes via this protocol.
///
@protocol LDrawGLCameraScroller <NSObject>

@required

/// Document size, in model units, and the current visible rect within that
/// coordinate system. The camera can request a document size change; NS code
/// can't change the document size behind the camera's back. Note that the
/// documentRect origin will generally not be at (0,0).
///
/// @param newDocumentRect	A purely imaginary rectangle that represents the
/// 						maximum visible extent of the current view. This is
/// 						given in the camera coordinate system described in
/// 						the class documentation. tl;dr: the (0,0) point is
/// 						not intrinsically meaningful, and is needed only to
/// 						reference the position of the visible rect within
/// 						the logical document size.
///
/// @param visibleRect 		The portion of the documentRect currently visible,
/// 						in the same coordinate system.
- (void) reflectLogicalDocumentRect:(Box2)newDocumentRect visibleRect:(Box2)visibleRect;

/// Called when the view scale factor changes. 1.0 is pixel-to-pixel. 2.0 makes
/// our model look twice as big on screen. The exact same information is
/// conveyed mathematically in -reflectLogicalDocumentRect:visibleRect:.
- (void) reflectScaleFactor:(CGFloat)newScaleFactor;

@end

