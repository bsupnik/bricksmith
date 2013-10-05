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
		owned by Appkit.
	
	Zoom
		owned by camera.  Clip view scale factor owned by NS and slaved from zoom by camera _sometimes_.
		
	Document Size
		owned by GL view, controlled by camera
	
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


@interface LDrawGLCamera : NSObject {

	id<LDrawGLCameraScroller>	scroller;
	
	GLfloat					projection[16];
	GLfloat					modelView[16];
	GLfloat					orientation[16];

	ProjectionModeT         projectionMode;
	LocationModeT			locationMode;
	Box3					modelSize;

	BOOL					viewportExpandsToAvailableSize;
	float					zoomFactor;

	GLfloat                 cameraDistance;			// location of camera on the z-axis; distance from (0,0,0);
	Point3					rotationCenter;
	Size2					snugFrameSize;
	
	int						mute;					// Counted 'mute' to stop re-entrant calls to tickle...

}

- (id)		init;
- (void)	dealloc;
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

// These change the camera by sending 'rotation' commands of various kinds to the camera.
- (void) setViewingAngle:(Tuple3)newAngle;
- (void) setProjectionMode:(ProjectionModeT)newProjectionMode;
- (void) setLocationMode:(LocationModeT)newLocationMode;
- (void) rotationDragged:(Vector2)viewDirection;
- (void) rotateByDegrees:(float)angle;

@end



////////////////////////////////////////////////////////////////////////////////
//
//		LDrawGLCameraScroller
//
////////////////////////////////////////////////////////////////////////////////
//
//	The camera scroller protocol abstracts a scrolling view that the camera
//	works within.  The camera does not get to own scrolling information; rather
//	it has to go to the protocol to get current state and make changes.  (We do
//	this because getting in a fight with NSClipView over scrolling is futile; if
//	there can be only one copy of scroll state AppKit has to own it.)
//

@protocol LDrawGLCameraScroller <NSObject>

@required

// Document size, in model units.  The camera can request a document size
// change; NS code won't change the document size behind the camera's back.
- (Size2)	getDocumentSize;
- (void)	setDocumentSize:(Size2)newDocumentSize;

// Scrolling
- (Box2)	getVisibleRect;								// From this we get our scroll position and visible area, in doc units.
- (Size2)	getMaxVisibleSizeDoc;						// Max size we can show in doc units before we scroll.
- (Size2)	getMaxVisibleSizeGL;						// Max size we can show in GL viewport pixels units before we scroll.

- (void)	setScaleFactor:(CGFloat)newScaleFactor;		// This sets the scale factor from UI points to doc units - 2.0 makes our model look twice as big on screen.
- (void)	setScrollOrigin:(Point2)visibleOrigin;		// This scrolls the scroller so that the model point "visibleOrigin" is in the upper right corner of the 
														//visible screen.
@end

