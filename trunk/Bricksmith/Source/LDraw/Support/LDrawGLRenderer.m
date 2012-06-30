//==============================================================================
//
// File:		LDrawGLRenderer.m
//
// Purpose:		Draws an LDrawFile with OpenGL.
//
//				This class is responsible for all platform-independent logic, 
//				including math and OpenGL operations. It also contains a number 
//				of methods which would be called in response to events; it is 
//				the responsibility of the platform layer to receive and 
//				interpret those events and pass them to us. 
//
//				The "event" type methods here take high-level parameters. For 
//				example, we don't check -- or want to know! -- if the option key 
//				is down. The platform layer figures out stuff like that, and 
//				more importantly, figures out what it *means*. The *meaning* is 
//				what the renderer's methods care about. 
//
//  Created by Allen Smith on 4/17/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawGLRenderer.h"

#import "LDrawColor.h"
#import "LDrawDirective.h"
#import "LDrawDragHandle.h"
#import "LDrawFile.h"
#import "LDrawModel.h"
#import "LDrawPart.h"
#import "LDrawStep.h"
#import "LDrawUtilities.h"

#define DEBUG_DRAWING				0
#define SIMPLIFICATION_THRESHOLD	0.3 //seconds
#define CAMERA_DISTANCE_FACTOR		6.5	//controls perspective; cameraLocation = modelSize * CAMERA_DISTANCE_FACTOR

@implementation LDrawGLRenderer

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize the object.
//
//==============================================================================
- (id) initWithBounds:(Size2)boundsIn
{
	self = [super init];
	
	//---------- Initialize instance variables ---------------------------------
	
	[self setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]];
	
	bounds							= boundsIn;
	visibleRect 					= V2MakeBox(0, 0, boundsIn.width, boundsIn.height);
	maximumVisibleSize				= boundsIn;
	viewportExpandsToAvailableSize	= YES;
	
	zoomFactor						= 100; // percent
	cameraDistance					= -10000;
	isTrackingDrag					= NO;
	selectionMarquee				= ZeroBox2;
	projectionMode					= ProjectionModePerspective;
	rotationDrawMode				= LDrawGLDrawNormal;
	gridSpacing 					= 20.0;
		
	[self setViewOrientation:ViewOrientation3D];
	
	return self;
	
}//end initWithFrame:


//========== prepareOpenGL =====================================================
//
// Purpose:		The context is all set up; this is where we prepare our OpenGL 
//				state.
//
//==============================================================================
- (void) prepareOpenGL
{
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_MULTISAMPLE); //antialiasing
	
	// This represents the "default" GL state, at least until we change that policy.
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	
	[self setBackgroundColorRed:1.0 green:1.0 blue:1.0]; // white

	//
	// Define the lighting.
	//
	
	//Our light position is transformed by the modelview matrix. That means 
	// we need to have a standard model matrix loaded to get our light to 
	// land in the right place! But our modelview might have already been 
	// affected by someone calling -setViewOrientation:. So we restore the 
	// default here.
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glRotatef(180,1,0,0); //convert to standard, upside-down LDraw orientation.
	
	//---------- Material ------------------------------------------------------
	
//	GLfloat ambient[4]  = { 0.2, 0.2, 0.2, 1.0 };
//	GLfloat diffuse[4]	= { 0.5, 0.5, 0.5, 1.0 };
	GLfloat specular[4] = { 0.0, 0.0, 0.0, 1.0 };
	GLfloat shininess   = 64.0; // range [0-128]
	
//	glMaterialfv( GL_FRONT_AND_BACK, GL_AMBIENT,	ambient );
//	glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE,	diffuse ); //don't bother; overridden by glColorMaterial
	glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR,	specular );
	glMaterialf(  GL_FRONT_AND_BACK, GL_SHININESS,	shininess );

//	glColorMaterial(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE); // this is the default anyway

	glShadeModel(GL_SMOOTH);
	glEnable(GL_NORMALIZE);
	glEnable(GL_COLOR_MATERIAL);
	

	//---------- Light Model ---------------------------------------------------
	
	// The overall scene has ambient light to make the lighting less harsh. But 
	// too much ambient light makes everything washed out. 
	GLfloat lightModelAmbient[4]    = {0.3, 0.3, 0.3, 0.0};
	
	glLightModelf( GL_LIGHT_MODEL_TWO_SIDE,		GL_FALSE );
	glLightModelfv(GL_LIGHT_MODEL_AMBIENT,		lightModelAmbient);
	
	
	//---------- Lights --------------------------------------------------------
	
	// We are going to have two lights, one in a standard position (LIGHT0) and 
	// another pointing opposite to it (LIGHT1). The second light will 
	// illuminate any inverted normals or backwards polygons. 
	GLfloat position0[] = {0, -0.0, -1.0, 0};
	GLfloat position1[] = {0,  0.0,  1.0, 0};
	
	// Lessening the diffuseness also makes lighting less extreme.
	GLfloat light0Ambient[4]     = { 0.0, 0.0, 0.0, 1.0 };
	GLfloat light0Diffuse[4]     = { 0.8, 0.8, 0.8, 1.0 };
	GLfloat light0Specular[4]    = { 0.0, 0.0, 0.0, 1.0 };
	
	//normal forward light
	glLightfv(GL_LIGHT0, GL_POSITION, position0);
	glLightfv(GL_LIGHT0, GL_AMBIENT,  light0Ambient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE,  light0Diffuse);
	glLightfv(GL_LIGHT0, GL_SPECULAR, light0Specular);
	
	glLightf(GL_LIGHT0, GL_CONSTANT_ATTENUATION,	1.0);
	glLightf(GL_LIGHT0, GL_LINEAR_ATTENUATION,		0.0);
	glLightf(GL_LIGHT0, GL_QUADRATIC_ATTENUATION,	0.0);

	//opposing light to illuminate backward normals.
	glLightfv(GL_LIGHT1, GL_POSITION, position1);
	glLightfv(GL_LIGHT1, GL_AMBIENT,  light0Ambient);
	glLightfv(GL_LIGHT1, GL_DIFFUSE,  light0Diffuse);
	glLightfv(GL_LIGHT1, GL_SPECULAR, light0Specular);
	
	glLightf(GL_LIGHT1, GL_CONSTANT_ATTENUATION,	1.0);
	glLightf(GL_LIGHT1, GL_LINEAR_ATTENUATION,		0.0);
	glLightf(GL_LIGHT1, GL_QUADRATIC_ATTENUATION,	0.0);

	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glEnable(GL_LIGHT1);
	
	
	//Now that the light is positioned where we want it, we can restore the 
	// correct viewing angle.
	[self setViewOrientation:self->viewOrientation];
	
}//end prepareOpenGL



#pragma mark -
#pragma mark DRAWING
#pragma mark -

//========== draw ==============================================================
//
// Purpose:		Draw the LDraw content of the view.
//
// Notes:		This method is, in theory at least, as thread-safe as Apple's 
//				OpenGL implementation is. Which is to say, not very much.
//
//==============================================================================
- (void) draw
{
	NSDate				*startTime			= nil;
	NSUInteger			 options			= DRAW_NO_OPTIONS;
	NSTimeInterval		 drawTime			= 0;
	BOOL				 considerFastDraw	= NO;
	
	startTime	= [NSDate date];

	// We may need to simplify large models if we are spinning the model 
	// or doing part drag-and-drop. 
	considerFastDraw =		self->isTrackingDrag == YES
						||	self->isGesturing == YES
						||	(	[self->fileBeingDrawn respondsToSelector:@selector(draggingDirectives)]
							 &&	[(id)self->fileBeingDrawn draggingDirectives] != nil
							);
#if DEBUG_DRAWING == 0
	if(considerFastDraw == YES && self->rotationDrawMode == LDrawGLDrawExtremelyFast)
	{
		options |= DRAW_BOUNDS_ONLY;
	}
#endif //DEBUG_DRAWING

	//Load the model matrix to make sure we are applying the right stuff.
	glMatrixMode(GL_MODELVIEW);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	// Make lines look a little nicer; Max width 1.0; 0.5 at 100% zoom
	glLineWidth(MIN([self zoomPercentage]/100 * 0.5, 1.0));

	// DRAW!
	[self->fileBeingDrawn draw:options
					 viewScale:[self zoomPercentage]/100.
				   parentColor:color];

	// We allow primitive drawing to leave their VAO bound to avoid setting the VAO
	// back to zero between every draw call.  Set it once here to avoid usign some
	// poor directive to draw!
	glBindVertexArrayAPPLE(0);

	// Marquee selection box -- only if non-zero.
	if( V2BoxWidth(self->selectionMarquee) != 0 && V2BoxHeight(self->selectionMarquee) != 0)
	{
		Point2	from	= self->selectionMarquee.origin;
		Point2	to		= V2Make( V2BoxMaxX(selectionMarquee), V2BoxMaxY(selectionMarquee) );
		Point2	p1		= [self convertPointToViewport:from];
		Point2	p2		= [self convertPointToViewport:to];

		Box2	vp = [self viewport];
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		glOrtho(V2BoxMinX(vp),V2BoxMaxX(vp),V2BoxMinY(vp),V2BoxMaxY(vp),-1,1);
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		
		glColor4f(0,0,0,1);

		GLfloat	vertices[8] = {
							p1.x,p1.y,
							p2.x,p1.y,
							p2.x,p2.y,
							p1.x,p2.y };
							
							
		glVertexPointer(2, GL_FLOAT, 0, vertices);
		glDisableClientState(GL_NORMAL_ARRAY);
		glDisableClientState(GL_COLOR_ARRAY);

		glDrawArrays(GL_LINE_LOOP,0,4);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);

		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
	}
	
	[self->delegate LDrawGLRendererNeedsFlush:self];
	
	// If we just did a full draw, let's see if rotating needs to be 
	// done simply. 
	drawTime = -[startTime timeIntervalSinceNow];
	if(considerFastDraw == NO)
	{
		if( drawTime > SIMPLIFICATION_THRESHOLD )
			rotationDrawMode = LDrawGLDrawExtremelyFast;
		else
			rotationDrawMode = LDrawGLDrawNormal;
	}

	// Timing info
	framesSinceStartTime++;
#if DEBUG_DRAWING
	NSTimeInterval timeSinceMark = [NSDate timeIntervalSinceReferenceDate] - fpsStartTime;
	if(timeSinceMark > 5)
	{	// reset periodically
		fpsStartTime = [NSDate timeIntervalSinceReferenceDate]; 
		framesSinceStartTime = 0;
		NSLog(@"fps = ????????, period = ????????, draw time: %f", drawTime);
	}
	else
	{
		CGFloat framesPerSecond = framesSinceStartTime / timeSinceMark;
		CGFloat period = timeSinceMark / framesSinceStartTime;
		NSLog(@"fps = %f, period = %f, draw time: %f", framesPerSecond, period, drawTime);
	}
#endif //DEBUG_DRAWING
	
}//end draw:to


//========== isFlipped =========================================================
//
// Purpose:		This lets us appear in the upper-left of scroll views rather 
//				than the bottom. The view should draw just fine whether or not 
//				it is flipped, though.
//
//==============================================================================
- (BOOL) isFlipped
{
	return YES;
	
}//end isFlipped


//========== isOpaque ==========================================================
//
// Note:		Our content completely covers this view. (This is just here as a 
//				reminder; NSOpenGLViews are opaque by default.) 
//
//==============================================================================
- (BOOL) isOpaque
{
	return YES;
}


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== activeDragHandle ==================================================
//
// Purpose:		Returns a drag handle if we are currently locked into a 
//				drag-handle drag. Otherwise returns nil. 
//
//==============================================================================
- (LDrawDragHandle*) activeDragHandle
{
	return self->activeDragHandle;
}


//========== centerPoint =======================================================
//
// Purpose:		Returns the point (in frame coordinates) which is currently 
//				at the center of the visible rectangle. This is useful for 
//				determining the point being viewed in the scroll view.
//
//==============================================================================
- (Point2) centerPoint
{
	return V2Make( V2BoxMidX(self->visibleRect), V2BoxMidY(self->visibleRect) );
	
}//end centerPoint


