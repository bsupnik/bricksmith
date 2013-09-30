//
//  LDrawGLCamera.m
//  Bricksmith
//
//  Created by bsupnik on 9/23/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import "LDrawGLCamera.h"
#import "MacLDraw.h"
#import "GLMatrixMath.h"

// Normally the doc size is rounded so that it doesn't jump per frame as we nudge; we can turn this OFF to debug editing.
#define NO_ROUNDING_DOC_SIZE		0

//controls perspective; cameraLocation = modelSize * CAMERA_DISTANCE_FACTOR
#define CAMERA_DISTANCE_FACTOR		6.5	

// Turn-table view changes how rotations work 
#define USE_TURNTABLE				([[NSUserDefaults standardUserDefaults] integerForKey:ROTATE_MODE_KEY] == RotateModeTurntable)


#define WALKTHROUGH_NEAR	20.0
#define WALKTHROUGH_FAR		20000.0

@implementation LDrawGLCamera

#pragma mark -
#pragma mark SETUP
#pragma mark -


//========== init ==============================================================
//
// Purpose:		Sets up the new camera.
//
// Notes:		The camera isn't really useful until a scroller is attached and
//				the camera is then tickled.  Without a scroller, the camera
//				cannot complete its setup.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	viewportExpandsToAvailableSize	= YES;
	
	zoomFactor						= 100; // percent
	cameraDistance					= -10000;
	projectionMode					= ProjectionModePerspective;
	locationMode					= LocationModeModel;
	modelSize						= InvalidBox;
	
	buildRotationMatrix(orientation,180,1,0,0);
	buildIdentity(modelView);
	buildIdentity(projection);
	
	return self;	
}//end init


//========== dealloc ===========================================================
//
// Purpose:		It's time to kick the bucket and go to meet the great head of
//				light entertainment in the sky.
//
//==============================================================================
- (void) dealloc
{
	[super dealloc];
}//end dealloc


//========== setScroller: ======================================================
//
// Purpose:		Specifies a scroller protocol that the camera uses to get
//				information about the document.
//
// Notes:		While the simplest design might be for the camer to control all
//				apsects of viewing, it can't own scrolling; AppKit needs to own
//				scrolling state and having the data exist in two places is a
//				recipe for chaos.
//
//				So the scroller gives the camera an abstract way to ask
//				_someone_ what's going on in the NS world with scrolling without
//				having to have our app's NS structure coded into the camera.
//
//==============================================================================
- (void) setScroller:(id<LDrawGLCameraScroller>)newScroller
{
	scroller = newScroller;
}//end setScroller:


#pragma mark -
#pragma mark PUBLIC ACCESSORS
#pragma mark -


//========== getProjection =====================================================
//
// Purpose:		Returns the current projection matrix as a float[16] ptr.
//				The projection matrix handles the effects of scrolling and
//				zoom.
//
// Notes:		The camera class does not talk to OpenGL directly, and thus
//				does not need context access.  The current matrices are owned
//				by the camera.  Rendering engine code is responsible for syncing
//				OpenGL to the camera, or shoveling these matrices into its
//				custom shaders.
//
//==============================================================================
- (GLfloat*)getProjection
{
	return projection;
	
}//end getProjection


//========== getModelView ======================================================
//
// Purpose:		Returns the current modelview matrix as a float[16] ptr.
//				The modelview matrix accounts for camera view distance, model
//				rotation and model center changes.
//
//==============================================================================
- (GLfloat*)getModelView
{
	return modelView;
	
}//end getModelView


//========== zoomPercentage ====================================================
//
// Purpose:		Returns the current zoom percentage.
//
//==============================================================================
- (CGFloat) zoomPercentage
{
	return self->zoomFactor;
	
}//end zoomPercentage


//========== projectionMode ====================================================
//
// Purpose:		Returns the current projection mode (perspective or ortho).
//
//==============================================================================
- (ProjectionModeT) projectionMode
{
	return self->projectionMode;
	
}//end projectionMode


//========== locationMode ====================================================
//
// Purpose:		Returns the current location mode.
//
//==============================================================================
- (LocationModeT) locationMode
{
	return self->locationMode;
	
}//end locationMode


