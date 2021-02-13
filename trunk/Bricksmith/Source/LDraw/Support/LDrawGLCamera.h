//
//  LDrawGLCamera.h
//  Bricksmith
//
//  Created by bsupnik on 9/23/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MatrixMath.h"

/*
	Who owns what data?
	
	Things appkit knows about:

	Scroll position
		owned by the camera.
	
	Zoom
		owned by camera.
		
	Document Size - a fiction that could be used to represent scroll bar positions
		owned by camera
 
	Viewport (View) Size
		owned by AppKit
		camera must be told
	
	Things OpenGL knows about:
		viewport - always set to visible area of GL drawable by view code - the camera assumes this is true.
		transform matrices - always owned by camera.
		
 */

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


@interface LDrawGLCamera : NSObject

@property (nonatomic, assign) Size2	graphicsSurfaceSize;
@property (nonatomic, readonly) Box2 visibleRect;

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

// Call this when the scroller's states change in any way, to force the
// camera to 'suck in' the camera scroller parameters.  Clients only need
// to call this when camera scroller properties change; if you call setModelSize,
// the camera tickles itself.  So tickle should really only be called for scroll-bar
// induced scrolling and frame dimension changes via a window resize or splitter move.
- (void) tickle;

// These change the cached representation of the 3-d "thing" the camera is looking at.
- (void) setModelSize:(Box3)modelSize;
- (void) setRotationCenter:(Point3)point;

// These change the camera-controllable aspects of the scroller via the camera.
- (void) setZoomPercentage:(CGFloat)newPercentage;
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point3)modelPoint;
- (void) scrollModelPoint:(Point3)modelPoint toViewportProportionalPoint:(Point2)viewportPoint;
- (void) scrollBy:(Vector2)scrollDelta;

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

/// Document size, in model units.  The camera can request a document size
/// change; NS code won't change the document size behind the camera's back.
- (void) reflectLogicalDocumentSize:(Size2)newDocumentSize viewportRect:(Box2)viewportRect;

/// Is called when the view scale factor changes. 1.0 is pixel-to-pixel. 2.0
/// makes our model look twice as big on screen.
- (void) reflectScaleFactor:(CGFloat)newScaleFactor;

@end