//========== didPartSelection ==================================================
//
// Purpose:		Returns whether the most-recent mouseDown resulted in a 
//				part-selection attempt. This is only valid when called during a 
//				mouse click. 
//
//==============================================================================
- (BOOL) didPartSelection
{
	return self->didPartSelection;
}


//========== getInverseMatrix ==================================================
//
// Purpose:		Returns the inverse of the current modelview matrix. You can 
//				multiply points by this matrix to convert screen locations (or 
//				vectors) to model points.
//
// Note:		This function filters out the translation which is caused by 
//				"moving" the camera with gluLookAt. That allows us to continue 
//				working with the model as if it's positioned at the origin, 
//				which means that points we generate with this matrix will 
//				correspond to points in the LDraw model itself.
//
//==============================================================================
- (Matrix4) getInverseMatrix
{
	Matrix4	transformation	= [self getMatrix];
	Matrix4	inversed		= Matrix4Invert(transformation);
	
	return inversed;
	
}//end getInverseMatrix


//========== getMatrix =========================================================
//
// Purpose:		Returns the the current modelview matrix, basically.
//
// Note:		This function filters out the translation which is caused by 
//				"moving" the camera with gluLookAt. That allows us to continue 
//				working with the model as if it's positioned at the origin, 
//				which means that points we generate with this matrix will 
//				correspond to points in the LDraw model itself. 
//
//==============================================================================
- (Matrix4) getMatrix
{
	GLfloat	currentMatrix[16];
	Matrix4	transformation	= IdentityMatrix4;
	
	glGetFloatv(GL_MODELVIEW_MATRIX, currentMatrix);
	transformation = Matrix4CreateFromGLMatrix4(currentMatrix); //convert to our utility library format
	
	// When using a perspective view, we must use gluLookAt to reposition 
	// the camera. That basically means translating the model. But all we're 
	// concerned about here is the *rotation*, so we'll zero out the 
	// translation components. 
	transformation.element[3][0] = 0;
	transformation.element[3][1] = 0; //translation is in the bottom row of the matrix.
	transformation.element[3][2] = 0;
	
	return transformation;
	
}//end getMatrix


//========== isTrackingDrag ====================================================
//
// Purpose:		Returns YES if a mouse-drag is currently in progress.
//
//==============================================================================
- (BOOL) isTrackingDrag
{
	return self->isTrackingDrag;
}


//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code of the receiver.
//
//==============================================================================
-(LDrawColor *) LDrawColor
{
	return self->color;
	
}//end color


//========== LDrawDirective ====================================================
//
// Purpose:		Returns the file or model being drawn by this view.
//
//==============================================================================
- (LDrawDirective *) LDrawDirective
{
	return self->fileBeingDrawn;
	
}//end LDrawDirective


//========== nudgeVector =======================================================
//
// Purpose:		Returns the direction of a keyboard part nudge. The target of 
//				our nudgeAction queries this method to find how to nudge the 
//				selection. 
//
// Notes:		This value is only valid during the nudgeAction callback.
//
//==============================================================================
- (Vector3) nudgeVector
{
	return self->nudgeVector;
	
}//end nudgeVector


//========== projectionMode ====================================================
//
// Purpose:		Returns the current projection mode (perspective or 
//				orthographic) used in the view.
//
//==============================================================================
- (ProjectionModeT) projectionMode
{
	return self->projectionMode;
	
}//end projectionMode


//========== selectionMarquee ==================================================
//==============================================================================
- (Box2) selectionMarquee
{
	return self->selectionMarquee;
}


//========== viewingAngle ======================================================
//
// Purpose:		Returns the modelview rotation, in degrees.
//
// Notes:		These numbers do *not* include the fact that LDraw has an 
//				upside-down coordinate system. So if this method returns 
//				(0,0,0), that means "Front, looking right-side up." 
//				
//==============================================================================
- (Tuple3) viewingAngle
{
	Matrix4              transformation		= IdentityMatrix4;
	TransformComponents  components			= IdentityComponents;
	Tuple3				 degrees			= ZeroPoint3;
	
	transformation = [self getMatrix];
	transformation = Matrix4Rotate(transformation, V3Make(180, 0, 0)); // LDraw is upside-down
	Matrix4DecomposeTransformation(transformation, &components);
	degrees = components.rotate;
	
	degrees.x = degrees(degrees.x);
	degrees.y = degrees(degrees.y);
	degrees.z = degrees(degrees.z);
	
	return degrees;
	
}//end viewingAngle


//========== viewOrientation ===================================================
//
// Purpose:		Returns the current camera orientation for this view.
//
//==============================================================================
- (ViewOrientationT) viewOrientation
{
	return self->viewOrientation;
	
}//end viewOrientation


//========== viewport ==========================================================
//
// Purpose:		Returns the viewport. Origin is the lower-left.
//
//==============================================================================
- (Box2) viewport
{
	GLint	glViewport[4]	= {};
	Box2	viewport		= ZeroBox2;
	
	glGetIntegerv(GL_VIEWPORT, glViewport);
	viewport = V2MakeBox(glViewport[0], glViewport[1], glViewport[2], glViewport[3]);
	
	return viewport;
}


//========== visibleRect =======================================================
//
// Purpose:		Returns the rect in the view coordinate system which is 
//				considered "visible." This is the rect the viewport is projected 
//				in. 
//
//==============================================================================
- (Box2) visibleRect
{
	return self->visibleRect;
}

//========== zoomPercentage ====================================================
//
// Purpose:		Returns the percentage magnification being applied to the 
//				receiver. (200 means 2x magnification.) The scaling factor is
//				determined by the receiver's scroll view, not the GLView itself.
//				If the receiver is not contained within a scroll view, this 
//				method returns 100.
//
//==============================================================================
- (CGFloat) zoomPercentage
{
	return self->zoomFactor;
	
}//end zoomPercentage


#pragma mark -

//========== setAllowsEditing: =================================================
//
// Purpose:		Sets whether the renderer supports part selection and dragging.
//
// Notes:		Querying a delegate isn't sufficient.
//
//==============================================================================
- (void) setAllowsEditing:(BOOL)flag
{
	self->allowsEditing = flag;
}


//========== setDelegate: ======================================================
//
// Purpose:		Sets the object that acts as the delegate for the receiver. 
//
//				This object relies on the the delegate to interface with the 
//				window manager to do things like scrolling. 
//
//==============================================================================
- (void) setDelegate:(id)object
{
	// weak link.
	self->delegate = object;

}//end setDelegate:


//========== setBackAction: ====================================================
//
// Purpose:		Sets the method called on the target when a backward swipe is 
//				received. 
//
//==============================================================================
- (void) setBackAction:(SEL)newAction
{
	self->backAction = newAction;
	
}//end setBackAction:


//========== setBackgroundColorRed:green:blue: =================================
//
// Purpose:		Sets the canvas background color.
//
//==============================================================================
- (void) setBackgroundColorRed:(float)red green:(float)green blue:(float)blue
{
	glBackgroundColor[0] = red;
	glBackgroundColor[1] = green;
	glBackgroundColor[2] = blue;
	glBackgroundColor[3] = 1.0;

	glClearColor(glBackgroundColor[0],
				 glBackgroundColor[1],
				 glBackgroundColor[2],
				 glBackgroundColor[3] );
				 
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
}


//========== setBounds: ========================================================
//
// Purpose:		Sets the maximum logical dimensions of the renderer.
//
// Notes:		The renderer tends to set this up itself based on the size of 
//				the model being displayed. See -resetFrameSize. 
//
//==============================================================================
- (void) setBounds:(Size2)boundsIn
{
	if(V2EqualSizes(self->bounds, boundsIn) == false)
	{
		self->bounds = boundsIn;
		
		[self resetVisibleRect];
		[self->delegate LDrawGLRendererNeedsRedisplay:self];
	}
}


//========== setDragEndedInOurDocument: ========================================
//
// Purpose:		When a dragging operation we initiated ends outside the 
//				originating document, we need to know about it so that we can 
//				tell the document to completely delete the directives it started 
//				dragging. (They are merely hidden during the drag.) However, 
//				each document can be represented by multiple views, so it is 
//				insufficient to simply test whether the drag ended within this 
//				view. 
//
//				So, when a drag ends in any LDrawGLView, it inspects the 
//				dragging source to see if it represents the same document. If it 
//				does, it sends the source this message. If this message hasn't 
//				been received by the time the drag ends, this view will 
//				automatically instruct its document to purge the source 
//				directives, since the directives were actually dragged out of 
//				their document. 
//
//==============================================================================
- (void) setDragEndedInOurDocument:(BOOL)flag
{
	self->dragEndedInOurDocument = flag;
	
}//end setDragEndedInOurDocument:


//========== setDraggingOffset: ================================================
//
// Purpose:		Sets the offset to apply to the first drag-and-drop part's 
//				position. This is used when initiating drag-and-drop while 
//				clicking on a point other than the exact center of the part. We 
//				want to maintain the clicked point under the cursor, but it is 
//				internally easier to move the part's centerpoint. This offset 
//				allows us to translate between the two. 
//
//==============================================================================
- (void) setDraggingOffset:(Vector3)offsetIn
{
	self->draggingOffset = offsetIn;
}


//========== setForwardAction: =================================================
//
// Purpose:		Sets the method called on the target when a forward swipe is 
//				received. 
//
//==============================================================================
- (void) setForwardAction:(SEL)newAction
{
	self->forwardAction = newAction;
	
}//end setForwardAction:


//========== setGridSpacing: ===================================================
//
// Purpose:		Sets the grid amount by which things are dragged.
//
//==============================================================================
- (void) setGridSpacing:(float)newValue
{
	self->gridSpacing = newValue;
}


//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the base color for parts drawn by this view which have no 
//				color themselves.
//
//==============================================================================
-(void) setLDrawColor:(LDrawColor *)newColor
{
	[newColor retain];
	[self->color release];
	self->color = newColor;
	
	[self->delegate LDrawGLRendererNeedsRedisplay:self];

}//end setColor


//========== LDrawDirective: ===================================================
//
// Purpose:		Sets the file being drawn in this view.
//
//				We also do other housekeeping here associated with tracking the 
//				model. We also automatically center the model in the view.
//
//==============================================================================
- (void) setLDrawDirective:(LDrawDirective *)newFile
{
	BOOL    virginView  = (self->fileBeingDrawn == nil);
	Size2   frame       = ZeroSize2;
	
	//Update our variable.
	[newFile retain];
	[self->fileBeingDrawn release];
	self->fileBeingDrawn = newFile;
	
	[self resetFrameSize];
	frame = self->bounds; //now that it's been changed above.
	if(virginView == YES)
	{
		[self scrollCenterToPoint:V2Make(frame.width/2, frame.height/2 )];
	}

	//Register for important notifications.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:LDrawDirectiveDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:LDrawFileActiveModelDidChangeNotification object:nil];
		
	[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(displayNeedsUpdating:)
				   name:LDrawDirectiveDidChangeNotification
				 object:self->fileBeingDrawn ];
	
	[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(displayNeedsUpdating:)
				   name:LDrawFileActiveModelDidChangeNotification
				 object:self->fileBeingDrawn ];
	
}//end setLDrawDirective:


//========== setMaximumVisibleSize: ============================================
//
// Purpose:		Sets the largest size (in frame coordinates) to which the 
//				visible rect should be permitted to grow. 
//
//==============================================================================
- (void) setMaximumVisibleSize:(Size2)size
{
	self->maximumVisibleSize = size;

	[self resetVisibleRect];
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
}


//========== setNudgeAction: ===================================================
//
// Purpose:		Sets the action sent when the GLView wants to nudge a part.
//
//				You get the nudge vector by calling -nudgeVector within the body 
//				of the action method. 
//
//==============================================================================
- (void) setNudgeAction:(SEL)newAction
{
	self->nudgeAction = newAction;
	
}//end setNudgeAction:


//========== setProjectionMode: ================================================
//
// Purpose:		Sets the projection used when drawing the receiver:
//					- orthographic is like a Mercator map; it distorts deeper 
//									objects.
//					- perspective draws deeper objects toward a vanishing point; 
//									this is how humans see the world.
//
//==============================================================================
- (void) setProjectionMode:(ProjectionModeT)newProjectionMode
{
	self->projectionMode = newProjectionMode;
	
	[self makeProjection];
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
	
} //end setProjectionMode:


//========== setSelectionMarquee: ==============================================
//
// Purpose:		The box (in view coordinates) in which to draw the selection 
//				marquee. 
//
//==============================================================================
- (void) setSelectionMarquee:(Box2)newBox_view
{
	self->selectionMarquee = newBox_view;
}


//========== setTarget: ========================================================
//
// Purpose:		Sets the object which is the receiver of this view's action 
//				methods. 
//
//==============================================================================
- (void) setTarget:(id)newTarget
{
	self->target = newTarget;
	
}//end setTarget:


//========== setViewingAngle: ==================================================
//
// Purpose:		Sets the modelview rotation, in degrees. The angle is applied in 
//				x-y-z order. 
//
// Notes:		These numbers do *not* include the fact that LDraw has an 
//				upside-down coordinate system. So if this method returns 
//				(0,0,0), that means "Front, looking right-side up." 
//
//==============================================================================
- (void) setViewingAngle:(Tuple3)newAngle
{
	Matrix4 modelview       = IdentityMatrix4;
	GLfloat glModelview[16];
	
	//Get the default angle.
	glMatrixMode(GL_MODELVIEW);
	
	modelview = Matrix4RotateModelview(modelview, newAngle);
	
	// The camera distance was set for us by -resetFrameSize, so as to be 
	// able to see the entire model. 
	modelview = V3LookAt(V3Make(0, 0, self->cameraDistance),
						 V3Make(0, 0, 0), 
						 V3Make(0, -1, 0), 
						 modelview);
	
	Matrix4GetGLMatrix4(modelview, glModelview);
	glLoadMatrixf(glModelview);
	
	[self->delegate LDrawGLRendererNeedsRedisplay:self];

}//end setViewingAngle:


//========== setViewOrientation: ===============================================
//
// Purpose:		Changes the camera position from which we view the model. 
//				i.e., ViewOrientationFront means we see the model head-on.
//
//==============================================================================
- (void) setViewOrientation:(ViewOrientationT)newOrientation
{
	Tuple3	newAngle	= [LDrawUtilities angleForViewOrientation:newOrientation];

	self->viewOrientation = newOrientation;
		
	// Apply the angle itself.
	[self setViewingAngle:newAngle];
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
	
}//end setViewOrientation:


//========== setViewportExpandsToAvailableSize: ================================
//
// Purpose:		Sets whether the viewport will always cover the full area of 
//				self->maximumVisibleSize, or whether it will be just big enough 
//				to fit the model. 
//
//==============================================================================
- (void) setViewportExpandsToAvailableSize:(BOOL)flag
{
	self->viewportExpandsToAvailableSize = flag;
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
}


//========== setZoomPercentage: ================================================
//
// Purpose:		Enlarges (or reduces) the magnification on this view. The center 
//				point of the original magnification remains the center point of 
//				the new magnification. Does absolutely nothing if this view 
//				isn't contained within a scroll view.
//
// Parameters:	newPercentage: new zoom; pass 100 for 100%, etc. Automatically 
//				constrained to a minimum of 1%. 
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage
{
	CGFloat currentZoomPercentage   = [self zoomPercentage];
	
	// Don't zoom if the zoom level isn't actually changing (to avoid 
	// unnecessary re-draw) 
	if(currentZoomPercentage != newPercentage)
	{
		Size2   frame           = self->bounds;
		Point2  originalCenter  = [self centerPoint];
		Point2  newCenter       = ZeroPoint2;
		Point2  centerFraction  = ZeroPoint2;
		
		// We want to maintain the visual center as we zoom. However, if the 
		// view is set to expand to its entire viewport, the frame may change 
		// size after zooming. That means we can't use the scroll center 
		// directly, but must instead calculate the proportion of the view it 
		// represents. 
		centerFraction.x = originalCenter.x / frame.width;
		centerFraction.y = originalCenter.y / frame.height;
		
		// Don't go below a certain zoom
		if(newPercentage >= 1)
		{
			self->zoomFactor                = newPercentage;
			self->visibleRect.size.width    /= (newPercentage / currentZoomPercentage);
			self->visibleRect.size.height   /= (newPercentage / currentZoomPercentage);
			
			[self->delegate LDrawGLRenderer:self didSetZoomPercentage:self->zoomFactor];
			
			[self resetFrameSize];
			
			// Restore the original scroll center using proportions, because the 
			// size of the frame may have changed. 
			frame       = self->bounds;
			newCenter.x = centerFraction.x * frame.width;
			newCenter.y = centerFraction.y * frame.height;
			[self scrollCenterToPoint:newCenter];
		}
	}

}//end setZoomPercentage


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== zoomIn: ===========================================================
//
// Purpose:		Enlarge the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomIn:(id)sender
{
	CGFloat currentZoom	= [self zoomPercentage];
	CGFloat newZoom		= currentZoom * 2;
	
	[self setZoomPercentage:newZoom];
	
}//end zoomIn:


//========== zoomOut: ==========================================================
//
// Purpose:		Shrink the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomOut:(id)sender
{
	CGFloat currentZoom	= [self zoomPercentage];
	CGFloat newZoom		= currentZoom / 2;
	
	[self setZoomPercentage:newZoom];
	
}//end zoomOut:


//========== zoomToFit: ========================================================
//
// Purpose:		Enlarge or shrink the zoom and scroll the model such that its 
//				image perfectly fills the visible area of the view 
//
//==============================================================================
- (IBAction) zoomToFit:(id)sender
{
	Size2   maxContentSize          = ZeroSize2;
	Box3    boundingBox             = InvalidBox;
	Point3  center                  = ZeroPoint3;
	Matrix4 modelView               = IdentityMatrix4;
	Matrix4 projection              = IdentityMatrix4;
	Box2    viewport                = ZeroBox2;
	GLfloat modelViewGLMatrix	[16];
	GLfloat projectionGLMatrix	[16];
	Box3    projectedBounds         = InvalidBox;
	Box2    projectionRect          = ZeroBox2;
	Size2   zoomScale2D             = ZeroSize2;
	CGFloat zoomScaleFactor         = 0.0;
	
	// How many onscreen pixels do we have to work with?
	maxContentSize.width    = V2BoxWidth(visibleRect)  * [self zoomPercentage]/100.;
	maxContentSize.height   = V2BoxHeight(visibleRect) * [self zoomPercentage]/100.;
//	NSLog(@"windowVisibleRect = %@", NSStringFromRect(windowVisibleRect));
//	NSLog(@"maxContentSize = %@", NSStringFromSize(maxContentSize));
	
	// Get bounds
	if([self->fileBeingDrawn respondsToSelector:@selector(boundingBox3)] )
	{
		boundingBox = [(id)self->fileBeingDrawn boundingBox3];
		if(V3EqualBoxes(boundingBox, InvalidBox) == NO)
		{		
			// Project the bounds onto the 2D "canvas"
			glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
			glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);
			
			modelView   = Matrix4CreateFromGLMatrix4(modelViewGLMatrix);
			projection  = Matrix4CreateFromGLMatrix4(projectionGLMatrix);
			viewport    = [self viewport];

			projectedBounds = [(id)self->fileBeingDrawn
									   projectedBoundingBoxWithModelView:modelView
															  projection:projection
																	view:viewport ];
			projectionRect  = V2MakeBox(projectedBounds.min.x, projectedBounds.min.y,   // origin
										projectedBounds.max.x - projectedBounds.min.x,  // width
										projectedBounds.max.y - projectedBounds.min.y); // height
										
			
			//---------- Find zoom scale -----------------------------------
			// Completely fill the viewport with the image
			
			zoomScale2D.width   = maxContentSize.width  / V2BoxWidth(projectionRect);
			zoomScale2D.height  = maxContentSize.height / V2BoxHeight(projectionRect);
			
			zoomScaleFactor		= MIN(zoomScale2D.width, zoomScale2D.height);
			
			
			//---------- Find visual center point --------------------------
			// One might think this would be V3CenterOfBox(bounds). But it's 
			// not. It seems perspective distortion can cause the visual 
			// center of the model to be someplace else. 
			
			Point2  graphicalCenter_viewport    = V2Make( V2BoxMidX(projectionRect), V2BoxMidY(projectionRect) );
			Point2 graphicalCenter_view        = [self convertPointFromViewport:graphicalCenter_viewport];
			Point3  graphicalCenter_model       = ZeroPoint3;
			
			graphicalCenter_model       = [self modelPointForPoint:graphicalCenter_view
											   depthReferencePoint:center];
			
			
			//---------- Zoom to Fit! --------------------------------------
			
			[self setZoomPercentage:([self zoomPercentage] * zoomScaleFactor)];
			[self scrollCenterToModelPoint:graphicalCenter_model];
		}
	}
	
}//end zoomToFit:



#pragma mark -
#pragma mark EVENTS
#pragma mark -

//========== mouseMoved: =======================================================
//
// Purpose:		Mouse has moved to the given view point. (This method is 
//				optional.) 
//
//==============================================================================
- (void) mouseMoved:(Point2)point_view
{
	[self publishMouseOverPoint:point_view];
}


//========== mouseDown =========================================================
//
// Purpose:		Signals that a mouse-down has been received; clear various state 
//				flags in preparation for selection or dragging. 
//
// Note:		Our platform view is responsible for correct interpretation of 
//				the event and routing it to the appropriate methods in the 
//				renderer class. 
//
//==============================================================================
- (void) mouseDown
{
	// Reset event tracking flags.
	self->isTrackingDrag	= NO;
	self->didPartSelection	= NO;
	
	// This might be the start of a new drag; start collecting frames per second
	fpsStartTime = [NSDate timeIntervalSinceReferenceDate];
	framesSinceStartTime = 0;
	
	[self->delegate markPreviousSelection:self];	
}


//========== mousedDragged =====================================================
//
// Purpose:		Signals that a mouse-drag has been received; clear various state 
//				flags in preparation for selection or dragging. 
//
// Note:		Our platform view is responsible for correct interpretation of 
//				the event and routing it to the appropriate methods in the 
//				renderer class. 
//
//==============================================================================
- (void) mouseDragged
{
	self->isStartingDrag    = (self->isTrackingDrag == NO); // first drag if none to date
	self->isTrackingDrag    = YES;
}


//========== mouseUp ===========================================================
//
// Purpose:		Signals that a mouse-up has been received; clear various state 
//				flags in preparation for selection or dragging. 
//
// Note:		Our platform view is responsible for correct interpretation of 
//				the event and routing it to the appropriate methods in the 
//				renderer class. 
//
//==============================================================================
- (void) mouseUp
{
	// Redraw from our dragging operations, if necessary.
	if(		(self->isTrackingDrag == YES && rotationDrawMode == LDrawGLDrawExtremelyFast)
	   ||	V2BoxWidth(self->selectionMarquee) || V2BoxHeight(self->selectionMarquee) )
	{
		[self->delegate LDrawGLRendererNeedsRedisplay:self];
	}
	
	self->activeDragHandle = nil;
	self->isTrackingDrag = NO; //not anymore.
	self->selectionMarquee = ZeroBox2;

	[self->delegate unmarkPreviousSelection:self];
}


#pragma mark - Clicking

//========== mouseCenterClick: =================================================
//
// Purpose:		We have received a mouseDown event which is intended to center 
//				our view on the point clicked.
//
//==============================================================================
- (void) mouseCenterClick:(Point2)viewClickedPoint
{
	// In orthographic projection, each world point always ends up in the same 
	// place on the document plane no matter where the scrollers are. So we can 
	// take a shortcut. 
	if(self->projectionMode == ProjectionModeOrthographic)
	{
		[self scrollCenterToPoint:viewClickedPoint];
	}
	else
	{
		// Perspective distortion makes this more complicated. The camera is in 
		// a fixed position, but the frustum changes with the scrollbars. 
		// We need to calculate the world point we just clicked on, then derive 
		// a new frustum projection centered on that point. 
		Point3  clickedPointInModel = ZeroPoint3;
		
		// Find the point we clicked on. It would be more accurate to use 
		// -getDirectivesUnderMouse:::, but it has to actually draw parts, which 
		// can be slow. 
		clickedPointInModel = [self modelPointForPoint:viewClickedPoint];
		
		[self scrollCenterToModelPoint:clickedPointInModel];
	}
	
}//end mouseCenterClick:


//========== mouseSelectionClick:extendSelection: ==============================
//
// Purpose:		Time to see if we should select something in the model. We 
//				search the model geometry for intersection with the click point. 
//				Our delegate is responsible for managing the actual selection. 
//
//				This function returns whether it hit something - calling code can
//				then do a part drag or marquee based on whether the user clicked
//				on a part or on empty space.
//
// Notes:		This method is optimized to do an iterative search, first with a
//				low-resolution draw, then on a high-resolution pass. It's about 
//				six times faster than just drawing the whole model.
//
//==============================================================================
- (BOOL) mouseSelectionClick:(Point2)point_view
			 selectionMode:(SelectionModeT)selectionMode
{
	NSArray			*fastDrawParts		= nil;
	NSArray			*fineDrawParts		= nil;
	LDrawDirective	*clickedDirective	= nil;
	
	self->selectionMarquee = V2MakeBox(point_view.x, point_view.y, 0, 0);

	// Only try to select if we are actually drawing something, and can actually 
	// select it. 
	if(		self->fileBeingDrawn != nil
	   &&	self->allowsEditing == YES
	   &&	[self->delegate respondsToSelector:@selector(LDrawGLRenderer:wantsToSelectDirective:byExtendingSelection:)] )
	{
		//first do hit-testing on nothing but the bounding boxes; that is very fast 
		// and likely eliminates a lot of parts.

		fastDrawParts	= [self getDirectivesUnderPoint:point_view
										amongDirectives:[NSArray arrayWithObject:self->fileBeingDrawn]
											   fastDraw:YES];
		
		//now do a full draw for testing on the most likely candidates
		fineDrawParts	= [self getDirectivesUnderPoint:point_view
										amongDirectives:fastDrawParts
											   fastDraw:NO];

				
		if([fineDrawParts count] > 0)
			clickedDirective = [fineDrawParts objectAtIndex:0];
			
		// Primitive manipulation?
		if([clickedDirective isKindOfClass:[LDrawDragHandle class]])
		{
			self->activeDragHandle = (LDrawDragHandle*)clickedDirective;
		}
		else
		{
			// Normal selection
			self->activeDragHandle = nil;
			
			// If we end up actually selecting some single thing, the extension happens if we are intersection (option-shift) or extend (shift).
			BOOL extendSelection = selectionMode == SelectionExtend || selectionMode == SelectionIntersection;
			
			BOOL has_sel_directive = clickedDirective != nil &&  [clickedDirective isSelected];
			BOOL has_any_directive = clickedDirective != nil;
			
			switch(selectionMode) {
			case SelectionReplace:				
				// Replacement mode?  Select unless we hit an already hit one - we do not "deselect others" on a click.
				if(!has_sel_directive)
					[self->delegate LDrawGLRenderer:self wantsToSelectDirective:clickedDirective byExtendingSelection:extendSelection ];				
				break;
			case SelectionExtend:
				// Extended selection.  If we hit a part, toggle it - if we miss a part, don't do anything, nothing to do.
				if(has_any_directive)
					[self->delegate LDrawGLRenderer:self wantsToSelectDirective:clickedDirective byExtendingSelection:extendSelection ];
				break;
			case SelectionIntersection:
				// Intersection.  If we hit an unselected directive, do the select to grab it - this will grab it (via option-shift).
				// Then we copy.  If we have no directive, the whole sel clears, which is the correct start for an intersection (since the
				// marquee is empty).
				if(!has_sel_directive)
					[self->delegate LDrawGLRenderer:self wantsToSelectDirective:clickedDirective byExtendingSelection:extendSelection ];
				break;
			case SelectionSubtract:
				// Subtraction.  If we have an UNSELECTED directive, we have to grab it.  If we have a selected directive  we do nothing so
				// we can option-drag-copy thes el.  And if we just miss everything, the subtraction hasn't nuked anything yet...again we do nothing.
				if(has_any_directive && !has_sel_directive)
					[self->delegate LDrawGLRenderer:self wantsToSelectDirective:clickedDirective byExtendingSelection:extendSelection ];
				break;
			}
		}
	}

	self->didPartSelection = YES;
	
	return (clickedDirective == nil) ? NO : YES;
	
}//end mousePartSelection:


//========== mouseZoomInClick: =================================================
//
// Purpose:		Depending on the tool mode, we want to zoom in or out. We also 
//				want to center the view on whatever we clicked on.
//
//==============================================================================
- (void) mouseZoomInClick:(Point2)viewClickedPoint
{
	CGFloat     currentZoom         = [self zoomPercentage];
	CGFloat     newZoom             = currentZoom * 2;
	
	[self setZoomPercentage:newZoom preservePoint:viewClickedPoint];
	
}//end mouseZoomInClick:


//========== mouseZoomOutClick: ================================================
//
// Purpose:		Depending on the tool mode, we want to zoom in or out. We also 
//				want to center the view on whatever we clicked on.
//
//==============================================================================
- (void) mouseZoomOutClick:(Point2)viewClickedPoint
{
	CGFloat     currentZoom         = [self zoomPercentage];
	CGFloat     newZoom             = currentZoom / 2;
	
	[self setZoomPercentage:newZoom preservePoint:viewClickedPoint];
	
}//end mouseZoomOutClick:


#pragma mark - Dragging

//========== dragHandleDragged: ================================================
//
// Purpose:		Move the active drag handle
//
//==============================================================================
- (void) dragHandleDraggedToPoint:(Point2)point_view
				constrainDragAxis:(BOOL)constrainDragAxis
{
	Point3	modelReferencePoint = [self->activeDragHandle position];
	BOOL	moved				= NO;

	[self publishMouseOverPoint:point_view];

	// Give the document controller an opportunity for undo management!
	if(self->isStartingDrag && [self->delegate respondsToSelector:@selector(LDrawGLRenderer:willBeginDraggingHandle:)])
	{
		[self->delegate LDrawGLRenderer:self willBeginDraggingHandle:self->activeDragHandle];
	}

	// Update with new position
	moved = [self updateDirectives:[NSArray arrayWithObject:self->activeDragHandle]
				  withDragPosition:point_view
			   depthReferencePoint:modelReferencePoint
					 constrainAxis:constrainDragAxis];
					 
	if(moved)
	{
		if([self->fileBeingDrawn respondsToSelector:@selector(optimizeVertexes)])
		{
			[(id)self->fileBeingDrawn optimizeVertexes];
		}

		[self->fileBeingDrawn noteNeedsDisplay];

		if([self->delegate respondsToSelector:@selector(LDrawGLRenderer:dragHandleDidMove:)])
		{
			[self->delegate LDrawGLRenderer:self dragHandleDidMove:self->activeDragHandle];
		}
	}

}//end dragHandleDragged:


//========== panDragged:location: ==============================================
//
// Purpose:		Scroll the view as the mouse is dragged across it. 
//
//==============================================================================
- (void) panDragged:(Vector2)viewDirection location:(Point2)point_view
{
	if(isStartingDrag)
	{
		self->initialDragLocation = [self modelPointForPoint:point_view];
	}
	
	Box2	viewport		= [self viewport];
	Point2	point_viewport	= [self convertPointToViewport:point_view];
	Point2	proportion		= V2Make(point_viewport.x, point_viewport.y);
	
	proportion.x /= V2BoxWidth(viewport);
	proportion.y /= V2BoxHeight(viewport);
	
	if([self->delegate respondsToSelector:@selector(LDrawGLRendererMouseNotPositioning:)])
		[self->delegate LDrawGLRendererMouseNotPositioning:self];
	
	[self scrollModelPoint:self->initialDragLocation toViewportProportionalPoint:proportion];
	
}//end panDragged:


//========== rotationDragged: ==================================================
//
// Purpose:		Tis time to rotate the object!
//
//				We need to translate horizontal and vertical 2-dimensional mouse 
//				drags into 3-dimensional rotations.
//
//		 +---------------------------------+       ///  /- -\ \\\   (This thing is a sphere.)
//		 |             y /|\               |      /     /   \    \				.
//		 |                |                |    //      /   \     \\			.
//		 |                |vertical        |    |   /--+-----+-\   |
//		 |                |motion (around x)   |///    |     |   \\\|
//		 |                |              x |   |       |     |      |
//		 |<---------------+--------------->|   |       |     |      |
//		 |                |     horizontal |   |\\\    |     |   ///|
//		 |                |     motion     |    |   \--+-----+-/   |
//		 |                |    (around y)  |    \\     |     |    //
//		 |                |                |      \     \   /    /
//		 |               \|/               |       \\\  \   / ///
//		 +---------------------------------+          --------
//
//				But 2D motion is not 3D motion! We can't just say that 
//				horizontal drag = rotation around y (up) axis. Why? Because the 
//				y-axis may be laying horizontally due to the rotation!
//
//				The trick is to convert the y-axis *on the projection screen* 
//				back to a *vector in the model*. Then we can just call glRotate 
//				around that vector. The result that the model is rotated in the 
//				direction we dragged, no matter what its orientation!
//
//				Last Note: A horizontal drag from left-to-right is a 
//					counterclockwise rotation around the projection's y axis.
//					This means a positive number of degrees caused by a positive 
//					mouse displacement.
//					But, a vertical drag from bottom-to-top is a clockwise 
//					rotation around the projection's x-axis. That means a 
//					negative number of degrees cause by a positive mouse 
//					displacement. That means we must multiply our x-rotation by 
//					-1 in order to make it go the right direction.
//
//==============================================================================
- (void) rotationDragged:(Vector2)viewDirection
{
	CGFloat	deltaX			=   viewDirection.x;
	CGFloat	deltaY			= - viewDirection.y; //Apple's delta is backwards, for some reason.
	
	// Get the percentage of the window we have swept over. Since half the 
	// window represents 180 degrees of rotation, we will eventually 
	// multiply this percentage by 180 to figure out how much to rotate. 
	CGFloat	percentDragX	= deltaX / bounds.width;
	CGFloat	percentDragY	= deltaY / bounds.height;
	
	// Remember, dragging on y means rotating about x.
	CGFloat	rotationAboutY	= + ( percentDragX * 180 );
	CGFloat	rotationAboutX	= - ( percentDragY * 180 ); //multiply by -1,
				// as we need to convert our drag into a proper rotation 
				// direction. See notes in function header.
	
	//Get the current transformation matrix. By using its inverse, we can 
	// convert projection-coordinates back to the model coordinates they 
	// are displaying.
	Matrix4 inversed = [self getInverseMatrix];
	
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
	
	if(self->viewOrientation != ViewOrientation3D)
	{
		[self setProjectionMode:ProjectionModePerspective];
		self->viewOrientation = ViewOrientation3D;
	}
	
	//Now rotate the model around the visual "up" and "down" directions.
	glMatrixMode(GL_MODELVIEW);
	glRotatef( rotationAboutY, transformedVectorY.x, transformedVectorY.y, transformedVectorY.z);
	glRotatef( rotationAboutX, transformedVectorX.x, transformedVectorX.y, transformedVectorX.z);
	
	if([self->delegate respondsToSelector:@selector(LDrawGLRendererMouseNotPositioning:)])
		[self->delegate LDrawGLRendererMouseNotPositioning:self];
	
	[self->delegate LDrawGLRendererNeedsRedisplay:self];
	
}//end rotationDragged


//========== zoomDragged: ======================================================
//
// Purpose:		Drag up means zoom in, drag down means zoom out. 1 px = 1 %.
//
//==============================================================================
- (void) zoomDragged:(Vector2)viewDirection
{
	CGFloat pixelChange     = -viewDirection.y;			// Negative means down
	CGFloat magnification   = pixelChange/100;			// 1 px = 1%
	CGFloat zoomChange      = 1.0 + magnification;
	CGFloat currentZoom     = [self zoomPercentage];
	
	[self setZoomPercentage:(currentZoom * zoomChange)];
	
	if([self->delegate respondsToSelector:@selector(LDrawGLRendererMouseNotPositioning:)])
		[self->delegate LDrawGLRendererMouseNotPositioning:self];
	
}//end zoomDragged:


//========== mouseSelectionDragToPoint:extendSelection: ========================
//
// Purpose:		Selects objects under the dragged rectangle.  Caller code tracks
//				the rectangle itself.
//
//==============================================================================
- (void) mouseSelectionDragToPoint:(Point2)point_view
				   selectionMode:(SelectionModeT) selectionMode
{
	NSArray			*fastDrawParts		= nil;
	NSArray			*fineDrawParts		= nil;
	
	self->selectionMarquee = V2MakeBoxFromPoints(selectionMarquee.origin, point_view);

	// Only try to select if we are actually drawing something, and can actually 
	// select it. 
	if(		self->fileBeingDrawn != nil
	   &&	self->allowsEditing == YES
	   &&	[self->delegate respondsToSelector:@selector(LDrawGLRenderer:wantsToSelectDirective:byExtendingSelection:)] )
	{
		// First do hit-testing on nothing but the bounding boxes; that is very 
		// fast and likely eliminates a lot of parts. 

		fastDrawParts = [self getDirectivesUnderRect:self->selectionMarquee
									 amongDirectives:[NSArray arrayWithObject:self->fileBeingDrawn]
											fastDraw:YES];

		fineDrawParts = [self getDirectivesUnderRect:self->selectionMarquee
									 amongDirectives:fastDrawParts
											fastDraw:NO];

		[self->delegate LDrawGLRenderer:self
				wantsToSelectDirectives:fineDrawParts
				   selectionMode:selectionMode ];
		
	}

	self->didPartSelection = YES;
	
}//end mouseSelectionDrag:to:extendSelection:


#pragma mark -
#pragma mark Gestures

//========== beginGesture ======================================================
//
// Purpose:		Our platform host view is informing us that it is starting 
//				gesture tracking. 
//
//==============================================================================
- (void) beginGesture
{
	self->isGesturing = YES;
}


//========== endGesture ========================================================
//
// Purpose:		Our platform host view is informing us that it is ending 
//				gesture tracking. 
//
//==============================================================================
- (void) endGesture
{
	self->isGesturing = NO;
	
	if(self->rotationDrawMode == LDrawGLDrawExtremelyFast)
	{
		[self->delegate LDrawGLRendererNeedsRedisplay:self];
	}
}


//========== rotateWithEvent: ==================================================
//
// Purpose:		User is doing the twist (rotate) trackpad gesture. Rotate 
//				counterclockwise by the given degrees. 
//
//				I have decided to interpret this as spinning the "baseplate" 
//				plane of the model (that is, spinning around -y). 
//
//==============================================================================
- (void) rotateByDegrees:(float)angle
{
	if(self->viewOrientation != ViewOrientation3D)
	{
		[self setProjectionMode:ProjectionModePerspective];
		self->viewOrientation = ViewOrientation3D;
	}

	// Rotate.
	glMatrixMode(GL_MODELVIEW);
	glRotatef( angle, 0, -1, 0);

}//end rotateWithEvent:


#pragma mark -
#pragma mark DRAG AND DROP
#pragma mark -

//========== draggingEnteredAtPoint: ===========================================
//
// Purpose:		A drag-and-drop part operation entered this view. We need to 
//			    initiate interactive dragging. 
//
//==============================================================================
- (void) draggingEnteredAtPoint:(Point2)point_view
					 directives:(NSArray *)directives
				   setTransform:(BOOL)setTransform
			  originatedLocally:(BOOL)originatedLocally
{
	LDrawDrawableElement	*firstDirective 	= [directives objectAtIndex:0];
	LDrawPart				*newPart			= nil;
	TransformComponents 	partTransform		= IdentityComponents;
	Point3					modelReferencePoint = ZeroPoint3;
	
	//---------- Initialize New Part? ------------------------------------------
	
	if(setTransform == YES)
	{
		// Uninitialized elements are always new parts from the part browser.
		newPart = [directives objectAtIndex:0];
	
		// Ask the delegate roughly where it wants us to be.
		// We get a full transform here so that when we drag in new parts, they 
		// will be rotated the same as whatever part we were using last. 
		if([self->delegate respondsToSelector:@selector(LDrawGLRendererPreferredPartTransform:)])
		{
			partTransform = [self->delegate LDrawGLRendererPreferredPartTransform:self];
			[newPart setTransformComponents:partTransform];
		}
	}
	
	
	//---------- Find Location -------------------------------------------------
	// We need to map our 2-D mouse coordinate into a point in the model's 3-D 
	// space.
	
	modelReferencePoint	= [firstDirective position];
	
	// Apply the initial offset.
	// This is the difference between the position of part 0 and the actual 
	// clicked point. We do this so that the point you clicked always remains 
	// directly under the mouse.
	//
	// Only applicable if dragging into the source view. Other views may have 
	// different orientations. We might be able to remove that requirement by 
	// zeroing the inapplicable component. 
	if(originatedLocally == YES)
	{
		modelReferencePoint = V3Add(modelReferencePoint, self->draggingOffset);
	}
	else
	{
		[self setDraggingOffset:ZeroPoint3]; // no offset for future updates either
	}

	// For constrained dragging, we care only about the initial, unmodified 
	// postion. 
	self->initialDragLocation = modelReferencePoint;
	
	// Move the parts
	[self updateDirectives:directives
		  withDragPosition:point_view
	   depthReferencePoint:modelReferencePoint
			 constrainAxis:NO];
	
	// The drag has begun!
	if([self->fileBeingDrawn respondsToSelector:@selector(setDraggingDirectives:)])
	{
		[(id)self->fileBeingDrawn setDraggingDirectives:directives];
		
		[self->fileBeingDrawn noteNeedsDisplay];
	}
	
}//end draggingEntered:


//========== endDragging =======================================================
//
// Purpose:		Ends part drag-and-drop.
//
//==============================================================================
- (void) endDragging
{
	if([self->fileBeingDrawn respondsToSelector:@selector(setDraggingDirectives:)])
	{
		[(id)self->fileBeingDrawn setDraggingDirectives:nil];
		
		[self->fileBeingDrawn noteNeedsDisplay];
	}
}


//========== updateDragWithPosition:constrainAxis: =============================
//
// Purpose:		Adjusts the directives so they align with the given drag 
//				location, in window coordinates. 
//
//==============================================================================
- (void) updateDragWithPosition:(Point2)point_view
				  constrainAxis:(BOOL)constrainAxis
{
	NSArray 				*directives 			= nil;
	Point3					modelReferencePoint 	= ZeroPoint3;
	LDrawDrawableElement	*firstDirective 		= nil;
	BOOL					moved					= NO;
	
	[self publishMouseOverPoint:point_view];
	
	if([self->fileBeingDrawn respondsToSelector:@selector(draggingDirectives)])
	{
		directives			= [(id)self->fileBeingDrawn draggingDirectives];
		firstDirective		= [directives objectAtIndex:0];
		modelReferencePoint = [firstDirective position];
		modelReferencePoint = V3Add(modelReferencePoint, self->draggingOffset);
		
		moved = [self updateDirectives:directives
					  withDragPosition:point_view
				   depthReferencePoint:modelReferencePoint
						 constrainAxis:constrainAxis];
		if(moved)
		{
			if([self->fileBeingDrawn respondsToSelector:@selector(optimizeVertexes)])
			{
				[(id)self->fileBeingDrawn optimizeVertexes];
			}
			
			[self->fileBeingDrawn noteNeedsDisplay];
		}
	}
	
}//end updateDirectives:withDragPosition:


//========== updateDirectives:withDragPosition: ================================
//
// Purpose:		Adjusts the directives so they align with the given drag 
//				location, in window coordinates. 
//
//==============================================================================
- (BOOL) updateDirectives:(NSArray *)directives
		 withDragPosition:(Point2)point_view
	  depthReferencePoint:(Point3)modelReferencePoint
			constrainAxis:(BOOL)constrainAxis
{
	LDrawDrawableElement	*firstDirective 		= nil;
	Point3					modelPoint				= ZeroPoint3;
	Point3					oldPosition 			= ZeroPoint3;
	Point3					constrainedPosition 	= ZeroPoint3;
	Vector3 				displacement			= ZeroPoint3;
	Vector3 				cumulativeDisplacement	= ZeroPoint3;
	NSUInteger				counter 				= 0;
	BOOL					moved					= NO;
	
	firstDirective	= [directives objectAtIndex:0];
	
	
	//---------- Find Location ---------------------------------------------
	
	// Where are we?
	oldPosition				= modelReferencePoint;
	
	// and adjust.
	modelPoint              = [self modelPointForPoint:point_view depthReferencePoint:modelReferencePoint];
	displacement            = V3Sub(modelPoint, oldPosition);
	cumulativeDisplacement  = V3Sub(modelPoint, self->initialDragLocation);
	
	
	//---------- Find Actual Displacement ----------------------------------
	// When dragging, we want to move IN grid increments, not move TO grid 
	// increments. That means we snap the displacement vector itself to the 
	// grid, not part's location. That's because the part may not have been 
	// grid-aligned to begin with. 
	
	// As is conventional in graphics programs, we allow dragging to be 
	// constrained to a single axis. We will pick that axis that is furthest 
	// from the initial drag location. 
	if(constrainAxis == YES)
	{
		// Find the part's position along the constrained axis.
		cumulativeDisplacement	= V3IsolateGreatestComponent(cumulativeDisplacement);
		constrainedPosition		= V3Add(self->initialDragLocation, cumulativeDisplacement);
		
		// Get the displacement from the part's current position to the 
		// constrained one. 
		displacement = V3Sub(constrainedPosition, oldPosition);
	}
	
	// Snap the displacement to the grid.
	displacement			= [firstDirective position:displacement snappedToGrid:self->gridSpacing];
	
	//---------- Update the parts' positions  ------------------------------
	
	if(V3EqualPoints(displacement, ZeroPoint3) == NO)
	{
		// Move all the parts by that amount.
		for(counter = 0; counter < [directives count]; counter++)
		{
			[[directives objectAtIndex:counter] moveBy:displacement];
		}
		
		moved = YES;
	}
	
	return moved;
	
}//end updateDirectives:withDragPosition:


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== displayNeedsUpdating: =============================================
//
// Purpose:		Someone (likely our file) has notified us that it has changed, 
//				and thus we need to redraw.
//
//				We also use this opportunity to grow the canvas if necessary.
//
//==============================================================================
- (void) displayNeedsUpdating:(NSNotification *)notification
{
	[self->delegate LDrawGLRendererNeedsCurrentContext:self];

	[self resetFrameSize]; //calls setNeedsDisplay
	
}//end displayNeedsUpdating