//========== viewingAngle ======================================================
//
// Purpose:		Returns the current viewing angle as a triplet of Euler angles.
//
//==============================================================================
- (Tuple3) viewingAngle
{
	Matrix4              transformation		= IdentityMatrix4;
	TransformComponents  components			= IdentityComponents;
	Tuple3				 degrees			= ZeroPoint3;
	
	transformation = Matrix4CreateFromGLMatrix4([self getModelView]);
	transformation = Matrix4Rotate(transformation, V3Make(180, 0, 0)); // LDraw is upside-down
	Matrix4DecomposeTransformation(transformation, &components);
	degrees = components.rotate;
	
	degrees.x = degrees(degrees.x);
	degrees.y = degrees(degrees.y);
	degrees.z = degrees(degrees.z);
	
	return degrees;
	
}//end viewingAngle


- (Point3) rotationCenter
{
	return self->rotationCenter;
}


#pragma mark -
#pragma mark INTERNAL UTILITIES
#pragma mark -


//========== scrollCenterToPoint: ==============================================
//
// Purpose:		Scrolls a given model point to the center of the visible window.
//
// Notes:		This utility does not 'tickle' the camera - client code must do
//				this.
//
//==============================================================================
- (void) scrollCenterToPoint:(Point2)newCenter
{
	Box2	newVisibleRect	= [scroller getVisibleRect];
	Point2	scrollOrigin	= V2Make(newCenter.x - V2BoxWidth([scroller getVisibleRect])/2,
									 newCenter.y - V2BoxHeight([scroller getVisibleRect])/2);
	// Sanity check
	if(scrollOrigin.x < 0)
	{
		scrollOrigin.x = 0;
	}
	if(scrollOrigin.y < 0)
	{
		scrollOrigin.y = 0;
	}
	
	newVisibleRect.origin = scrollOrigin;

	[scroller setScrollOrigin:newVisibleRect.origin];
	
}//end scrollCenterToPoint:


//========== fieldDepth ========================================================
//
// Purpose:		Returns the depth range of our view - that is, the distance
//				between the near an far clip planes in model coordinates.  The 
//				model origin is centered in this range.
//
//==============================================================================
- (float) fieldDepth
{
	float	fieldDepth		= 0;
	
	// This is effectively equivalent to infinite field depth
	fieldDepth = MAX(snugFrameSize.height, snugFrameSize.width);
	fieldDepth *= 2;
	
	return fieldDepth;
	
}//end fieldDepth


//========== nearOrthoClippingRectFromVisibleRect: ============================
//
// Purpose:		Returns the rect of the near clipping plane which should be used 
//				for an orthographic projection. The coordinates are in model 
//				coordinates, located on the plane at
//					z = - [self fieldDepth] / 2.
//
//==============================================================================
- (Box2) nearOrthoClippingRectFromVisibleRect:(Box2)visibleRectIn
{
	Box2	visibilityPlane	= ZeroBox2;

	CGFloat y = V2BoxMinY(visibleRectIn);
	if(1)//[self isFlipped] == YES)
	{
		y = [scroller getDocumentSize].height - y - V2BoxHeight(visibleRectIn);
	}
	
	//The projection plane is stated in model coordinates.
	visibilityPlane.origin.x	= V2BoxMinX(visibleRectIn) - [scroller getDocumentSize].width/2;
	visibilityPlane.origin.y	= y - [scroller getDocumentSize].height/2;
	visibilityPlane.size.width	= V2BoxWidth(visibleRectIn);
	visibilityPlane.size.height	= V2BoxHeight(visibleRectIn);
	
	return visibilityPlane;
	
}//end nearOrthoClippingRectFromVisibleRect:


//========== nearFrustumClippingRectFromVisibleRect: ==========================
//
// Purpose:		Returns the rect of the near clipping plane which should be used 
//				for an perspective projection. The coordinates are in model 
//				coordinates, located on the plane at
//					z = - [self fieldDepth] / 2.
//
// Notes:		We want perspective and ortho views to show objects at the 
//				 origin as the same size. Since perspective viewing is defined 
//				 by a frustum (truncated pyramid), we have to shrink the 
//				 visibily plane--which is located on the near clipping plane--in 
//				 such a way that the slice of the frustum at the origin will 
//				 have the dimensions of the desired visibility plane. (Remember, 
//				 slices grow *bigger* as they go deeper into the view. Since the 
//				 origin is deeper, that means we need a near visibility plane 
//				 that is *smaller* than the desired size at the origin.) 
//
//==============================================================================
- (Box2) nearFrustumClippingRectFromVisibleRect:(Box2)visibleRectIn
{
	Box2  orthoVisibilityPlane    = [self nearOrthoClippingRectFromVisibleRect:visibleRectIn];
	Box2  visibilityPlane         = orthoVisibilityPlane;
	float   fieldDepth              = [self fieldDepth];
	
	// Find the scaling percentage betwen the frustum slice through 
	// (0,0,0) and the slice that defines the near clipping plane. 
	float visibleProportion = (fabs(self->cameraDistance) - fieldDepth/2)
												/
									fabs(self->cameraDistance);
	
	//scale down the visibility plane, centering it in the full-size one.
	visibilityPlane.origin.x    = V2BoxMinX(orthoVisibilityPlane) + V2BoxWidth(orthoVisibilityPlane)  * (1 - visibleProportion) / 2;
	visibilityPlane.origin.y    = V2BoxMinY(orthoVisibilityPlane) + V2BoxHeight(orthoVisibilityPlane) * (1 - visibleProportion) / 2;
	visibilityPlane.size.width  = V2BoxWidth(orthoVisibilityPlane)  * visibleProportion;
	visibilityPlane.size.height = V2BoxHeight(orthoVisibilityPlane) * visibleProportion;
	
	return visibilityPlane;
	
}//end nearFrustumClippingRectFromVisibleRect:


//========== nearOrthoClippingRectFromNearFrustumClippingRect: =================
//
// Purpose:		Returns the near clipping rectangle which would be used if the 
//				given perspective view were converted to an orthographic 
//				projection. 
//
//==============================================================================
- (Box2) nearOrthoClippingRectFromNearFrustumClippingRect:(Box2)visibilityPlane
{
	Box2    orthoVisibilityPlane    = ZeroBox2;
	float   fieldDepth              = [self fieldDepth];
	
	// Find the scaling percentage betwen the frustum slice through 
	// (0,0,0) and the slice that defines the near clipping plane. 
	float visibleProportion = (fabs(self->cameraDistance) - fieldDepth/2)
												/
									fabs(self->cameraDistance);
	
	// Enlarge the ortho plane 
	orthoVisibilityPlane.size.width     = visibilityPlane.size.width  / visibleProportion;
	orthoVisibilityPlane.size.height    = visibilityPlane.size.height / visibleProportion;
	
	// Move origin according to enlargement
	orthoVisibilityPlane.origin.x       = V2BoxMinX(visibilityPlane) - V2BoxWidth(orthoVisibilityPlane)  * (1 - visibleProportion) / 2;
	orthoVisibilityPlane.origin.y       = V2BoxMinY(visibilityPlane) - V2BoxHeight(orthoVisibilityPlane) * (1 - visibleProportion) / 2;

	return orthoVisibilityPlane;
	
}//end nearOrthoClippingRectFromNearFrustumClippingRect:


//========== visibleRectFromNearOrthoClippingRect: =============================
//
// Purpose:		Returns the Cocoa view visible rectangle which would result in 
//				the given orthographic clipping rect. 
//
//==============================================================================
- (Box2) visibleRectFromNearOrthoClippingRect:(Box2)visibilityPlane
{
	Box2  newVisibleRect  = ZeroBox2;
	
	// Convert from model coordinates back to Cocoa view coordinates.
	
	newVisibleRect.origin.x    = visibilityPlane.origin.x + [scroller getDocumentSize].width/2;
	newVisibleRect.origin.y    = visibilityPlane.origin.y + [scroller getDocumentSize].height/2;
	newVisibleRect.size        = visibilityPlane.size;
	
	if(1)//[self isFlipped] == YES)
	{
		newVisibleRect.origin.y = [scroller getDocumentSize].height - V2BoxHeight(visibilityPlane) - V2BoxMinY(newVisibleRect);
	}
	
	return newVisibleRect;
	
}//end visibleRectFromNearOrthoClippingRect:


//========== visibleRectFromNearFrustumClippingRect: ===========================
//
// Purpose:		Returns the Cocoa view visible rectangle which would result in 
//				the given frustum clipping rect. 
//
//==============================================================================
- (Box2) visibleRectFromNearFrustumClippingRect:(Box2)visibilityPlane
{
	Box2  orthoClippingRect   = ZeroBox2;
	Box2  newVisibleRect      = ZeroBox2;
	
	orthoClippingRect   = [self nearOrthoClippingRectFromNearFrustumClippingRect:visibilityPlane];
	newVisibleRect      = [self visibleRectFromNearOrthoClippingRect:orthoClippingRect];
	
	return newVisibleRect;
	
}//end visibleRectFromNearFrustumClippingRect:


//========== makeProjection ====================================================
//
// Purpose:		Returns the Cocoa view visible rectangle which would result in 
//				the given frustum clipping rect. 
//
//==============================================================================
- (void) makeProjection
{
	float	fieldDepth		= [self fieldDepth];
	Box2	visibilityPlane	= ZeroBox2;
	
	//ULTRA-IMPORTANT NOTE: this method assumes that you have already made our 
	// openGLContext the current context
	
	// Start from scratch
	if(self->locationMode == LocationModeWalkthrough)
	{
		Size2	viewportSize = [scroller getMaxVisibleSizeDoc];
		float aspect_ratio = viewportSize.width / viewportSize.height;
		
		buildFrustumMatrix(projection,
					-WALKTHROUGH_NEAR / (self->zoomFactor / 100.0),
					+WALKTHROUGH_NEAR / (self->zoomFactor / 100.0),
					-WALKTHROUGH_NEAR / (self->zoomFactor / 100.0) / aspect_ratio,
					+WALKTHROUGH_NEAR / (self->zoomFactor / 100.0) / aspect_ratio,
					WALKTHROUGH_NEAR,
					WALKTHROUGH_FAR);
	}
	
	else if(self->projectionMode == ProjectionModePerspective)
	{
		visibilityPlane = [self nearFrustumClippingRectFromVisibleRect:[scroller getVisibleRect]];
		
		assert(visibilityPlane.size.width > 0.0);
		assert(visibilityPlane.size.height > 0.0);
		
		buildFrustumMatrix(projection,		
				  V2BoxMinX(visibilityPlane),	// left
				  V2BoxMaxX(visibilityPlane),	// right
				  V2BoxMinY(visibilityPlane),	// bottom
				  V2BoxMaxY(visibilityPlane),	// top
				  fabs(cameraDistance) - fieldDepth/2,	// near (closer points are clipped); distance from CAMERA LOCATION
				  fabs(cameraDistance) + fieldDepth/2	// far (points beyond this are clipped); distance from CAMERA LOCATION
				 );
	}
	else
	{
		visibilityPlane = [self nearOrthoClippingRectFromVisibleRect:[scroller getVisibleRect]];

		assert(visibilityPlane.size.width > 0.0);
		assert(visibilityPlane.size.height > 0.0);
		
		buildOrthoMatrix(projection,
				V2BoxMinX(visibilityPlane),	// left
				V2BoxMaxX(visibilityPlane),	// right
				V2BoxMinY(visibilityPlane),	// bottom
				V2BoxMaxY(visibilityPlane),	// top
				fabs(cameraDistance) - fieldDepth/2,	// near (points beyond these are clipped)
				fabs(cameraDistance) + fieldDepth/2 );	// far
	}
	
}//end makeProjection


//========== makeModelView =====================================================
//
// Purpose:		Rebuilds the model-view matrix from the camera distance, 
//				rotation and center - call this if any of these change.
//
//==============================================================================
- (void) makeModelView
{
	GLfloat cam_trans[16], center_trans[16], flip[16], temp1[16], temp2[16];
	
	buildRotationMatrix(flip,0,1,0,0);
	buildTranslationMatrix(cam_trans, 0, 0, self->cameraDistance);
	buildTranslationMatrix(center_trans,-rotationCenter.x, -rotationCenter.y, -rotationCenter.z);

	if(locationMode == LocationModeModel)
	{
		buildIdentity(temp1);	
		multMatrices(temp2,temp1,cam_trans);
		multMatrices(temp1,temp2,orientation);
		multMatrices(temp2,temp1,center_trans);
		multMatrices(modelView,temp2,flip);
	}
	else
	{
		buildIdentity(temp1);	
		multMatrices(temp2,temp1,orientation);
		multMatrices(temp1,temp2,center_trans);
		multMatrices(modelView,temp1,flip);		
	}
	
}//end makeModelView


//========== tickle ============================================================
//
// Purpose:		Cause the camera to recompute the document size, scrolling
//				position, and all matrices.
//
// Notes:		This routine must be called any time the external scroller
//				properties change, so that the camera can 'react' to the change.
//
//==============================================================================
- (void) tickle
{
	if(mute) 
		return;
	// At init we get tickled before we are wired - avoid seg fault or NaNs.
	if(scroller)
	{
		//
		// First, recalculate the document size based on the current model size, zoom, and current window size.
		// We will recalculate camera distance and rebuild the MV matrix.
		///

		Point3	origin			= {0,0,0};
		Point2	centerPoint		= V2Make( V2BoxMidX([scroller getVisibleRect]), V2BoxMidY([scroller getVisibleRect]) );
		Box3	newBounds		= modelSize;
		
		if(V3EqualBoxes(newBounds, InvalidBox) == YES ||	
			newBounds.min.x >= newBounds.max.x ||
			newBounds.min.y >= newBounds.max.y ||
			newBounds.min.z >= newBounds.max.z)			
		{
			newBounds = V3BoundsFromPoints(V3Make(-1, -1, -1), V3Make(1, 1, 1));
		}
		
		//
		// Find bounds size, based on model dimensions.
		//
		
		float	distance1		= V3DistanceBetween2Points(origin, newBounds.min );
		float	distance2		= V3DistanceBetween2Points(origin, newBounds.max );
		float	newSize			= MAX(distance1, distance2) + 40; //40 is just to provide a margin.
		
		// The canvas resizing is set to a fairly large granularity so 
		// it doesn't constantly change on people. 
		#if !NO_ROUNDING_DOC_SIZE
		newSize = ceil(newSize / 384) * 384;
		#endif

		self->cameraDistance = - (newSize) * CAMERA_DISTANCE_FACTOR;

		[self makeModelView];		// New camera distance means rebuild Mv.
		
		//
		// Second, resize the document based on the model size and the parent window size.
		// We will restore scrolling, which can get borked when the document size changes.
		//
		
		Size2	oldFrameSize	= [scroller getDocumentSize];
		Size2	newFrameSize	= ZeroSize2;
		
		self->snugFrameSize	= V2MakeSize( newSize*2, newSize*2 );
		
		if(self->viewportExpandsToAvailableSize == YES)
		{
			// Make the frame either just a little bit bigger than the 
			// size of the model, or the same as the scroll view, 
			// whichever is larger. 
			newFrameSize	= V2MakeSize( MAX(snugFrameSize.width,  [scroller getMaxVisibleSizeDoc].width  ),
										  MAX(snugFrameSize.height, [scroller getMaxVisibleSizeDoc].height ) );
		}
		else
		{
			newFrameSize	= snugFrameSize;
		}
		newFrameSize.width	= floor(newFrameSize.width);
		newFrameSize.height = floor(newFrameSize.height);
		
		// The canvas size changes will effectively be distributed equally 
		// on all sides, because the model is always drawn in the center of 
		// the canvas. So, our effective viewing center will only change by 
		// half the size difference. 
		centerPoint.x += (newFrameSize.width  - oldFrameSize.width)/2;
		centerPoint.y += (newFrameSize.height - oldFrameSize.height)/2;
		
		if(locationMode == LocationModeModel)
		{
			// I have only seen this on Lion and later: when we set the document size the scroll point is set to something totally 
			// silly.  Because of this, the visible rect is empty, and the entire camera calculation NaNs out.
			// To 'work around' this, we ignore the tickle that comes back from the reshape that is a result of the doc frame size
			// changing; we don't need it since we're going to re-scroll and redo the MV projection in the next few lines.
			++self->mute;
			[scroller setDocumentSize:newFrameSize];
			[self scrollCenterToPoint:centerPoint];		//Restore centering - changing the doc size causes AppKit to whack scrolling.
			--self->mute;			
		}
		else
		{
			++self->mute;			
			[scroller setDocumentSize:[scroller getMaxVisibleSizeDoc]];
			--self->mute;			
		}

		// Rebuild projection based on latest scroll data from AppKit.
		[self makeProjection];

	}
	
}//end tickle


#pragma mark -
#pragma mark CAMERA CONTROL API
#pragma mark -


//========== setModelSize: =====================================================
//
// Purpose:		Tell the camera the new size of the model it is viewing.
//
// Notes:		The tickle command will recompute the document size and then
//				request a scrolling update.
//
//==============================================================================
- (void) setModelSize:(Box3)inModelSize
{
	assert(inModelSize.min.x != inModelSize.max.x ||
		inModelSize.min.y != inModelSize.max.y ||
		inModelSize.min.z != inModelSize.max.z);
	self->modelSize = inModelSize;
	[self tickle];
}//end setModelSize:


//========== setRotationCenter: =============================================
//
// Purpose:		Change the rotation center to a new location, and center that
//				location.
//
//==============================================================================
- (void) setRotationCenter:(Point3)point
{
	if(V3EqualPoints(self->rotationCenter,point) == NO)
	{
		self->rotationCenter = point;
		[self makeModelView];																		// Recalc model view - needed before we can scroll to a given point!
		[self scrollModelPoint:self->rotationCenter toViewportProportionalPoint:V2Make(0.5,0.5)];	// scroll to new center (tickles itself, public API)
	}
}//end setRotationCenter:


//========== setZoomPercentage: ================================================
//
// Purpose:		Change the zoom of the camera.  This is called by the zoom
//				text field and zoom commands.  It resizes the document and
//				tickles the camera to make everything take effect.
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage
{
	assert(!isnan(newPercentage));
	assert(!isinf(newPercentage));
	assert(newPercentage > 0.0);
	
	CGFloat currentZoomPercentage   = self->zoomFactor;
	
	// Don't zoom if the zoom level isn't actually changing (to avoid 
	// unnecessary re-draw) 
	if(currentZoomPercentage == newPercentage)
		return;

	Point2	centerPoint	   = V2Make( V2BoxMidX([scroller getVisibleRect]), V2BoxMidY([scroller getVisibleRect]) );
	Point2	centerFraction = V2Make(centerPoint.x / [scroller getDocumentSize].width, centerPoint.y / [scroller getDocumentSize].height);
		
	self->zoomFactor = newPercentage;

	// Tell NS that sizes have changed - once we do this, we can request a re-scroll.
	
	self->mute++;
	
	if(locationMode == LocationModeWalkthrough)
		[scroller setScaleFactor:1.0];
	else
		[scroller setScaleFactor:self->zoomFactor/100.0];

	centerPoint.x = centerFraction.x * [scroller getDocumentSize].width;
	centerPoint.y = centerFraction.y * [scroller getDocumentSize].height;

	if(locationMode != LocationModeWalkthrough)
		[self scrollCenterToPoint:centerPoint]; // Request that NS change scrolling to restore centering.
		
	self->mute--;	
	[self tickle];								// Rebuild ourselves based on the new zoom, scroll, etc.
}//end setZoomPercentage:


//========== setZoomPercentage:preservePoint: ==================================
//
// Purpose:		Set the zoom percentage, keeping a particular model point fixed
//				on screen.
//
// Notes:		To do this, we figure out where on screen the model point is, 
//				then we zoom, and then we re-scroll that 3-d point to its new
//				location.
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage preservePoint:(Point3)modelPoint
{
	Box2 viewport = V2MakeBox(0,0,1,1);		// Fake view-port - this gets us our scaled point in viewport-proportional units.
	
	// - Near clipping plane unprojection
	Point3 nearModelPoint = V3Project(modelPoint,
								 Matrix4CreateFromGLMatrix4(modelView),
								 Matrix4CreateFromGLMatrix4(projection),
								 viewport);

	Point2 viewportProportion  = V2Make(nearModelPoint.x,nearModelPoint.y);
	
	[self setZoomPercentage:newPercentage];
	[self scrollModelPoint:modelPoint toViewportProportionalPoint:viewportProportion]; //(tickles itself, public API)
}//end setZoomPercentage:preservePoint:


//========== scrollModelPoint:toViewportProportionalPoint: =====================
//
// Purpose:		Scroll a given 3-d point on our model to a particular location
//				on screen.  The view location is a ratio of the visible portion
//				of the screen, e.g. 0.5, 0.5 is the center of the screen.
//
//==============================================================================
- (void) scrollModelPoint:(Point3)modelPoint toViewportProportionalPoint:(Point2)viewportPoint
{
	if(locationMode == LocationModeWalkthrough)
		return;

	Point2  newCenter           = ZeroPoint2;
	float   zEval               = 0;
	float	zNear				= 0;
	Matrix4 modelViewMatrix     = Matrix4CreateFromGLMatrix4(modelView);
	Point4  transformedPoint    = ZeroPoint4;
	Box2    newVisibleRect      = ZeroBox2;
	Box2    currentClippingRect = ZeroBox2;
	Box2    newClippingRect     = ZeroBox2;
	
	// For the camera calculation, we need effective world coordinates, not 
	// model coordinates. 
	transformedPoint = V4MulPointByMatrix(V4FromPoint3(modelPoint), modelViewMatrix);
	
	// Perspective distortion makes this more complicated. The camera is in a 
	// fixed position, but the frustum changes with the scrollbars. We need to 
	// calculate the world point we just clicked on, then derive a new frustum 
	// projection centered on that point. 
	if(self->projectionMode == ProjectionModePerspective)
	{
		currentClippingRect = [self nearFrustumClippingRectFromVisibleRect:[scroller getVisibleRect]];
		
		// Consider how perspective projection works: you can think of the frustum as having two 
		// effects on X and Y coordinates:
		//
		// (1) it makes them get closer together as they get farther from the camera.  Think of train
		//	   tracks converging on the horizon.
		//
		// (2) it rescales the entire mess of coordinates from an arbitrary range of camera X and Y 
		//	   to -1..1 (after perspective divide) which then go to the viewport.
		//
		// You can think of part 2 as happening via the left/right/top/bottom inputs to the frustum.
		// The near plane is used to implement idea 1 - drawing _at_ the near clip plane goes on to
		// step 2 unmodified.  Anything farther than the near clip plane becomes smaller.
		//
		// (The far clip plane never actually shows up in the final computation of clip-space x or y.)
		// 
		// So...transformedPoint is a point in eye space and we want to know where in our NS document 
		// it is - but our viewport is in model coordinates.  IF the point were on the near clip plane,
		// this would be no problem; the eye coordinates are what we want. 
		// 
		// So what we do is calculate that 'foreshortening ratio' - that is, the fraction that makes
		// the tracks closer to the origin at farther distances.  We apply that to our point, finding
		// where it 'looks' to the user (farther away is closer to the camera origin) and we pass that
		// without ever using step (2) to go from model units to -1..1.
		
		
		// We need the near clip plane - note that it will have a negative value - since +Z looks at
		// us EVERYTHING you ever see in GL (in eye coordinates) has negative Z.
		zNear = (cameraDistance + [self fieldDepth]/2);
		
		// The ratio of 'far away' is given by near/z.  Both zNear and our point's Z are negative, so
		// the ratio is positive, as expected.  At the near clip plane the ratio is 1.  Note that IF
		// we could draw in front of the near clip plane without, y'know, clipping, then zEval would
		// become larger than 1 and rapidly head off to infinity as our transformed point approached
		// zero.  In other words, things heading at us through the near clip plane would get 
		// infinitely big just as they crash into our eyeballs.
		zEval = zNear / transformedPoint.z;

		// New center is eye coordinates of our point scaled in to account for perspective.
		newCenter.x     = zEval * transformedPoint.x;
		newCenter.y     = zEval * transformedPoint.y;

		// Calculate a NEW frustum clipping rect centered on the clicked point's 
		// projection onto the near clipping plane. 
		newClippingRect.size        = currentClippingRect.size;
		newClippingRect.origin.x    = newCenter.x - V2BoxWidth(currentClippingRect) * viewportPoint.x;
		newClippingRect.origin.y    = newCenter.y - V2BoxHeight(currentClippingRect) * viewportPoint.y;
		
		// Reverse-derive the correct Cocoa view visible rect which will result 
		// in the desired clipping rect to be used. 
		newVisibleRect = [self visibleRectFromNearFrustumClippingRect:newClippingRect];
	}
	else
	{
		currentClippingRect = [self nearOrthoClippingRectFromVisibleRect:[scroller getVisibleRect]];
		
		// Ortho centers are trivial.
		newCenter.x = transformedPoint.x;
		newCenter.y = transformedPoint.y;
		
		// Calculate a clipping rect centered on the clicked point's projection. 
		newClippingRect.size        = currentClippingRect.size;
		newClippingRect.origin.x    = newCenter.x - V2BoxWidth(currentClippingRect) * viewportPoint.x;
		newClippingRect.origin.y    = newCenter.y - V2BoxHeight(currentClippingRect) * viewportPoint.y;
		
		// Reverse-derive the correct Cocoa view visible rect which will result 
		// in the desired clipping rect to be used. 
		newVisibleRect = [self visibleRectFromNearOrthoClippingRect:newClippingRect];
	}

	// Scroll to it. -makeProjection will now derive the exact frustum or ortho 
	// projection which will make the clicked point appear in the center. 
	[scroller setScrollOrigin:newVisibleRect.origin];
	[self tickle];		// Tickle to rebuild all matrices based on external change.

}//end scrollModelPoint:toViewportProportionalPoint:


//========== setViewingAngle: ==================================================
//
// Purpose:		Change the viewing angle to a specific angle.
//
//==============================================================================
- (void) setViewingAngle:(Tuple3)newAngle
{
	GLfloat gl_angle[16],gl_flip[16];
	Matrix4 angle = Matrix4RotateModelview(IdentityMatrix4, newAngle);

	Matrix4GetGLMatrix4(angle,gl_angle);	
	buildRotationMatrix(gl_flip, 180, 1, 0, 0);
	multMatrices(orientation, gl_flip, gl_angle);
	
	[self makeModelView];

}//end setViewingAngle:


//========== setProjectionMode: ================================================
//
// Purpose:		Change projection modes.
//
// Notes:		This is a special-case - normally we'd tickle, but we only need
//				to make the projection matrix over because right now all 
//				projection modes keep the same document size.
//
//==============================================================================
- (void) setProjectionMode:(ProjectionModeT)newProjectionMode
{
	self->projectionMode = newProjectionMode;
	[self makeProjection];		// This doesn't need a full tickle because proj mode doesn't change the doc size.
	
}//end setProjectionMode:


//========== setLocationMode: ================================================
//
// Purpose:		Change Location modes.
//
//==============================================================================
- (void) setLocationMode:(LocationModeT)newLocationMode
{
	if(self->locationMode != newLocationMode)
	{
		self->locationMode = newLocationMode;
		
		// Tell NS that sizes have changed - once we do this, we can request a re-scroll.
		if(locationMode == LocationModeWalkthrough)
			[scroller setScaleFactor:1.0];
		else
			[scroller setScaleFactor:self->zoomFactor/100.0];
		
		[self tickle];
	}
	
}//end setProjectionMode:


//========== rotationDragged ===================================================
//
// Purpose:		Rotate the camera based on a 2-d drag vector.
//
//==============================================================================
- (void) rotationDragged:(Vector2)viewDirection
{
	CGFloat	deltaX			=   viewDirection.x;
	CGFloat	deltaY			= - viewDirection.y; //Apple's delta is backwards, for some reason.
	
	// Get the percentage of the window we have swept over. Since half the 
	// window represents 180 degrees of rotation, we will eventually 
	// multiply this percentage by 180 to figure out how much to rotate. 
	CGFloat	percentDragX	= deltaX / [scroller getDocumentSize].width;
	CGFloat	percentDragY	= deltaY / [scroller getDocumentSize].height;
	
	// Remember, dragging on y means rotating about x.
	CGFloat	rotationAboutY	= + ( percentDragX * 180 );
	CGFloat	rotationAboutX	= - ( percentDragY * 180 ); //multiply by -1,
				// as we need to convert our drag into a proper rotation 
				// direction. See notes in function header.

	if(USE_TURNTABLE)
	{
		Tuple3 view_now = [self viewingAngle];
		if(view_now.x * view_now.y * view_now.z < 0.0)
			rotationAboutY = -rotationAboutY;
	}	
	
	//Get the current transformation matrix. By using its inverse, we can 
	// convert projection-coordinates back to the model coordinates they 
	// are displaying.
	Matrix4 inversed = Matrix4Invert(Matrix4CreateFromGLMatrix4([self getModelView]));
	
	// clear any translation resulting from a rotation center
	inversed.element[3][0] = 0;
	inversed.element[3][1] = 0;
	inversed.element[3][2] = 0;
	
	// Now we will convert what appears to be the vertical and horizontal 
	// axes into the actual model vectors they represent. 
	Vector4 vectorX             = {1,0,0,1}; //unit vector i along x-axis.
	Vector4 vectorY             = {0,1,0,1}; //unit vector j along y-axis.
	Vector4 transformedVectorX;
	Vector4 transformedVectorY;
	
	// We do this conversion from screen to model coordinates by multiplying 
	// our screen points by the modelview matrix inverse. That has the 
	// effect of "undoing" the model matrix on the screen point, leaving us 
	// a model point. 
	transformedVectorX = V4MulPointByMatrix(vectorX, inversed);
	transformedVectorY = V4MulPointByMatrix(vectorY, inversed);

	if(USE_TURNTABLE)
	{
		rotationAboutY = -rotationAboutY;
		transformedVectorY = vectorY;
	}
	
	//Now rotate the model around the visual "up" and "down" directions.

	applyRotationMatrix(orientation, rotationAboutX, transformedVectorX.x, transformedVectorX.y, transformedVectorX.z);
	applyRotationMatrix(orientation, rotationAboutY, transformedVectorY.x, transformedVectorY.y, transformedVectorY.z);
	[self makeModelView];

	
}//end rotationDragged


//========== rotateByDegrees: ==================================================
//
// Purpose:		Rotate the camera by a fixed angle - used by the trackpad twist
//				gesture, this rotates aronud the screen Y axis.
//
//==============================================================================
- (void) rotateByDegrees:(float)angle
{
	applyRotationMatrix(orientation, angle, 0, -1, 0);
	[self makeModelView];

}//end rotateByDegrees:



@end