//========== reshape ===========================================================
//
// Purpose:		Something changed in the viewing department; we need to adjust 
//				our projection and viewing area.
//
//==============================================================================
- (void) reshape
{
	CGFloat	scaleFactor	= [self zoomPercentage] / 100;
	
//	NSLog(@"GL view(%p) reshaping; frame %@", self, NSStringFromRect([self frame]));
	
	//Make a new view based on the current viewable area
	[self makeProjection];

	// How many PIXELS of the screen should the context use?
	glViewport(0,0, V2BoxWidth(visibleRect) * scaleFactor, V2BoxHeight(visibleRect) * scaleFactor );
	
}//end reshape


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== getDepthUnderPoint: ===============================================
//
// Purpose:		Returns the depth component of the nearest object under the view 
//				point. 
//
//				Returns 1.0 if there is no object under the point.
//
//==============================================================================
- (float) getDepthUnderPoint:(Point2)point_view
{
	Point2  point_viewport  = [self convertPointToViewport:point_view];
	GLfloat depth           = 1.0;
	
	// Find the location in the depth buffer. This tells us the percentage of 
	// depth of the nearest pixel to the viewer.
	// Note: This function is not available in OpenGL ES.
//	glReadPixels(point_viewport.x, point_viewport.y,
//				 1, 1,  	// width, height
//				 GL_DEPTH_COMPONENT,
//				 GL_FLOAT, &depth);
				 
	// Since we can't read the depth buffer in OpenGL ES, we will use the 
	// ray-tracing code. 

	Point3				contextNear 			= ZeroPoint3;
	Point3				contextFar				= ZeroPoint3;
	Ray3				pickRay 				= {{0}};
	Point3				pickRay_end 			= ZeroPoint3;
	Box2				viewport				= [self viewport];
	GLfloat 			projectionGLMatrix[16]	= {0.0};
	GLfloat 			modelViewGLMatrix[16]	= {0.0};
	NSMutableDictionary *hits					= [NSMutableDictionary dictionary];
	NSArray 			*clickedDirectives		= nil;
	NSUInteger			counter 				= 0;
	LDrawDirective		*currentDirective		= nil;
	float				currentDepth			= 0.0;
	
	// Get view and projection
	glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
	glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);
	
	// convert to 3D viewport coordinates
	contextNear		= V3Make(point_viewport.x, point_viewport.y, 0.0);
	contextFar		= V3Make(point_viewport.x, point_viewport.y, 1.0);
	
	// Pick Ray
	pickRay.origin      = V3Unproject(contextNear,
									  Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
									  Matrix4CreateFromGLMatrix4(projectionGLMatrix),
									  viewport);
	pickRay_end         = V3Unproject(contextFar,
									  Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
									  Matrix4CreateFromGLMatrix4(projectionGLMatrix),
									  viewport);
	pickRay.direction   = V3Sub(pickRay_end, pickRay.origin);
	pickRay.direction	= V3Normalize(pickRay.direction);
	
	// Do bounding-box hit test
	[fileBeingDrawn hitTest:pickRay
				  transform:IdentityMatrix4
				  viewScale:[self zoomPercentage]/100.
				 boundsOnly:YES
			   creditObject:nil
					   hits:hits];
	clickedDirectives = [self getPartsFromHits:hits];
	
	// Do full-resolution test for exact depth point
	if([clickedDirectives count] >= 1)
	{
		[hits removeAllObjects];
		for(counter = 0; counter < [clickedDirectives count]; counter++)
		{
			[[clickedDirectives objectAtIndex:counter] hitTest:pickRay
													 transform:IdentityMatrix4
													 viewScale:[self zoomPercentage]/100.
													boundsOnly:NO
												  creditObject:nil
														  hits:hits];
		}
		// Find shallowest hit. The hit record depths are mapped as depths along 
		// the pick ray. 
		for(NSValue *key in hits)
		{
			currentDirective    = [key pointerValue];
			currentDepth        = [[hits objectForKey:key] floatValue];
			
			if(currentDepth < depth)
			{
				depth = currentDepth;
			}
		}
	}
	
	return depth;	
}


//========== getDirectivesUnderMouse:amongDirectives:fastDraw: =================
//
// Purpose:		Finds the directives under a given mouse-click. This method is 
//				written so that the caller can optimize its hit-detection by 
//				doing a preliminary test on just the bounding boxes.
//
// Parameters:	theEvent	= mouse-click event
//				directives	= the directives under consideration for being 
//								clicked. This may be the whole File directive, 
//								or a smaller subset we have already determined 
//								(by a previous call) is in the area.
//				fastDraw	= consider only bounding boxes for hit-detection.
//
// Returns:		Array of clicked parts; the closest one -- and the only one we 
//				ultimately care about -- is always the 0th element.
//
//==============================================================================
- (NSArray *) getDirectivesUnderPoint:(Point2)point_view
					  amongDirectives:(NSArray *)directives
							 fastDraw:(BOOL)fastDraw
{
	NSArray	*clickedDirectives	= nil;
	
	if([directives count] == 0)
	{
		// If there's nothing to test in, there's no work to do!
		clickedDirectives = [NSArray array];
	}
	else
	{
		Point2              point_viewport          = [self convertPointToViewport:point_view];
		Point3              contextNear             = ZeroPoint3;
		Point3              contextFar              = ZeroPoint3;
		Ray3                pickRay                 = {{0}};
		Point3              pickRay_end             = ZeroPoint3;
		Box2				viewport	            = [self viewport];
		GLfloat             projectionGLMatrix[16]  = {0.0};
		GLfloat             modelViewGLMatrix[16]   = {0.0};
		NSMutableDictionary *hits                   = [NSMutableDictionary dictionary];
		NSUInteger          counter                 = 0;
		
		// Get view and projection
		glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
		glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);
		
		// convert to 3D viewport coordinates
		contextNear		= V3Make(point_viewport.x, point_viewport.y, 0.0);
		contextFar		= V3Make(point_viewport.x, point_viewport.y, 1.0);
		
		// Pick Ray
		pickRay.origin      = V3Unproject(contextNear,
										  Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
										  Matrix4CreateFromGLMatrix4(projectionGLMatrix),
										  viewport);
		pickRay_end         = V3Unproject(contextFar,
										  Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
										  Matrix4CreateFromGLMatrix4(projectionGLMatrix),
										  viewport);
		pickRay.direction   = V3Sub(pickRay_end, pickRay.origin);
		pickRay.direction	= V3Normalize(pickRay.direction);
		
		// Do hit test
		for(counter = 0; counter < [directives count]; counter++)
		{
			[[directives objectAtIndex:counter] hitTest:pickRay
											  transform:IdentityMatrix4
											  viewScale:[self zoomPercentage]/100.
											 boundsOnly:fastDraw
										   creditObject:nil
												   hits:hits];
		}
		
		clickedDirectives = [self getPartsFromHits:hits];
	}

	return clickedDirectives;
	
}//end getDirectivesUnderMouse:amongDirectives:fastDraw:


//========== getDirectivesUnderRect:amongDirectives:fastDraw: ==================
//
// Purpose:		Finds the directives under a given mouse-recangle.  This
//				does a two-pass search so that clients can do a bounding box
//				test first.
//
// Parameters:	bottom_left, top_right = the rectangle (in viewport space) in 
//										 which to test.
//				directives	= the directives under consideration for being 
//								clicked. This may be the whole File directive, 
//								or a smaller subset we have already determined 
//								(by a previous call) is in the area.
//				fastDraw	= consider only bounding boxes for hit-detection.
//
// Returns:		Array of all parts that are at least partly inside the rectangle
//				in screen space.
//
//==============================================================================
- (NSArray *) getDirectivesUnderRect:(Box2)rect_view 
					 amongDirectives:(NSArray *)directives
							fastDraw:(BOOL)fastDraw
{
	NSArray	*clickedDirectives	= nil;
	
	if([directives count] == 0)
	{
		// If there's nothing to test in, there's no work to do!
		clickedDirectives = [NSArray array];
	}
	else
	{
		Point2			bottom_left 			= rect_view.origin;
		Point2			top_right				= V2Make( V2BoxMaxX(rect_view), V2BoxMaxY(rect_view) );
		Point2			bl						= [self convertPointToViewport:bottom_left];
		Point2			tr						= [self convertPointToViewport:top_right];
		Box2			viewport				= [self viewport];
		GLfloat 		projectionGLMatrix[16]	= {0.0};
		GLfloat 		modelViewGLMatrix[16]	= {0.0};
		NSMutableSet	*hits					= [NSMutableSet set];
		NSUInteger		counter 				= 0;
		
		// Get view and projection
		glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
		glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);

		float x1 = (MIN(bl.x,tr.x) - viewport.origin.x) * 2.0 / V2BoxWidth (viewport) - 1.0;
		float x2 = (MAX(bl.x,tr.x) - viewport.origin.x) * 2.0 / V2BoxWidth (viewport) - 1.0;
		float y1 = (MIN(bl.y,tr.y) - viewport.origin.x) * 2.0 / V2BoxHeight(viewport) - 1.0;
		float y2 = (MAX(bl.y,tr.y) - viewport.origin.y) * 2.0 / V2BoxHeight(viewport) - 1.0;

		Box2	test_box = V2MakeBox(x1,y1,x2-x1,y2-y1);
		
		Matrix4	mvp =			Matrix4Multiply(
										Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
										Matrix4CreateFromGLMatrix4(projectionGLMatrix));
										
		// Do hit test
		for(counter = 0; counter < [directives count]; counter++)
		{
			[[directives objectAtIndex:counter] boxTest:test_box
											  transform:mvp 
											  viewScale:[self zoomPercentage]/100.
											 boundsOnly:fastDraw
										   creditObject:nil
												   hits:hits];
		}

		NSMutableArray * collected = [NSMutableArray arrayWithCapacity:[hits count]];
		clickedDirectives = collected;
		
		for(NSValue *key in hits)
		{
			LDrawDirective * currentDirective    = [key pointerValue];
			[collected addObject:currentDirective];
		}
	}

	return clickedDirectives;
	
}//end getDirectivesUnderMouse:amongDirectives:fastDraw


//========== getPartFromHits:hitCount: =========================================
//
// Purpose:		Deduce the parts that were clicked on, given the selection data 
//				returned from -[LDrawDirective hitTest:...]
//
//				Each time something's geometry intersects our pick ray under the 
//				mouse (and it has a different name), it generates a hit record. 
//				So we have to investigate our hits and figure out which hit was 
//				the nearest to the front (smallest minimum depth); that is the 
//				one we clicked on. 
//
// Returns:		Array of all the parts under the click. The nearest part is 
//				guaranteed to be the first entry in the array. There is no 
//				defined order for the rest of the parts.
//
//==============================================================================
- (NSArray *) getPartsFromHits:(NSDictionary *)hits
{
	NSMutableArray  *clickedDirectives  = [NSMutableArray arrayWithCapacity:[hits count]];
	LDrawDirective  *currentDirective   = nil;
	float           minimumDepth        = INFINITY;
	float           currentDepth        = 0;
	
	// The hit record depths are mapped as depths along the pick ray. We are 
	// looking for the shallowest point, because that's what we clicked on. 
	
	for(NSValue *key in hits)
	{
		currentDirective    = [key pointerValue];
		currentDepth        = [[hits objectForKey:key] floatValue];
		
//		NSLog(@"Hit depth %f %@", currentDepth, currentDirective);
		
		if(currentDepth < minimumDepth)
		{
			// guarantee shallowest object is first in array
			[clickedDirectives insertObject:currentDirective atIndex:0];
			minimumDepth = currentDepth;
		}
		else
		{
			[clickedDirectives addObject:currentDirective];
		}
	}
//	NSLog(@"===============================================");
	
	return clickedDirectives;
	
}//end getPartFromHits:hitCount:


//========== publishMouseOverPoint: ============================================
//
// Purpose:		Informs the delegate that the mouse is hovering over the model 
//				point under the view point. 
//
//==============================================================================
- (void) publishMouseOverPoint:(Point2)point_view
{
	Point3		modelPoint			= ZeroPoint3;
	Vector3		modelAxisForX		= ZeroPoint3;
	Vector3		modelAxisForY		= ZeroPoint3;
	Vector3		modelAxisForZ		= ZeroPoint3;
	Vector3		confidence			= ZeroPoint3;
	
	if([self->delegate respondsToSelector:@selector(LDrawGLRenderer:mouseIsOverPoint:confidence:)])
	{
		modelPoint = [self modelPointForPoint:point_view];
		
		if([self projectionMode] == ProjectionModeOrthographic)
		{
			[self getModelAxesForViewX:&modelAxisForX Y:&modelAxisForY Z:&modelAxisForZ];
			
			confidence = V3Add(modelAxisForX, modelAxisForY);
		}
		
		[self->delegate LDrawGLRenderer:self mouseIsOverPoint:modelPoint confidence:confidence];
	}
}


//========== resetFrameSize: ===================================================
//
// Purpose:		We resize the canvas to accomodate the model. It automatically 
//				shrinks for small models and expands for large ones. Neat-o!
//
//==============================================================================
- (void) resetFrameSize
{
	// We do not want to apply this resizing to a raw GL view.
	// It only makes sense for those in a scroll view. (The Part Browsers have 
	// been moved to scrollviews now too in order to allow zooming.) 
	if( [self->fileBeingDrawn respondsToSelector:@selector(boundingBox3)] )
	{
		// Determine whether the canvas size needs to change.
		Point3	origin			= {0,0,0};
		Point2	centerPoint		= [self centerPoint];
		Box3	newBounds		= InvalidBox;
		
		if([self->fileBeingDrawn respondsToSelector:@selector(boundingBox3)])
		{
			newBounds = [(id)fileBeingDrawn boundingBox3]; //cast to silence warning.
		}

		if(V3EqualBoxes(newBounds, InvalidBox) == YES)
		{
			newBounds = V3BoundsFromPoints(V3Make(-1, -1, -1), V3Make(1, 1, 1));
		}
		
		//
		// Find bounds size, based on model dimensions.
		//
		
		float	distance1		= V3DistanceBetween2Points(origin, newBounds.min );
		float	distance2		= V3DistanceBetween2Points(origin, newBounds.max );
		float	newSize			= MAX(distance1, distance2) + 40; //40 is just to provide a margin.
		GLfloat	currentMatrix[16];
		
		// The canvas resizing is set to a fairly large granularity so 
		// it doesn't constantly change on people. 
		newSize = ceil(newSize / 384) * 384;
		
		//
		// Reposition the Camera
		//
		
		// As the size of the model changes, we must move the camera in 
		// and out so as to view the entire model in the right 
		// perspective. Moving the camera is equivalent to translating 
		// the modelview matrix. (That's what gluLookAt does.) 
		// Note:	glTranslatef() doesn't work here. If M is the current matrix, 
		//			and T is the translation, it performs M = M x T. But we need 
		//			M = T x M, because OpenGL uses transposed matrices.
		//			Solution: set matrix manually. Is there a better one?
		glMatrixMode(GL_MODELVIEW);
		glGetFloatv(GL_MODELVIEW_MATRIX, currentMatrix);

		// As cameraDistance approaches infinity, the view approximates 
		// an orthographic projection. We want a fairly large number 
		// here to produce a small, only slightly-noticable perspective. 
		self->cameraDistance = - (newSize) * CAMERA_DISTANCE_FACTOR;
		currentMatrix[12] = 0; //reset the camera location. Positions 12-14 of 
		currentMatrix[13] = 0; // the matrix hold the translation values.
		currentMatrix[14] = cameraDistance;
		glLoadMatrixf(currentMatrix); // It's easiest to set them directly.

		//
		// Resize the Frame
		//
		
		Size2	oldFrameSize	= self->bounds;
		Size2	newFrameSize	= ZeroSize2;
		
		self->snugFrameSize	= V2MakeSize( newSize*2, newSize*2 );
		
		if(self->viewportExpandsToAvailableSize == YES)
		{
			// Make the frame either just a little bit bigger than the 
			// size of the model, or the same as the scroll view, 
			// whichever is larger. 
			newFrameSize	= V2MakeSize( MAX(snugFrameSize.width,  self->maximumVisibleSize.width  / ([self zoomPercentage]/100)),
										  MAX(snugFrameSize.height, self->maximumVisibleSize.height / ([self zoomPercentage]/100)) );
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
		
//			NSLog(@"frame %f %f; camera %f", newFrameSize.width, newFrameSize.height, cameraDistance);
		[self setBounds:newFrameSize];
		if([self->delegate respondsToSelector:@selector(LDrawGLRenderer:didSetBoundsToSize:)])
		{
			[self->delegate  LDrawGLRenderer:self didSetBoundsToSize:self->bounds];
		}
		[self scrollCenterToPoint:centerPoint]; //must preserve this; otherwise, viewing is funky.
		
		// Make *sure* the projection matches the frame. Ordinarily, this 
		// happens automatically in -reshape. But when the view is set to 
		// fill its entire scroll view, the frame *may not actualy change*, 
		// even though the camera distance DOES! If we didn't force the 
		// projection to be remade here, the model would just vanish in that 
		// case. 
		[self makeProjection];
		
		//NSLog(@"minimum (%f, %f, %f); maximum (%f, %f, %f)", newBounds.min.x, newBounds.min.y, newBounds.min.z, newBounds.max.x, newBounds.max.y, newBounds.max.z);
		[self->delegate LDrawGLRendererNeedsRedisplay:self];
	}
	
}//end resetFrameSize


//========== resetVisibleRect ==================================================
//
// Purpose:		Recomputes the visible rect based on the current bounds and max 
//				visible area. 
//
//==============================================================================
- (void) resetVisibleRect
{
	Box2	newFrame		= ZeroBox2;
	Box2	maxVisibleRect	= ZeroBox2;
	Point2	maxVisiblePoint = ZeroPoint2;
	Box2	newVisibleRect	= ZeroBox2;
	
	newFrame.origin				= ZeroPoint2;
	newFrame.size				= self->bounds;
	
	maxVisibleRect.origin		= self->visibleRect.origin;
	maxVisibleRect.size 		= self->maximumVisibleSize;
	maxVisibleRect.size.width	/= self->zoomFactor / 100;
	maxVisibleRect.size.height	/= self->zoomFactor / 100;
	
	maxVisiblePoint.x			= MIN( V2BoxMaxX(maxVisibleRect), V2BoxMaxX(newFrame) );
	maxVisiblePoint.y			= MIN( V2BoxMaxY(maxVisibleRect), V2BoxMaxY(newFrame) );
	
	newVisibleRect.origin		= self->visibleRect.origin;
	newVisibleRect.size.width	= maxVisiblePoint.x - V2BoxMinX(maxVisibleRect);
	newVisibleRect.size.height	= maxVisiblePoint.y - V2BoxMinY(maxVisibleRect);
	
	self->visibleRect			= newVisibleRect;
	
	[self reshape];
}


//========== setZoomPercentage:preservePoint: ==================================
//
// Purpose:		Performs cursor-centric zooming on the given point, in view 
//				coordinates. After the new zoom is applied, the 3D point 
//				projected at viewPoint will still be in the same projected 
//				location. 
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage
			 preservePoint:(Point2)viewPoint
{
	Point2 viewportProportion  = ZeroPoint2;
	Point3  modelPoint          = ZeroPoint3;
	
	// Cursor-centric zooming: when the new zoom factor is applied, the point in 
	// the model we clicked on should still be directly under the mouse. 
	modelPoint = [self modelPointForPoint:viewPoint];
	
	viewportProportion.x = (viewPoint.x - V2BoxMinX(visibleRect)) / V2BoxWidth(visibleRect);
	viewportProportion.y = (viewPoint.y - V2BoxMinY(visibleRect)) / V2BoxHeight(visibleRect);
	
	if([self isFlipped] == YES)
	{
		viewportProportion.y = 1.0 - viewportProportion.y;
	}
	
	[self setZoomPercentage:newPercentage];
	[self scrollModelPoint:modelPoint toViewportProportionalPoint:viewportProportion];

}//end setZoomPercentage:preservePoint:


//========== scrollCenterToModelPoint: =========================================
//
// Purpose:		Scrolls the receiver (if it is inside a scroll view) so that 
//				newCenter is at the center of the viewing area. newCenter is 
//				given in LDraw model coordinates.
//
//==============================================================================
- (void) scrollCenterToModelPoint:(Point3)modelPoint
{
	[self scrollModelPoint:modelPoint toViewportProportionalPoint:V2Make(0.5, 0.5)];
}


//========== scrollModelPoint:toViewportProportionalPoint: =====================
//
// Purpose:		Scrolls viewport so the projection of the given 3D point appears 
//				at the given fraction of the viewport. (0,0) means the 
//				bottom-right corner of the viewport; (0.5, 0.5) means the 
//				center; (1.0, 1.0) means the top-right. 
//
//==============================================================================
- (void)     scrollModelPoint:(Point3)modelPoint
  toViewportProportionalPoint:(Point2)viewportPoint
{
	Point3  cameraPoint         = V3Make(0, 0, self->cameraDistance);
	Point2  newCenter           = ZeroPoint2;
	float   nearClippingZ       = 0;
	float   zEval               = 0;
	Matrix4 modelViewMatrix     = [self getMatrix];
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
		currentClippingRect = [self nearFrustumClippingRectFromVisibleRect:self->visibleRect];
		
		// Transforming causes an undesired shift on z. I'm not mathematically 
		// sure why yet, but it is lethal and must be undone. I think it has 
		// something to do with LDraw's flipped coordinate system and the camera 
		// location therein... 
		transformedPoint.z *= -1;
		
		// Intersect the 3D line between the camera and the clicked point with 
		// the near clipping plane. 
		nearClippingZ   = - [self fieldDepth] / 2;
		zEval           = (nearClippingZ - cameraPoint.z) / (transformedPoint.z - cameraPoint.z);
		newCenter.x     = zEval * (transformedPoint.x - cameraPoint.x) + cameraPoint.x;
		newCenter.y     = zEval * (transformedPoint.y - cameraPoint.y) + cameraPoint.y;
		
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
		currentClippingRect = [self nearOrthoClippingRectFromVisibleRect:self->visibleRect];
		
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
	[self scrollRectToVisible:newVisibleRect];
	
}//end scrollCenterToModelPoint:


//========== scrollCenterToPoint ===============================================
//
// Purpose:		Scrolls the receiver (if it is inside a scroll view) so that 
//				newCenter is at the center of the viewing area. newCenter is 
//				given in frame coordinates.
//
//==============================================================================
- (void) scrollCenterToPoint:(Point2)newCenter
{
	Box2	newVisibleRect	= self->visibleRect;
	Point2	scrollOrigin	= V2Make(newCenter.x - V2BoxWidth(visibleRect)/2,
									 newCenter.y - V2BoxHeight(visibleRect)/2);
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
	
	[self scrollRectToVisible:newVisibleRect];
	
}//end scrollCenterToPoint:


//========== scrollRectToVisible: ==============================================
//
// Purpose:		Sets the visible rect to aRect.
//
//==============================================================================
- (void) scrollRectToVisible:(Box2)aRect
{
	if( V2EqualBoxes(aRect, self->visibleRect) == false )
	{
		self->visibleRect = aRect;
		
		if([self->delegate respondsToSelector:@selector(LDrawGLRenderer:scrollToRect:)])
		{
			[self->delegate LDrawGLRenderer:self scrollToRect:self->visibleRect];
		}
		[self->delegate LDrawGLRendererNeedsRedisplay:self];
	}
}


#pragma mark -
#pragma mark Geometry

//========== convertPointFromViewport: =========================================
//
// Purpose:		Converts the point from the viewport coordinate system to the 
//				view bounds' coordinate system. 
//
//==============================================================================
- (Point2) convertPointFromViewport:(Point2)viewportPoint
{
	Point2	point_visibleRect	= ZeroPoint2;
	Point2	point_view			= ZeroPoint2;
	
	// Rescale to visible rect
	point_visibleRect.x = viewportPoint.x / ([self zoomPercentage]/100.);
	point_visibleRect.y = viewportPoint.y / ([self zoomPercentage]/100.);
	
	// The viewport origin is always at (0,0), so wo only need to translate if 
	// the coordinate system is flipped. 
	
	// Flip the coordinates
	if([self isFlipped])
	{
		// The origin of the viewport is in the lower-left corner.
		// The origin of the view is in the upper right (it is flipped)
		point_visibleRect.y = V2BoxHeight(visibleRect) - point_visibleRect.y;
	}
	
	// Translate to full bounds coordinates
	point_view.x = point_visibleRect.x + visibleRect.origin.x;
	point_view.y = point_visibleRect.y + visibleRect.origin.y;
	
	return point_view;
	
}//end convertPointFromViewport:


//========== convertPointToViewport: ===========================================
//
// Purpose:		Converts the point from the view bounds' coordinate system into 
//				the viewport's coordinate system. 
//
//==============================================================================
- (Point2) convertPointToViewport:(Point2)point_view
{
	Point2	point_visibleRect	= ZeroPoint2;
	Point2	point_viewport		= ZeroPoint2;
	
	// Translate from full bounds coordinates to the visible rect
	point_visibleRect.x = point_view.x - visibleRect.origin.x;
	point_visibleRect.y = point_view.y - visibleRect.origin.y;
	
	// Flip the coordinates
	if([self isFlipped])
	{
		// The origin of the viewport is in the lower-left corner.
		// The origin of the view is in the upper right (it is flipped)
		point_visibleRect.y = V2BoxHeight(visibleRect) - point_visibleRect.y;
	}
	
	// Rescale to viewport pixels
	point_viewport.x = point_visibleRect.x * ([self zoomPercentage]/100.);
	point_viewport.y = point_visibleRect.y * ([self zoomPercentage]/100.);
	
	return point_viewport;
	
}//end convertPointToViewport:


//========== fieldDepth ========================================================
//
// Purpose:		Returns the distance between the near and far clipping planes.
//
// Notes:		Once upon a time, I had a feature called "infinite field depth," 
//				as opposed to a depth that would clip the model. Eventually I 
//				concluded this was a bad idea. But for future reference, the 
//				maximum fieldDepth is about 1e6 (50,000 studs, >1300 ft; 
//				probably enough!); viewing goes haywire with bigger numbers. 
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


//========== getModelAxesForViewX:Y:Z: =========================================
//
// Purpose:		Finds the axes in the model coordinate system which most closely 
//			    project onto the X, Y, Z axes of the view. 
//
// Notes:		The screen coordinate system is right-handed:
//
//					 +y
//					|
//					|
//					*-- +x
//				   /
//				  +z
//
//				The choice between what is the "closest" axis in the model is 
//			    often arbitrary, but it will always be a unique and 
//			    sensible-looking choice. 
//
//==============================================================================
- (void) getModelAxesForViewX:(Vector3 *)outModelX
							Y:(Vector3 *)outModelY
							Z:(Vector3 *)outModelZ
{
	Vector4 screenX		= {1,0,0,1};
	Vector4 screenY		= {0,1,0,1};
	Vector4 unprojectedX, unprojectedY; //the vectors in the model which are projected onto x,y on screen
	Vector3 modelX, modelY, modelZ; //the closest model axes to which the screen's x,y,z align
	
	// Translate the x, y, and z vectors on the surface of the screen into the 
	// axes to which they most closely align in the model itself. 
	// This requires the inverse of the current transformation matrix, so we can 
	// convert projection-coordinates back to the model coordinates they are 
	// displaying. 
	Matrix4 inversed = [self getInverseMatrix];
	
	//find the vectors in the model which project onto the screen's axes
	// (We only care about x and y because this is a two-dimensional 
	// projection, and the third axis is consquently ambiguous. See below.) 
	unprojectedX = V4MulPointByMatrix(screenX, inversed);
	unprojectedY = V4MulPointByMatrix(screenY, inversed);
	
	//find the actual axes closest to those model vectors
	modelX	= V3FromV4(unprojectedX);
	modelY	= V3FromV4(unprojectedY);
	
	modelX	= V3IsolateGreatestComponent(modelX);
	modelY	= V3IsolateGreatestComponent(modelY);
	
	modelX	= V3Normalize(modelX);
	modelY	= V3Normalize(modelY);
	
	// The z-axis is often ambiguous because we are working backwards from a 
	// two-dimensional screen. Thankfully, while the process used for deriving 
	// the x and y vectors is perhaps somewhat arbitrary, it always yields 
	// sensible and unique results. Thus we can simply derive the z-vector, 
	// which will be whatever axis x and y *didn't* land on. 
	modelZ = V3Cross(modelX, modelY);
	
	if(outModelX != NULL)
		*outModelX = modelX;
	if(outModelY != NULL)
		*outModelY = modelY;
	if(outModelZ != NULL)
		*outModelZ = modelZ;
	
}//end getModelAxesForViewX:Y:Z:


//========== modelPointForPoint: ===============================================
//
// Purpose:		Unprojects the given point (in view coordinates) back into a 
//			    point in the model which projects there, using existing data in 
//				the depth buffer to infer the location on the z axis. 
//
// Notes:		The depth buffer is not super-accurate, but it's passably 
//				close. But most importantly, it could be faster to read the 
//				depth buffer than to redraw parts of the model under a pick 
//				matrix. 
//
//==============================================================================
- (Point3) modelPointForPoint:(Point2)viewPoint
{
	Point2              viewportPoint           = [self convertPointToViewport:viewPoint];
	float               depth                   = 0.0; 
	TransformComponents partTransform           = IdentityComponents;
	Point3              contextPoint            = ZeroPoint3;
	GLfloat             modelViewGLMatrix	[16];
	GLfloat             projectionGLMatrix	[16];
	Point3              modelPoint              = ZeroPoint3;
	
	depth = [self getDepthUnderPoint:viewPoint];
	
	if(depth == 1.0)
	{
		// Error!
		// Maximum depth readings essentially tell us that no pixels were drawn 
		// at this point. So we have to make up a best guess now. This guess 
		// will very likely be wrong, but there is little else which can be 
		// done. 
		
		if([self->delegate respondsToSelector:@selector(LDrawGLRendererPreferredPartTransform:)])
		{
			partTransform = [self->delegate LDrawGLRendererPreferredPartTransform:self];
		}

		modelPoint = [self modelPointForPoint:viewPoint
						  depthReferencePoint:partTransform.translate];
	}
	else
	{
		// Convert to 3D viewport coordinates
		contextPoint = V3Make(viewportPoint.x, viewportPoint.y, depth);
	
		// Convert back to a point in the model.
		glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
		glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);
		
		modelPoint = V3Unproject(contextPoint,
								 Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
								 Matrix4CreateFromGLMatrix4(projectionGLMatrix),
								 [self viewport]);
	}
	
	return modelPoint;
	
}//end modelPointForPoint:


//========== modelPointForPoint:depthReferencePoint: ===========================
//
// Purpose:		Unprojects the given point (in view coordinates) back into a 
//			    point in the model which projects there, calculating the 
//				location on the z axis using the given depth reference point. 
//
// Notes:		Any point on the screen represents the projected location of an 
//			    infinite number of model points, extending on a line from the 
//			    near to the far clipping plane. 
//
//				It's impossible to boil that down to a single point without 
//			    being given some known point in the model to determine the 
//			    desired depth. (Hence the depthPoint parameter.) The returned 
//			    point will lie on a plane which contains depthPoint and is 
//			    perpendicular to the model axis most closely aligned to the 
//			    computer screen's z-axis. 
//
//										* * * *
//
//				When viewing the model with an orthographic projection and the 
//			    camera pointing parallel to one of the model's coordinate axes, 
//				this method is useful for determining two of the three 
//			    coordinates over which the mouse is hovering. To find which 
//			    coordinate is bogus, we call -getModelAxesForViewX:Y:Z:. The 
//			    returned z-axis indicates the unreliable point. 
//
//==============================================================================
- (Point3) modelPointForPoint:(Point2)viewPoint
		  depthReferencePoint:(Point3)depthPoint
{
	GLfloat modelViewGLMatrix	[16];
	GLfloat projectionGLMatrix	[16];
	Box2	viewport				= [self viewport];
	
	Point2	contextPoint			= [self convertPointToViewport:viewPoint];
	Point3	nearModelPoint			= ZeroPoint3;
	Point3	farModelPoint			= ZeroPoint3;
	Point3	modelPoint				= ZeroPoint3;
	Vector3 modelZ					= ZeroPoint3;
	float	t						= 0; //parametric variable
	
	glGetFloatv(GL_PROJECTION_MATRIX, projectionGLMatrix);
	glGetFloatv(GL_MODELVIEW_MATRIX, modelViewGLMatrix);
	
	// gluUnProject takes a window "z" coordinate. These values range from 
	// 0.0 (on the near clipping plane) to 1.0 (the far clipping plane). 
	
	// - Near clipping plane unprojection
	nearModelPoint = V3Unproject(V3Make(contextPoint.x, contextPoint.y, 0.0),
								 Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
								 Matrix4CreateFromGLMatrix4(projectionGLMatrix),
								 viewport);
	
	// - Far clipping plane unprojection
	farModelPoint = V3Unproject(V3Make(contextPoint.x, contextPoint.y, 1.0),
								Matrix4CreateFromGLMatrix4(modelViewGLMatrix),
								Matrix4CreateFromGLMatrix4(projectionGLMatrix),
								viewport);
	
	//---------- Derive the actual point from the depth point --------------
	//
	// We now have two accurate unprojected coordinates: the near (P1) and 
	// far (P2) points of the line through 3-D space which projects onto the 
	// single screen point. 
	//
	// The parametric equation for a line given two points is:
	//
	//		 /      \														/
	//	 L = | 1 - t | P  + t P        (see? at t=0, L = P1 and at t=1, L = P2.
	//		 \      /   1      2
	//
	// So for example,	z = (1-t)*z1 + t*z2
	//					z = z1 - t*z1 + t*z2
	//
	//								/       \								/
	//					 z = z  - t | z - z  |
	//						  1     \  1   2/
	//
	//
	//						  z  - z
	//						   1			No need to worry about dividing 
	//					 t = ---------		by 0 because the axis we are 
	//						  z  - z		inspecting will never be 
	//						   1    2		perpendicular to the screen.

	// Which axis are we going to use from the reference point?
	[self getModelAxesForViewX:NULL Y:NULL Z:&modelZ];
	
	// Find the value of the parameter at the depth point.
	if(modelZ.x != 0)
	{
		t = (nearModelPoint.x - depthPoint.x) / (nearModelPoint.x - farModelPoint.x);
	}
	else if(modelZ.y != 0)
	{
		t = (nearModelPoint.y - depthPoint.y) / (nearModelPoint.y - farModelPoint.y);
	}
	else if(modelZ.z != 0)
	{
		t = (nearModelPoint.z - depthPoint.z) / (nearModelPoint.z - farModelPoint.z);
	}
	// Evaluate the equation of the near-to-far line at the parameter for 
	// the depth point. 
	modelPoint.x = LERP(t, nearModelPoint.x, farModelPoint.x);
	modelPoint.y = LERP(t, nearModelPoint.y, farModelPoint.y);
	modelPoint.z = LERP(t, nearModelPoint.z, farModelPoint.z);

	return modelPoint;
	
}//end modelPointForPoint:depthReferencePoint:


//========== makeProjection ====================================================
//
// Purpose:		Loads the viewing projection appropriate for our canvas size.
//
//==============================================================================
- (void) makeProjection
{
	float	fieldDepth		= [self fieldDepth];
	Box2	visibilityPlane	= ZeroBox2;
	
	//ULTRA-IMPORTANT NOTE: this method assumes that you have already made our 
	// openGLContext the current context
	
	// Start from scratch
	glMatrixMode(GL_PROJECTION); //we are changing the projection, NOT the model!
	glLoadIdentity();
	
	if(self->projectionMode == ProjectionModePerspective)
	{
		visibilityPlane = [self nearFrustumClippingRectFromVisibleRect:visibleRect];
		
		glFrustum(V2BoxMinX(visibilityPlane),	// left
				  V2BoxMaxX(visibilityPlane),	// right
				  V2BoxMinY(visibilityPlane),	// bottom
				  V2BoxMaxY(visibilityPlane),	// top
				  fabs(cameraDistance) - fieldDepth/2,	// near (closer points are clipped); distance from CAMERA LOCATION
				  fabs(cameraDistance) + fieldDepth/2	// far (points beyond this are clipped); distance from CAMERA LOCATION
				 );
	}
	else
	{
		visibilityPlane = [self nearOrthoClippingRectFromVisibleRect:visibleRect];
		
		glOrtho(V2BoxMinX(visibilityPlane),	// left
				V2BoxMaxX(visibilityPlane),	// right
				V2BoxMinY(visibilityPlane),	// bottom
				V2BoxMaxY(visibilityPlane),	// top
				fabs(cameraDistance) - fieldDepth/2,	// near (points beyond these are clipped)
				fabs(cameraDistance) + fieldDepth/2 );	// far
	}
	
}//end makeProjection


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
	if([self isFlipped] == YES)
	{
		y = bounds.height - y - V2BoxHeight(visibleRectIn);
	}
	
	//The projection plane is stated in model coordinates.
	visibilityPlane.origin.x	= V2BoxMinX(visibleRectIn) - bounds.width/2;
	visibilityPlane.origin.y	= y - bounds.height/2;
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
	
	newVisibleRect.origin.x    = visibilityPlane.origin.x + bounds.width/2;
	newVisibleRect.origin.y    = visibilityPlane.origin.y + bounds.height/2;
	newVisibleRect.size        = visibilityPlane.size;
	
	if([self isFlipped] == YES)
	{
		newVisibleRect.origin.y = bounds.height - V2BoxHeight(visibilityPlane) - V2BoxMinY(newVisibleRect);
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


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		glFinishForever();
//
//==============================================================================
- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[fileBeingDrawn	release];

	[super dealloc];
	
}//end dealloc


@end
