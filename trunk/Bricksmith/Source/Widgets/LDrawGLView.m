//==============================================================================
//
// File:		LDrawGLView.m
//
// Purpose:		This is the intermediary between the operating system (events 
//				and view hierarchy) and the LDrawGLRenderer (responsible for all 
//				platform-independent drawing logic). 
//
//				Certain interactions must be handed off to an LDrawDocument in 
//				order for them to effect the object being drawn. 
//
//				This class also provides for a number of mouse-based viewing 
//				tools triggered by hotkeys. However, we don't track them here! 
//				(We want *all* LDrawGLViews to respond to hotkeys at once.) So 
//				there is a symbiotic relationship with ToolPalette to track 
//				which tool mode we're in; we get notifications when it changes.
//
// Threading:	At one point, I was trying to get LDrawGLView to spawn a 
//				separate thread to draw. It never worked right. But there are 
//				two critical pieces of shared data protected by mutual-exclusion 
//				locks as a result: 
//				
//					* the NSOpenGLContext
//
//					* the contents of the directive being drawn
//						--	I kinda cheated on this one. Only LDrawFiles 
//							automatically maintain mutexes. It's a safe shortcut
//							because only Files are edited! The editor must track 
//							the lock manually.
//
//  Created by Allen Smith on 4/17/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawGLView.h"

#import <OpenGL/OpenGL.h>

#import "FocusRingView.h"
#import "LDrawApplication.h"
#import "LDrawColor.h"
#import "LDrawDirective.h"
#import "LDrawDocument.h"
#import "LDrawDragHandle.h"
#import "LDrawFile.h"
#import "LDrawModel.h"
#import "LDrawPart.h"
#import "LDrawGLRenderer.h"
#import "LDrawStep.h"
#import "LDrawUtilities.h"
#import "MacLDraw.h"
#import "OverlayViewCategory.h"
#import "ScrollViewCategory.h"
#import "UserDefaultsCategory.h"

#define USE_TURNTABLE				([[NSUserDefaults standardUserDefaults] integerForKey:ROTATE_MODE_KEY] == RotateModeTurntable)
#define USE_RIGHT_SPIN				([[NSUserDefaults standardUserDefaults] integerForKey:RIGHT_BUTTON_BEHAVIOR_KEY] == RightButtonRotates)
#define USE_ZOOM_WHEEL				([[NSUserDefaults standardUserDefaults] integerForKey:MOUSE_WHEEL_BEHAVIOR_KEY] == MouseWheelZooms)

#define SIMPLIFICATION_THRESHOLD	0.3 //seconds
#define CAMERA_DISTANCE_FACTOR		6.5	//controls perspective; cameraLocation = modelSize * CAMERA_DISTANCE_FACTOR

//========== NSRectToBox2 ======================================================
//
// Purpose:		Convert Cocoa rects to our internal format.
//
//==============================================================================
static Box2 NSRectToBox2(NSRect rect)
{
	Box2 box = V2MakeBox(NSMinX(rect), NSMinY(rect), NSWidth(rect), NSHeight(rect));
	
	return box;
}


//========== NSSizeToSize2 =====================================================
//
// Purpose:		Convert Cocoa sizes to our internal format.
//
//==============================================================================
static Size2 NSSizeToSize2(NSSize size)
{
	Size2 sizeOut = V2MakeSize(size.width, size.height);
	
	return sizeOut;
}


@implementation LDrawGLView

//========== awakeFromNib ======================================================
//
// Purpose:		Set up our Cocoa viewing.
//
// Notes:		This method will get called twice: once because we load our 
//				accessory view from a Nib file, and once when this object is 
//				unpacked from the Nib in which it's stored.
//
//==============================================================================
- (void) awakeFromNib
{
	id		superview	= [self superview];
	
	// If we are in a scroller, make sure we appear centered when smaller than 
	// the scroll view. 
	[[self enclosingScrollView] centerDocumentView];

	if([superview isKindOfClass:[NSClipView class]])
	{
		[superview setCopiesOnScroll:NO];
	}
	
	//Machinery needed to draw Quartz overtop OpenGL. Sadly, it caused our view 
	// to become transparent when minimizing to the dock. In the end, I didn't 
	// need it anyway.
//	long backgroundOrder = -1;
//	[[self openGLContext] setValues:&backgroundOrder forParameter: NSOpenGLCPSurfaceOrder];
//
//
//	NSScrollView *scrollView = [self enclosingScrollView];
//	if(scrollView != nil){
//		NSLog(@"making stuff transparent");
//		[[self window] setOpaque:NO];
//		[[self window] setAlphaValue:.999f];
////		[[self superview] setDrawsBackground:NO];
////		[scrollView setDrawsBackground:NO];
//	}
	
}//end awakeFromNib

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== initWithFrame: ====================================================
//
// Purpose:		For programmatically-created GL views.
//
//==============================================================================
- (id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format
{
	self = [super initWithFrame:frameRect pixelFormat:format];
	
	[self internalInit];
	
	return self;
	
}//end initWithFrame:


//========== initWithCoder: ====================================================
//
// Purpose:		For GL views loaded from Interface Builder.
//
//==============================================================================
- (id) initWithCoder: (NSCoder *) coder
{	
	self = [super initWithCoder: coder];
	
	// Ignore any settings defined in Interface Builder's lame-o inspector panel.
	[self internalInit];
	
	return self;
	
}//end initWithCoder:


//========== internalInit ======================================================
//
// Purpose:		Set up the beatiful OpenGL view.
//
//==============================================================================
- (void) internalInit
{
	NSOpenGLContext         *context            = nil;
	NSOpenGLPixelFormat     *pixelFormat        = [LDrawApplication openGLPixelFormat];
	NSNotificationCenter    *notificationCenter = [NSNotificationCenter defaultCenter];
	
	[[self openGLContext] makeCurrentContext];
	
	renderer = [[LDrawGLRenderer alloc] initWithBounds:NSSizeToSize2([self bounds].size)];
	[renderer setDelegate:self];

	selectionIsMarquee = NO;
	marqueeSelectionMode = SelectionReplace;
	
	//---------- Load UI -------------------------------------------------------
	
	// Yes, we have a nib file. Don't laugh. This view has accessories.
	[NSBundle loadNibNamed:@"LDrawGLViewAccessories" owner:self];
	
	self->focusRingView = [[[FocusRingView alloc] initWithFrame:[self bounds]] autorelease];
	[focusRingView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[focusRingView setFocusSource:self];
	
	[self addOverlayView:focusRingView];
	
	
	//---------- Initialize instance variables ---------------------------------
	
	[self setAcceptsFirstResponder:YES];
	[self->renderer setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]];
	
	canDrawLock				= [[NSConditionLock alloc] initWithCondition:NO];
	keepDrawThreadAlive		= YES;
	
	// Set up our OpenGL context. We need to base it on a shared context so that 
	// display-list names can be shared globally throughout the application.
	context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat
										 shareContext:[LDrawApplication sharedOpenGLContext]];
	[self setOpenGLContext:context];
//	[context setView:self]; //documentation says to do this, but it generates an error. Weird.
	[[self openGLContext] makeCurrentContext];
	
	[self setPixelFormat:pixelFormat];
	
	// Multithreading engine
	// It turned out to be as miserable a failure as my home-spun attempts. 
	// Three times longer and display corruption to boot. Bricksmith is 
	// apparently allergic to multithreading of any kind, and darn if I know 
	// why. 
//	CGLEnable(CGLGetCurrentContext(), kCGLCEMPEngine);
	
	// Prevent "tearing"
	GLint   swapInterval    = 1;
	[[self openGLContext] setValues: &swapInterval
					   forParameter: NSOpenGLCPSwapInterval ];
	
	// GL surface should be under window to allow Cocoa overtop.
	// Huge FPS hit--over 40%! Don't do it!
//	GLint   surfaceOrder    = -1;
//	[[self openGLContext] setValues: &surfaceOrder
//					   forParameter: NSOpenGLCPSurfaceOrder ];
			
	[self setViewOrientation:ViewOrientation3D];
	
	
	//---------- Register notifications ----------------------------------------
	
	[notificationCenter addObserver:self
						   selector:@selector(mouseToolDidChange:)
							   name:LDrawMouseToolDidChangeNotification
							 object:nil ];
	
	[notificationCenter addObserver:self
						   selector:@selector(backgroundColorDidChange:)
							   name:LDrawViewBackgroundColorDidChangeNotification
							 object:nil ];
	
	NSTrackingAreaOptions	options 		= (		NSTrackingMouseEnteredAndExited
											   |	NSTrackingMouseMoved
											   |	NSTrackingActiveInActiveApp
											   |	NSTrackingInVisibleRect
											  );
	NSTrackingArea			*trackingArea	= [[NSTrackingArea alloc] initWithRect:NSZeroRect
																  options:options
																	owner:self
																 userInfo:nil];
	[self addTrackingArea:trackingArea];
	[trackingArea release];
	
}//end internalInit


//========== prepareOpenGL =====================================================
//
// Purpose:		The context is all set up; this is where we prepare our OpenGL 
//				state.
//
//==============================================================================
- (void) prepareOpenGL
{
	[self->renderer prepareOpenGL];
	
	[self takeBackgroundColorFromUserDefaults]; //glClearColor()
	
}//end prepareOpenGL



#pragma mark -
#pragma mark DRAWING
#pragma mark -

//========== drawRect: =========================================================
//
// Purpose:		Draw the file into the view.
//
//==============================================================================
- (void) drawRect:(NSRect)rect
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	//We have the option of doing multithreaded drawing, so all the actual 
	// drawing code is in a thread-accessible method.
	
	//threading isn't working out well at all. So I have a threading preference, 
	// which will be OFF by default.
	if([userDefaults boolForKey:@"UseThreads"] == YES)
	{
		// signal the render thread to wake up
		[self->canDrawLock lockWhenCondition:NO];
		[self->canDrawLock unlockWithCondition:YES];
	}
	else
	{
		// draw directly
		[self draw];
	}
		
}//end drawRect:


//========== threadDrawLoop ====================================================
//
// Purpose:		This is the body function for highly-experimental multithreaded 
//				drawing.
//
// Notes:		As of Bricksmith 2.1, this still doesn't work, even after years 
//				of trying to get it to. It really seems like Mac OS X is at 
//				fault.
//
//==============================================================================
- (void) threadDrawLoop:(id)sender
{
	BOOL threadCanContinue = YES;
	
	while(threadCanContinue == YES)
	{
		[self->canDrawLock lockWhenCondition:YES];
		{
			NSAutoreleasePool	*pool	= [[NSAutoreleasePool alloc] init];
			
			[self draw];
			
			// the keepAlive flag is protected by our canDrawLock mutex.
			threadCanContinue = self->keepDrawThreadAlive;
			
			[pool release];
		}
		[self->canDrawLock unlockWithCondition:NO];
	}
	
}//end threadDrawLoop:


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
	//mark another outstanding draw request, then get in line by requesting the 
	// mutex.
	@synchronized(self)
	{
		numberDrawRequests += 1;
	}
	
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
		
		//any previous draw requests have now executed and let go of the mutex.
		// if we are the LAST draw in the queue, we draw. Otherwise, we drop 
		// ourselves, and defer to the last guy.
		if(numberDrawRequests == 1)
		{
			[self->renderer draw];
			
		}
		//else we just drop the draw.
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
	//cleanup
	@synchronized(self)
	{
		self->numberDrawRequests -= 1;
	}
	
}//end draw


//========== drawFocusRing =====================================================
//
// Purpose:		Draws a focus ring around the view, which indicates that this 
//				view is the first responder.
//
// Notes:		This is obsolete; the focus ring can (and is) now drawn in 
//				Cocoa. 
//
//==============================================================================
- (void) drawFocusRing
{
//	NSRect	visibleRect = [self visibleRect];
//	CGFloat	lineWidth	= 1.0;
//	
//	lineWidth /= [self->renderer zoomPercentage] / 100;
//	
//	//we just want to DRAW plain colored pixels.
//	glDisable(GL_LIGHTING);
//	
//	glMatrixMode(GL_PROJECTION);
//	glPushMatrix();
//	{
//		glLoadIdentity();
//		gluOrtho2D( NSMinX(visibleRect), NSMaxX(visibleRect),
//				    NSMinY(visibleRect), NSMaxY(visibleRect) );
//				   
//		glMatrixMode(GL_MODELVIEW);
//		glPushMatrix();
//		{
//			//we indicate focus by drawing a series of framing lines.
//			
//			glLoadIdentity();
//			
//			glColor4ub(125, 151, 174, 255);
//			[self strokeInsideRect:visibleRect
//						 thickness:lineWidth];
//			
//			glColor4ub(137, 173, 204, 213);
//			[self strokeInsideRect:NSInsetRect( visibleRect, 1 * lineWidth, 1 * lineWidth )
//						 thickness:lineWidth];
//			
//			glColor4ub(161, 184, 204, 172);
//			[self strokeInsideRect:NSInsetRect( visibleRect, 2 * lineWidth, 2 * lineWidth )
//						 thickness:lineWidth];
//			
//			glColor4ub(184, 195, 204, 128);
//			[self strokeInsideRect:NSInsetRect( visibleRect, 3 * lineWidth, 3 * lineWidth )
//						 thickness:lineWidth];
//		}
//		glPopMatrix();
//	}
//	glMatrixMode(GL_PROJECTION);
//	glPopMatrix();
//	
//	glEnable(GL_LIGHTING);

}//end drawFocusRing


//========== strokeInsideRect:thickness: =======================================
//
// Purpose:		Draws a line of the specified thickness on the inside edge of 
//				the rectangle.
//
//==============================================================================
- (void) strokeInsideRect:(NSRect)rect
				thickness:(CGFloat)borderWidth
{
	//draw like the wood of a picture frame: four trapezoids
	glBegin(GL_QUAD_STRIP);
	
	//lower left
	glVertex2f( NSMinX(rect),				NSMinY(rect)				);
	glVertex2f( NSMinX(rect) + borderWidth,	NSMinY(rect) + borderWidth	);
	
	//lower right
	glVertex2f( NSMaxX(rect),				NSMinY(rect)				);
	glVertex2f( NSMaxX(rect) - borderWidth,	NSMinY(rect) + borderWidth	);
	
	//upper right
	glVertex2f( NSMaxX(rect),				NSMaxY(rect)				);
	glVertex2f( NSMaxX(rect) - borderWidth,	NSMaxY(rect) - borderWidth	);
	
	//upper left
	glVertex2f( NSMinX(rect),				NSMaxY(rect)				);
	glVertex2f( NSMinX(rect) + borderWidth,	NSMaxY(rect) - borderWidth	);
	
	//lower left (finish last trapezoid)
	glVertex2f( NSMinX(rect),				NSMinY(rect)				);
	glVertex2f( NSMinX(rect) + borderWidth,	NSMinY(rect) + borderWidth	);
	
	glEnd();
	
}//end strokeInsideRect:thickness:


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

//========== acceptsFirstResponder =============================================
//
// Purpose:		Allows us to pick up key events.
//
//==============================================================================
- (BOOL)acceptsFirstResponder
{
	return self->acceptsFirstResponder;
	
}//end acceptsFirstResponder


//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code of the receiver.
//
//==============================================================================
-(LDrawColor *) LDrawColor
{
	[[self openGLContext] makeCurrentContext];
	return [self->renderer LDrawColor];
	
}//end color


//========== LDrawDirective ====================================================
//
// Purpose:		Returns the file or model being drawn by this view.
//
//==============================================================================
- (LDrawDirective *) LDrawDirective
{
	return [self->renderer LDrawDirective];
	
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
//==============================================================================
- (ProjectionModeT) projectionMode
{
	[[self openGLContext] makeCurrentContext];
	return [self->renderer projectionMode];
	
}//end projectionMode


//========== viewingAngle ======================================================
//==============================================================================
- (Tuple3) viewingAngle
{
	[[self openGLContext] makeCurrentContext];

	Tuple3	angle	= [self->renderer viewingAngle];
	
	return angle;
	
}//end viewingAngle


//========== viewOrientation ===================================================
//
// Purpose:		Returns the current camera orientation for this view.
//
//==============================================================================
- (ViewOrientationT) viewOrientation
{
	[[self openGLContext] makeCurrentContext];
	return [self->renderer viewOrientation];
	
}//end viewOrientation


//========== zoomPercentage ====================================================
//
// Purpose:		Returns the percentage magnification being applied to the 
//				receiver.
//
//==============================================================================
- (CGFloat) zoomPercentage
{
	[[self openGLContext] makeCurrentContext];
	return [self->renderer zoomPercentage];
	
}//end zoomPercentage


#pragma mark -

//========== setAcceptsFirstResponder: =========================================
//
// Purpose:		Do we want to pick up key events?
//
//==============================================================================
- (void) setAcceptsFirstResponder:(BOOL)flag
{
	self->acceptsFirstResponder = flag;
}//end 


//========== setAutosaveName: ==================================================
//
// Purpose:		Sets the name under which this view saves its viewing 
//				configuration. Pass nil for no saving.
//
//==============================================================================
- (void) setAutosaveName:(NSString *)newName
{
	[newName retain];
	[self->autosaveName release];
	self->autosaveName = newName;
	
}//end setAutosaveName:


//========== setDelegate: ======================================================
//
// Purpose:		Sets the object that acts as the delegate for the receiver. 
//
// Notes:		This object acts in tandem with two different "delegate" 
//				concepts: the delegate and the document. The delegate is 
//				responsible for more high-level, general activity, as described 
//				in the LDrawGLViewDelegate category. The document is an actual 
//				LDrawDocument, used for the nitty-gritty manipulation of the 
//				model this view supports. 
//
//==============================================================================
- (void) setDelegate:(id)object
{
	// weak link.
	self->delegate = object;
	
	// Drag and Drop support. We only accept drags if we have a document to add 
	// them to. 
	if([self->delegate respondsToSelector:@selector(LDrawGLView:acceptDrop:directives:)])
		[self registerForDraggedTypes:[NSArray arrayWithObject:LDrawDraggingPboardType]];
	else
		[self unregisterDraggedTypes];
		
	if([self->delegate respondsToSelector:@selector(LDrawGLView:wantsToSelectDirective:byExtendingSelection:)])
	{
		[self->renderer setAllowsEditing:YES];
	}
	else
	{
		[self->renderer setAllowsEditing:NO];
	}
	
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


//========== setFrame: =========================================================
//
// Purpose:		Frame size is being changed.
//
//==============================================================================
- (void)setFrame:(NSRect)frameRect
{
	[[self openGLContext] makeCurrentContext];
	[super setFrame:frameRect];
	[self->renderer setBounds:NSSizeToSize2(frameRect.size)];
}


//========== setGridSpacingMode: ===============================================
//
// Purpose:		Sets the current granularity of the positioning grid being used 
//				in this document. 
//
//==============================================================================
- (void) setGridSpacingMode:(gridSpacingModeT)newMode
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer setGridSpacing:[BricksmithUtilities gridSpacingForMode:newMode]];
	
}//end setGridSpacingMode:


//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the base color for parts drawn by this view which have no 
//				color themselves.
//
//==============================================================================
-(void) setLDrawColor:(LDrawColor *)newColor
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer setLDrawColor:newColor];
	
}//end setColor


//========== LDrawDirective: ===================================================
//
// Purpose:		Sets the file being drawn in this view.
//
//				We also do other housekeeping here associated with tracking the 
//				model. We also automatically center the model in the view.
//
//==============================================================================
- (void) setLDrawDirective:(LDrawDirective *) newFile
{
	// We lock around the drawing context in case the current directive is being 
	// drawn right now. We certainly wouldn't want to release what we're 
	// drawing! 
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
		[self->renderer setLDrawDirective:newFile];
	
		[self setNeedsDisplay:YES];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end setLDrawDirective:


//========== setNeedsDisplay: ==================================================
//
// Purpose:		Request redraw. This is here for debugging to track down extra 
//				draws. 
//
//==============================================================================
- (void) setNeedsDisplay:(BOOL)flag
{
	[super setNeedsDisplay:flag];
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
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
		
		[self->renderer setProjectionMode:newProjectionMode];
		
		[self setNeedsDisplay:YES];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
	[self saveConfiguration];

} //end setProjectionMode:


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
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		//This method can get called from -prepareOpenGL, which is itself called 
		// from -makeCurrentContext. That's a recipe for infinite recursion. So, 
		// we only makeCurrentContext if we *need* to.
		if([NSOpenGLContext currentContext] != [self openGLContext])
			[[self openGLContext] makeCurrentContext];
		
		[self->renderer setViewingAngle:newAngle];
		
		[self setNeedsDisplay:YES];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end setViewingAngle:


//========== setViewOrientation: ===============================================
//
// Purpose:		Changes the camera position from which we view the model. 
//				i.e., ViewOrientationFront means we see the model head-on.
//
//==============================================================================
- (void) setViewOrientation:(ViewOrientationT)newOrientation
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer setViewOrientation:newOrientation];
		
	[self saveConfiguration];
	
}//end setViewOrientation:


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
- (void) setZoomPercentage:(CGFloat) newPercentage
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer setZoomPercentage:newPercentage];
	
}//end setZoomPercentage


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== viewOrientationSelected: ==========================================
//
// Purpose:		The user has chosen a new viewing angle from a menu.
//				sender is the menu item, whose tag is the viewing angle.
//
//==============================================================================
- (IBAction) viewOrientationSelected:(id)sender
{	
	ViewOrientationT newAngle = [sender tag];
	
	[[self openGLContext] makeCurrentContext];
	
	[self->renderer setViewOrientation:newAngle];
	
	//We treat 3D as a request for perspective, but any straight-on view can 
	// logically be expected to be displayed orthographically.
	if(newAngle == ViewOrientation3D)
		[self->renderer setProjectionMode:ProjectionModePerspective];
	else
		[self->renderer setProjectionMode:ProjectionModeOrthographic];
	
	[self saveConfiguration];

}//end viewOrientationSelected:


//========== zoomIn: ===========================================================
//
// Purpose:		Enlarge the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomIn:(id)sender
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer zoomIn:sender];
	
}//end zoomIn:


//========== zoomOut: ==========================================================
//
// Purpose:		Shrink the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomOut:(id)sender
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer zoomOut:sender];
	
}//end zoomOut:


//========== zoomToFit: ========================================================
//
// Purpose:		Enlarge or shrink the zoom and scroll the model such that its 
//				image perfectly fills the visible area of the view 
//
//==============================================================================
- (IBAction) zoomToFit:(id)sender
{
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
		[self->renderer zoomToFit:sender];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end zoomToFit:



#pragma mark -
#pragma mark EVENTS
#pragma mark -

//========== becomeFirstResponder ==============================================
//
// Purpose:		This view is to become the first responder; we need to inform 
//				the rest of the file's views about this event.
//
//==============================================================================
- (BOOL) becomeFirstResponder
{
	BOOL success = [super becomeFirstResponder];
	
	if(success == YES)
	{
		if(self->delegate != nil && [self->delegate respondsToSelector:@selector(LDrawGLViewBecameFirstResponder:)])
		{
			[self->delegate LDrawGLViewBecameFirstResponder:self];
		}
		
		//need to draw the focus ring now
		[self->focusRingView setNeedsDisplay:YES];
	}
	
	return success;
}//end becomeFirstResponder


//========== resignFirstResponder ==============================================
//
// Purpose:		We are losing key status.
//
//==============================================================================
- (BOOL) resignFirstResponder
{
	BOOL success = [super resignFirstResponder];
	
	if(success == YES)
	{
		//need to lose the focus ring
		[self->focusRingView setNeedsDisplay:YES];
	}
	
	return success;
	
}//end resignFirstResponder


//========== resetCursor =======================================================
//
// Purpose:		Force a mouse-cursor update. We call this whenever a significant 
//				event occurs, such as a click or keypress.
//
//==============================================================================
- (void) resetCursor
{	
	//It seems -invalidateCursorRectsForView: only causes -resetCursorRects to 
	// get called if there is currently a cursor in force. So we oblige it.
	[self addCursorRect:[self visibleRect] cursor:[NSCursor arrowCursor]];
	
	[[self window] invalidateCursorRectsForView:self];	
	
}//end resetCursor


//========== resetCursorRects ==================================================
//
// Purpose:		Update the document cursor to reflect the current state of 
//				events.
//
//				To simplify, we set a single cursor for the entire view. 
//				Whenever the mouse enters our frame, the AppKit automatically 
//				takes care of adjusting the cursor. This method itself is called 
//				by the AppKit when necessary. We also coax it into happening 
//				more frequently by invalidating. See -resetCursor.
//
//==============================================================================
- (void) resetCursorRects
{
	[super resetCursorRects];
	
	NSRect		 visibleRect	= [self visibleRect];
	BOOL		 isClicked		= NO; /*[[NSApp currentEvent] type] == NSLeftMouseDown;*/ //not enough; overwhelmed by repeating key events
	NSCursor	*cursor			= nil;
	NSImage		*cursorImage	= nil;
	ToolModeT	 toolMode		= [ToolPalette toolMode];
	
	switch(toolMode)
	{
		case RotateSelectTool:
			//just use the standard arrow cursor.
			if(self->selectionIsMarquee)
			{
				switch(self->marqueeSelectionMode) {
				case SelectionIntersection:
					cursorImage = [NSImage imageNamed:@"CrosshairTimes"];
					break;
				case SelectionExtend:
					cursorImage = [NSImage imageNamed:@"CrosshairPlus"];
					break;
				case SelectionSubtract:
					cursorImage = [NSImage imageNamed:@"CrosshairMinus"];
					break;
				case SelectionReplace:
					cursorImage = [NSImage imageNamed:@"Crosshair"];
					break;
				}
				cursor = [[[NSCursor alloc] initWithImage:cursorImage
												  hotSpot:NSMakePoint(8, 8)] autorelease];
			}
			else			
				cursor = [NSCursor arrowCursor];
			break;
		
		case PanScrollTool:
			if([self->renderer isTrackingDrag] == YES || isClicked == YES)
				cursor = [NSCursor closedHandCursor];
			else
				cursor = [NSCursor openHandCursor];
			break;
			
		case SmoothZoomTool:
			if([self->renderer isTrackingDrag] == YES)
			{
				cursorImage = [NSImage imageNamed:@"ZoomCursor"];
				cursor = [[[NSCursor alloc] initWithImage:cursorImage
												  hotSpot:NSMakePoint(7, 10)] autorelease];
			}
			else
				cursor = [NSCursor crosshairCursor];
			break;
			
		case ZoomInTool:
			cursorImage = [NSImage imageNamed:@"ZoomInCursor"];
			cursor = [[[NSCursor alloc] initWithImage:cursorImage
											  hotSpot:NSMakePoint(7, 10)] autorelease];
			break;
			
		case ZoomOutTool:
			cursorImage = [NSImage imageNamed:@"ZoomOutCursor"];
			cursor = [[[NSCursor alloc] initWithImage:cursorImage
											  hotSpot:NSMakePoint(7, 10)] autorelease];
			break;
		
		case SpinTool:
			cursorImage = [NSImage imageNamed:@"Spin"];
			cursor = [[[NSCursor alloc] initWithImage:cursorImage
											  hotSpot:NSMakePoint(7, 10)] autorelease];
			break;
			
		case EraserTool:
			//just use the standard arrow cursor.
			cursor = [NSCursor arrowCursor];
			break;
	}
	
	//update the cursor based on the tool mode.
	if(cursor != nil)
	{
		//Make this cursor active over the entire document.
		[self addCursorRect:visibleRect cursor:cursor];
		[cursor setOnMouseEntered:YES];
		
		//okay, something very weird is going on here. When the cursor is inside 
		// a view and THE PARTS BROWSER DRAWER IS OPEN, merely establishing a 
		// cursor rect isn't enough. It's somehow instantly erased when the 
		// LDrawGLView inside the drawer redoes its own cursor rects. Even 
		// calling -set on the cursor often has little more effect than a brief 
		// flicker. I don't know why this is happening, but this hack seems to 
		// fix it.
		if([self mouse:[self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil]
				inRect:[self visibleRect] ] ) //mouse is inside view.
		{
			//[cursor set]; //not enough.
			[cursor performSelector:@selector(set) withObject:nil afterDelay:0];
		}
		
	}
		
}//end resetCursorRects


//========== worksWhenModal ====================================================
//
// Purpose:		Due to buggy or at least undocumented behavior in Cocoa, this 
//				method must be implemented in order for objects of this class to 
//				be the target of menu actions when the instance resides in a 
//				modal dialog.
//
//				This was discovered experimentally by some enterprising soul on 
//				Cocoa-dev.
//
//==============================================================================
- (BOOL) worksWhenModal
{
	return YES;
	
}//end worksWhenModal


#pragma mark -
#pragma mark Keyboard

//========== keyDown: ==========================================================
//
// Purpose:		Certain key event have editorial significance. Like arrow keys, 
//				for instance. We need to assemble a sensible move request based 
//				on the arrow key pressed.
//
//==============================================================================
- (void)keyDown:(NSEvent *)theEvent
{
	NSString		*characters	= [theEvent charactersIgnoringModifiers];
	
//		[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
	//We are circumventing the AppKit's key processing system here, because we 
	// may want to extend our keys to mean different things with different 
	// modifiers. It is easier to do that here than to pass it off to 
	// -interpretKeyEvent:. But beware of no-character keypresses like deadkeys.
	if([characters length] > 0)
	{
		unichar firstCharacter	= [characters characterAtIndex:0]; //the key pressed

		switch(firstCharacter)
		{
			//brick movements
			case NSUpArrowFunctionKey:
			case NSDownArrowFunctionKey:
			case NSLeftArrowFunctionKey:
			case NSRightArrowFunctionKey:
				[self nudgeKeyDown:theEvent];
				break;
			
			// handled by menu item
//			case NSDeleteCharacter: //regular delete character, apparently.
//			case NSDeleteFunctionKey: //forward delete--documented! My gosh!
//				[NSApp sendAction:@selector(delete:)
//							   to:nil //just send it somewhere!
//							 from:self];

//			case '\\':
//				[self setNeedsDisplay:YES];
//				break;
//
//			case 'f':
//			{
//				[[self openGLContext] makeCurrentContext];
//				glReadBuffer(GL_FRONT);
//
//				NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
//				NSString *path = [searchPaths objectAtIndex:0];
//				
//				path = [path stringByAppendingPathComponent:@"Front"];
//				path = [path stringByAppendingPathExtension:@"tiff"];
//				[self saveImageToPath:path];
//			}
//				break;
//
//			case 'b':
//			{
//				[[self openGLContext] makeCurrentContext];
//				glReadBuffer(GL_BACK);
//
//				NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
//				NSString *path = [searchPaths objectAtIndex:0];
//				
//				path = [path stringByAppendingPathComponent:@"Back"];
//				path = [path stringByAppendingPathExtension:@"tiff"];
//				[self saveImageToPath:path];
//			}
//				break;

			case ' ':
				// Swallow the spacebar, since it is a special tool-palette key. 
				// If we pass it up to super, it will cause a beep. 
				break;

			//viewing angle
			case '4':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationLeft];
				break;
			case '6':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationRight];
				break;
			case '2':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationBottom];
				break;
			case '8':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationTop];
				break;
			case '5':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationFront];
				break;
			case '7':
			case '9':
				[self setProjectionMode:ProjectionModeOrthographic];
				[self setViewOrientation:ViewOrientationBack];
				break;
			case '0':
				[self setProjectionMode:ProjectionModePerspective];
				[self setViewOrientation:ViewOrientation3D];
				break;
				
			default:
				[super keyDown:theEvent];
				break;
		}
		
	}

}//end keyDown:


//========== nudgeKeyDown: =====================================================
//
// Purpose:		We have received a keypress intended to move bricks. We need to 
//				figure out which direction to move them with respect to how the 
//				model is currently oriented.
//
//==============================================================================
- (void) nudgeKeyDown:(NSEvent *)theEvent
{
	NSString	*characters		= [theEvent characters];
	unichar		firstCharacter	= '\0';
	Vector3		xNudge			= ZeroPoint3;
	Vector3		yNudge			= ZeroPoint3;
	Vector3		zNudge			= ZeroPoint3;
	Vector3		actualNudge		= ZeroPoint3;
	BOOL		isZMovement		= NO;
	BOOL		isFastNudge		= NO;
	BOOL		isNudge			= NO;
	
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
		
		if([characters length] > 0)
		{
			firstCharacter	= [characters characterAtIndex:0]; //the key pressed
			
			if ([self projectionMode] == ProjectionModeOrthographic || !USE_TURNTABLE)
			{
				// find which model-coordinate directions our screen axes are best 
				// aligned with. 
				[self->renderer getModelAxesForViewX:&xNudge
													Y:&yNudge
													Z:&zNudge ];
			} else {

				/* 
					This view mode matches the turntable-style editing:
					The model "horizontal" axes x & z always match x & z nudge,
					but which one is X and which way they go match screen space
					for sanity.
					Up-down is ALWAYS y, with a reverse if you (insanely) flip
					the model's pitch by > 90 degrees.
					Since the Y axis is always Y, there is never any question 
					whether we'll be pulling depth or height.
					Finally: the model's Z or X axis is aligned with screen space
					Y so that if we are looking DOWN on a model and we pull a brick
					toward us, it moves down, which matches what we'd expect.  In
					other words, the depth perspective matches screen space.
				*/

				Matrix4 matrix = [self->renderer getMatrix];
				Vector4 x_model = { 1, 0, 0 };
				Vector4 y_model = { 0, 1, 0 };
				Vector4 z_model = { 0, 0, 1 };
				
				Vector4 x_screen = V4MulPointByMatrix(x_model, matrix);
				Vector4 y_screen = V4MulPointByMatrix(y_model, matrix);
				Vector4 z_screen = V4MulPointByMatrix(z_model, matrix);
				
				if(fabsf(x_screen.x) > fabsf(z_screen.x))
				{
					xNudge.x = (x_screen.x > 0.0f) ? 1.0f : -1.0f;
					yNudge.y = (y_screen.y > 0.0f) ? 1.0f : -1.0f;
					zNudge.z = (z_screen.y > 0.0f) ? -1.0f : 1.0f;
				}
				else 
				{
					xNudge.z = (z_screen.x > 0.0f) ? 1.0f : -1.0f;
					yNudge.y = (y_screen.y > 0.0f) ? 1.0f : -1.0f;
					zNudge.x = (x_screen.y < 0.0f) ? 1.0f : -1.0f;
				}
			}
							
			// By holding down the option key, we transcend the two-plane 
			// limitation presented by the arrow keys. Option-presses mean 
			// movement along the z-axis. Note that move "in" to the screen (up 
			// arrow, left arrow?) is a movement along the screen's negative 
			// z-axis. 
			isZMovement	= ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
			isFastNudge = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;
			isNudge		= NO;
			
			
			//now we must select which axis we actually are nudging on.
			switch(firstCharacter)
			{
				case NSUpArrowFunctionKey:
				
					if(isZMovement == YES)
					{
						//into the screen (-z)
						actualNudge = V3Negate(zNudge);
					}
					else
						actualNudge = yNudge;
					isNudge = YES;
					break;
					
				case NSDownArrowFunctionKey:
				
					if(isZMovement == YES)
						actualNudge = zNudge;
					else
					{
						actualNudge = V3Negate(yNudge);
					}
					isNudge = YES;
					break;
					
				case NSLeftArrowFunctionKey:
				
					if(isZMovement == YES)
					{
						//this is iffy at best
						// -- and it made things go the wrong way in default 3D 
						// perspective view, so I switched signs.
//						actualNudge = V3Negate(zNudge);
						actualNudge = zNudge;
					}
					else
					{
						actualNudge = V3Negate(xNudge);
					}
					isNudge = YES;
					break;
					
				case NSRightArrowFunctionKey:
				
					if(isZMovement == YES)
					{
//						actualNudge = zNudge;
						actualNudge = V3Negate(zNudge);
					}
					else
						actualNudge = xNudge;
					isNudge = YES;
					break;
					
				default:
					break;
			}
			
			//Pass the nudge along to the document, which is the one actually in 
			// charge of manipulating the data.
			if(isNudge == YES)
			{
				if(isFastNudge)
					actualNudge = V3Scale(actualNudge,10.0);
				self->nudgeVector = actualNudge;
				[NSApp sendAction:self->nudgeAction to:self->target from:self];
				self->nudgeVector = ZeroPoint3;
			}
		}
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end nudgeKeyDown:


#pragma mark -
#pragma mark Mouse

//========== mouseMoved: =======================================================
//
// Purpose:		Mouse is hovering in the view.
//
//==============================================================================
- (void) mouseMoved:(NSEvent *)theEvent
{
	NSPoint     windowClickedPoint  = [theEvent locationInWindow];
	NSPoint     viewClickedPoint    = [self convertPoint:windowClickedPoint fromView:nil ];
	Point2      view_point          = V2Make(viewClickedPoint.x, viewClickedPoint.y);
	
	[[self openGLContext] makeCurrentContext];
	
	[self->renderer mouseMoved:view_point];
}


//========== mouseExited: ======================================================
//
// Purpose:		Mouse left the view.
//
//==============================================================================
- (void) mouseExited:(NSEvent *)theEvent
{
	if([self->delegate respondsToSelector:@selector(LDrawGLViewMouseNotPositioning:)])
	{
		[self->delegate LDrawGLViewMouseNotPositioning:self];
	}
}

//========== mouseDown: ========================================================
//
// Purpose:		We received a mouseDown before a mouseDragged. Handy thought.
//
//==============================================================================
- (void) mouseDown:(NSEvent *)theEvent
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	MouseDragBehaviorT	 draggingBehavior	= [userDefaults integerForKey:MOUSE_DRAGGING_BEHAVIOR_KEY];
	ToolModeT			 toolMode			= [ToolPalette toolMode];
	
	if([theEvent buttonNumber] == 1)
		toolMode = SpinTool;
	
	[[self openGLContext] makeCurrentContext];

	// Reset event tracking flags.

	selectionIsMarquee = NO;
	marqueeSelectionMode = SelectionReplace;

	[self->renderer mouseDown];
	
	[self resetCursor];
	
	if(toolMode == SmoothZoomTool)
	{
		NSPoint windowClickedPoint  = [theEvent locationInWindow]; //window coordinates
		NSPoint	viewClickedPoint	= [self convertPoint:windowClickedPoint fromView:nil ];

		[self->renderer mouseCenterClick:V2Make(viewClickedPoint.x, viewClickedPoint.y)];
	}	
	else if( toolMode == EraserTool )
	{
		[self mousePartSelection:theEvent];
		
		// Request delete using the standard responder message. Hopefully 
		// someone out there will listen. 
		[NSApp sendAction:@selector(delete:)
					   to:nil
					 from:self];
	}	
	else if(toolMode == RotateSelectTool)
	{
		switch(draggingBehavior)
		{
			case MouseDraggingOff:					
				// No-op.  During a drag we'll actually start the marquee
				break;
			
			case MouseDraggingBeginAfterDelay:
				[self cancelClickAndHoldTimer]; // just in case
				
				// Try waiting for a click-and-hold; that means "begin 
				// drag-and-drop" 
				self->mouseDownTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
																		target:self
																	  selector:@selector(clickAndHoldTimerFired:)
																	  userInfo:theEvent
																	   repeats:NO ];
				break;			
			
			case MouseDraggingBeginImmediately:
				[self mousePartSelection:theEvent];
				break;
			
			case MouseDraggingImmediatelyInOrthoNeverInPerspective:
				if([self->renderer projectionMode] == ProjectionModeOrthographic)
				{
					[self mousePartSelection:theEvent];
				}
				break;
		}
	
	}
	
}//end mouseDown:


//========== mouseDragged: =====================================================
//
// Purpose:		The user has dragged the mouse after clicking it.
//
//==============================================================================
- (void) mouseDragged:(NSEvent *)theEvent
{
	NSUserDefaults      *userDefaults       = [NSUserDefaults standardUserDefaults];
	MouseDragBehaviorT  draggingBehavior    = [userDefaults integerForKey:MOUSE_DRAGGING_BEHAVIOR_KEY];
	ToolModeT           toolMode            = [ToolPalette toolMode];
	Vector2             dragDelta           = V2Make([theEvent deltaX], [theEvent deltaY]);

	if([theEvent buttonNumber] == 1)
		toolMode = SpinTool;
	
	[[self openGLContext] makeCurrentContext];

	[self->renderer mouseDragged];
	[self resetCursor];
	
	//What to do?
	
	if(toolMode == PanScrollTool)
	{
		NSPoint point_window	= [theEvent locationInWindow];
		NSPoint point_view		= [self convertPoint:point_window fromView:nil ];
		
		[self->renderer panDragged:dragDelta location:V2Make(point_view.x, point_view.y)];
	}
	else if(toolMode == SpinTool)
	{
		[self->renderer rotationDragged:dragDelta];
	}
	else if(toolMode == SmoothZoomTool)
	{
		[self->renderer zoomDragged:dragDelta];
	}
	else if(toolMode == RotateSelectTool)
	{
		switch(draggingBehavior)
		{
			case MouseDraggingOff:
				[self->renderer rotationDragged:dragDelta];
				break;
				
			case MouseDraggingBeginAfterDelay:
				// If the delay has elapsed, begin drag-and-drop. Otherwise, 
				// just spin the model. 
				if(self->canBeginDragAndDrop == YES)
					[self directInteractionDragged:theEvent];
				else			
					[self->renderer rotationDragged:dragDelta];
				break;			
				
			case MouseDraggingBeginImmediately:
				if (selectionIsMarquee)
				{
					[self autoscroll:theEvent];
					[self mousePartSelection:theEvent];				
				}
				else
					[self directInteractionDragged:theEvent];
				break;
				
			case MouseDraggingImmediatelyInOrthoNeverInPerspective:
				if([self->renderer projectionMode] == ProjectionModePerspective)
					[self->renderer rotationDragged:dragDelta];
				else {
					if (selectionIsMarquee)
					{
						[self autoscroll:theEvent];
						[self mousePartSelection:theEvent];				
					}
					else
						[self directInteractionDragged:theEvent				];
				}
				break;
		}
	}
	
	// Don't wait for drag-and-drop anymore. We need to do this after we process 
	// the drag, because it clears the can-drag flag. 
	[self cancelClickAndHoldTimer];
	
}//end mouseDragged


//========== mouseUp: ==========================================================
//
// Purpose:		The mouse has been released. Figure out exactly what that means 
//				in the wider context of what the mouse did before now.
//
//==============================================================================
- (void) mouseUp:(NSEvent *)theEvent
{
	ToolModeT			 toolMode			= [ToolPalette toolMode];
	if([theEvent buttonNumber] == 1)
		toolMode = SpinTool;

	[[self openGLContext] makeCurrentContext];
	
	[self cancelClickAndHoldTimer];

	if( toolMode == RotateSelectTool )
	{
		//We only want to select a part if this was NOT part of a mouseDrag event.
		// Otherwise, the selection should remain intact.
		if(		[self->renderer isTrackingDrag] == NO
		   &&	[self->renderer didPartSelection] == NO )
		{
			[self mousePartSelection:theEvent];
		}
	}
	else if(	toolMode == ZoomInTool
			||	toolMode == ZoomOutTool )
	{
		[self mouseZoomClick:theEvent];
	}
	
	[self->renderer mouseUp];
	[self resetCursor];

	selectionIsMarquee = NO;
	marqueeSelectionMode = SelectionReplace;

	if(self->autoscrollTimer)
	{
		[self->autoscrollTimer invalidate];
		self->autoscrollTimer = nil;
	}
		
}//end mouseUp:


//========== rightMouseDown: ===================================================
//
// Purpose:		Secondary mouse button clicked.
//
// Notes:		Control-click does not come through here.
//
//==============================================================================
- (void) rightMouseDown:(NSEvent *)theEvent
{
	if(!USE_RIGHT_SPIN)
	{
		[super rightMouseDown:theEvent];
	}
	else
	{
		[[self openGLContext] makeCurrentContext];
		[self->renderer mouseDown];
	}

}


//========== rightMouseDragged: ================================================
//
// Purpose:		Secondary mouse button dragged.
//
//==============================================================================
- (void) rightMouseDragged:(NSEvent *)theEvent
{
	if(!USE_RIGHT_SPIN)
		[super rightMouseDragged:theEvent];
	else
	{
		Vector2	dragDelta	= V2Make([theEvent deltaX], [theEvent deltaY]);
		
		[[self openGLContext] makeCurrentContext];
		
		[self->renderer mouseDragged];
		[self->renderer rotationDragged:dragDelta];
	}
}


//========== rightMouseUp: =====================================================
//
// Purpose:		Secondary mouse button released.
//
//==============================================================================
- (void) rightMouseUp:(NSEvent *)theEvent
{
	if(!USE_RIGHT_SPIN)
	{
		[super rightMouseUp:theEvent];
	}
	else
	{
		[[self openGLContext] makeCurrentContext];
		[self->renderer mouseUp];
	}
}


//========== menuForEvent: =====================================================
//
// Purpose:		Customize the contextual menu for the given mouse-down event. 
//
//				Calls to this method are filtered by the events the system 
//				considers acceptible for invoking a contextual menu; namely, 
//				right-clicks and control-clicks. 
//
//==============================================================================
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
	NSUInteger modifiers = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
	
	// Only display contextual menus for pure control- or right-clicks. By 
	// default, the system permits control+<any other modifiers> to trigger 
	// contextual menus. We want to use control/modifier combos to activate 
	// other mouse tools, so we filter out those events. 
	if(		modifiers == NSControlKeyMask // and nothing else!
	   ||	[theEvent type] == NSRightMouseDown )
		return [self menu];
	else
		return nil;
		
}//end menuForEvent:


//========== otherMouseDown: ===================================================
//
// Purpose:		A mouse button other than left or right was clicked. My, the 
//				things Mighty Mice make possible. 
//
//				We use the middle mouse button as a more convenient way to 
//				activate the spin tool. 
//
//==============================================================================
- (void) otherMouseDown:(NSEvent *)theEvent
{
	// button 3
	if([theEvent buttonNumber] == 2)
	{
		// The Tool Palette is responsible for assessing the current mode based 
		// on event state. 
		[[ToolPalette sharedToolPalette] mouseButton3DidChange:theEvent];
		
		[self mouseDown:theEvent];
	}
	
}//end otherMouseDown:


//========== otherMouseDragged: ================================================
//
// Purpose:		A mouse button other than left or right was dragged. My, the 
//				things Mighty Mice make possible.
//
//==============================================================================
- (void) otherMouseDragged:(NSEvent *)theEvent
{
	// button 3
	if([theEvent buttonNumber] == 2)
	{
		// our mouseDragged method will do the right thing based on tool mode
		[self mouseDragged:theEvent];
	}

}//end otherMouseDragged:


//========== otherMouseUp: =====================================================
//
// Purpose:		Third or higher mouse button released.
//
//==============================================================================
- (void) otherMouseUp:(NSEvent *)theEvent
{
	// button 3
	if([theEvent buttonNumber] == 2)
	{
		// reset normal state while the tool mode is still SpinTool
		[self mouseUp:theEvent];
		
		// The Tool Palette is responsible for assessing the current mode based on 
		// event state. 
		[[ToolPalette sharedToolPalette] mouseButton3DidChange:theEvent];
	}

}//end otherMouseUp:


//========== scrollWheel: ======================================================
//
// Purpose:		Scrolling. We intercept option-scroll to zoom.
//
//==============================================================================
- (void)scrollWheel:(NSEvent *)theEvent
{
	NSUInteger modifiers = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;

	if(modifiers == NSAlternateKeyMask || USE_ZOOM_WHEEL)
	{
		// Zoom in
		[[self openGLContext] makeCurrentContext];
		
		NSPoint windowPoint     = [theEvent locationInWindow];
		NSPoint viewPoint       = [self convertPoint:windowPoint fromView:nil];
		CGFloat magnification   = [theEvent deltaY] / 20; // 1 = increase 100%; -1 = decrease 100%
		CGFloat zoomChange      = 1.0 + magnification;
		CGFloat currentZoom     = [self->renderer zoomPercentage];
		
		// Negative means down
		[self->renderer setZoomPercentage:(currentZoom * zoomChange)
							preservePoint:V2Make(viewPoint.x, viewPoint.y)];
	}
	else
	{
		// Regular scrolling
		[super scrollWheel:theEvent];
	}
}

#pragma mark - Dragging

//========== directInteractionDragged: =========================================
//
// Purpose:		This is a mouseDragged intended to directly modify onscreen 
//				objects, by moving, deforming, or transforming them. 
//
//==============================================================================
- (void) directInteractionDragged:(NSEvent *)theEvent
{
	if([self->renderer activeDragHandle])
	{
		// move drag handle
		[self dragHandleDragged:theEvent];
	}
	else
	{
		[self dragAndDropDragged:theEvent];
	}

}//end directInteractionDragged:


//========== dragAndDropDragged: ===============================================
//
// Purpose:		This is a special mouseDragged which means to begin a Mac OS 
//				drag-and-drop operation. The originating drag dies here; once we 
//				start drag-and-drop, the OS machinery takes over and we don't 
//				track mouseDraggeds anymore. 
//
//==============================================================================
- (void) dragAndDropDragged:(NSEvent *)theEvent
{
	NSPasteboard			*pasteboard			= nil;
	NSPoint					 imageLocation		= NSZeroPoint;
	BOOL					 beginCopy			= NO;
	BOOL					 okayToDrag			= NO;
	NSPoint					 offset				= NSZeroPoint;
	NSArray					*archivedDirectives	= nil;
	NSData					*data				= nil;
	LDrawDrawableElement	*firstDirective		= nil;
	NSPoint					 viewPoint			= [self convertPoint:[theEvent locationInWindow] fromView:nil];
	Point3					 modelPoint			= ZeroPoint3;
	Point3					 firstPosition		= ZeroPoint3;
	Vector3					 displacement		= ZeroPoint3;
	NSImage					*dragImage			= nil;

	if(		self->delegate != nil
	   &&	[self->delegate respondsToSelector:@selector(LDrawGLView:writeDirectivesToPasteboard:asCopy:)] )
	{
		pasteboard		= [NSPasteboard pasteboardWithName:NSDragPboard];
		beginCopy		= ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
	
		okayToDrag		= [self->delegate LDrawGLView:self writeDirectivesToPasteboard:pasteboard asCopy:beginCopy];
		
		[[self openGLContext] makeCurrentContext];

		if(okayToDrag == YES)
		{
			//---------- Find drag displacement --------------------------------
			//
			// When a drag enters a view, the first part's position is normally 
			// set to the model point under the mouse. But that is incorrect 
			// behavior when entering the originating view. The user almost 
			// certainly did not click the mouse at the exact center of part 0, 
			// but nevertheless he does not expect part 0 of his selection to 
			// suddenly become centered under the mouse after dragging only one 
			// pixel.
			//
			// Instead we record the offset of his actual originating 
			// click against the position of part 0. Now when this drag reenters 
			// its originating view, its position will be adjusted by that 
			// offset. Everything will come out looking right. 
			//
			archivedDirectives	= [pasteboard propertyListForType:LDrawDraggingPboardType];
			data				= [archivedDirectives objectAtIndex:0];
			firstDirective		= [NSKeyedUnarchiver unarchiveObjectWithData:data];
			firstPosition		= [firstDirective position];
			modelPoint			= [self->renderer modelPointForPoint:V2Make(viewPoint.x, viewPoint.y) depthReferencePoint:firstPosition];
			displacement		= V3Sub(modelPoint, firstPosition);
			
			// write displacement to private pasteboard.
			[pasteboard addTypes:[NSArray arrayWithObject:LDrawDraggingInitialOffsetPboardType] owner:self];
			[pasteboard setData:[NSData dataWithBytes:&displacement length:sizeof(Vector3)]
						forType:LDrawDraggingInitialOffsetPboardType];
			
			
			//---------- Reset event tracking flags ----------------------------

			[self->renderer setDraggingOffset:displacement];
			
			// reset drop destination flag.
			[self setDragEndedInOurDocument:NO];
			
			// Once we give control to drag-and-drop, we no longer receive 
			// mouseDragged events. 
//			self->isTrackingDrag = NO;
			[self->renderer mouseUp]; // this is hacky. It makes sure the isTrackingDrag flag is NO.
			
			
			//---------- Start drag-and-drop ----------------------------------

			imageLocation	= viewPoint;
			dragImage		= [BricksmithUtilities dragImageWithOffset:&offset];
			
			// Offset the image location so that the drag image appears to the 
			// lower-right of the arrow like a dragging badge. 
			imageLocation.x +=  offset.x;
			imageLocation.y += -offset.y; // Invert y because this view is flipped.
			
			// Initiate Drag.
			[self dragImage:dragImage
						 at:imageLocation
					 offset:NSZeroSize
					  event:theEvent
				 pasteboard:pasteboard
					 source:self
				  slideBack:NO ];
			
			// **** -dragImage: BLOCKS until drag is complete. ****
		}
	}

}//end dragAndDropDragged:


//========== dragHandleDragged: ================================================
//
// Purpose:		Move the active drag handle
//
//==============================================================================
- (void) dragHandleDragged:(NSEvent *)theEvent
{
	NSPoint dragPointInWindow	= [theEvent locationInWindow];
	NSPoint viewPoint			= [self convertPoint:dragPointInWindow fromView:nil];
	BOOL	constrainDragAxis	= NO;

	constrainDragAxis   = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;
	
	[[self openGLContext] makeCurrentContext];

	[self->renderer dragHandleDraggedToPoint:V2Make(viewPoint.x, viewPoint.y)
						   constrainDragAxis:constrainDragAxis];

}//end dragHandleDragged:


#pragma mark - Clicking

//========== mousePartSelection: ===============================================
//
// Purpose:		This routine handles clicks and drags for the purpose of 
//				selection.  it is called in an odd pattern:
//				
//				It is _always_ called on mouse-down, whether this is a marquee
//				drag or selection click.  This is true because we have ot click
//				once (and hit test) to even know if we hit an obj or will marquee.
//
//				It is _only_ called during drag if it is a marquee drag.  If we
//				hit a part before, client code will call directInteractionDragged
//				instead to move the part around.
//
//==============================================================================
- (void) mousePartSelection:(NSEvent *)theEvent
{
	NSPoint windowPoint     = [theEvent locationInWindow];
	NSPoint viewPoint       = [self convertPoint:windowPoint fromView:nil];
	SelectionModeT selectionMode;
	
	[[self openGLContext] makeCurrentContext];
		
	if([theEvent type] == NSLeftMouseDragged)
	{

		[self->renderer mouseSelectionDragToPoint:V2Make(viewPoint.x, viewPoint.y)
								  selectionMode:marqueeSelectionMode];
							
		[self setNeedsDisplay:YES];
	}
	else
	{
	
	// Per the AHIG, both command and shift are used for multiple selection. In 
	// Bricksmith, there is no difference between contiguous and non-contiguous 
	// selection, so both keys do the same thing. 
	// -- We desperately need simple modifiers for rotating the view. Otherwise, 
	// I doubt people would discover it. 

	if (([theEvent modifierFlags] & NSShiftKeyMask) != 0)
	{
		if(([theEvent modifierFlags] & NSAlternateKeyMask) != 0)
			selectionMode = SelectionIntersection;
		else
			selectionMode = SelectionExtend;			
	}
	else 
	{
		if(([theEvent modifierFlags] & NSAlternateKeyMask) != 0)
			selectionMode = SelectionSubtract;		
		else
			selectionMode = SelectionReplace;
	}

		// This click is a click down to see what we hit - record whether we hit something so
		// we can then marquee or drag and drop.
		selectionIsMarquee = ![self->renderer mouseSelectionClick:V2Make(viewPoint.x, viewPoint.y)
												  selectionMode:selectionMode]
						&& [self->delegate respondsToSelector:@selector(markPreviousSelection)];
		if(selectionIsMarquee)
		{
			// We are starting a marquee select.  We can do this because our part selection is known to have missed
			// a part and thus is a click in free space.  Start a timer to fire...if the user parks the mouse in the auto
			// scroll zone this will continuously scroll.  I do _not_ know what the correct scrolling interval should be...
			// auto-scroll seems jerky.
			self->marqueeSelectionMode = selectionMode;
			self->autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
																		target:self
																	  selector:@selector(autoscrollTimerFired:)
																	  userInfo:self
																	   repeats:YES ];
		}
	}
}//end mousePartSelection:


//========== mouseZoomClick: ===================================================
//
// Purpose:		Depending on the tool mode, we want to zoom in or out. We also 
//				want to center the view on whatever we clicked on.
//
//==============================================================================
- (void) mouseZoomClick:(NSEvent*)theEvent
{
	ToolModeT   toolMode            = [ToolPalette toolMode];
	NSPoint     windowClickedPoint  = [theEvent locationInWindow];
	NSPoint     viewClickedPoint    = [self convertPoint:windowClickedPoint fromView:nil ];
	Point2      view_point          = V2Make(viewClickedPoint.x, viewClickedPoint.y);
	
	[[self openGLContext] makeCurrentContext];

	// New zoom percentage
	if(	toolMode == ZoomInTool )
	{
		[self->renderer mouseZoomInClick:view_point];
	}
	else if( toolMode == ZoomOutTool )
	{
		[self->renderer mouseZoomOutClick:view_point];
	}
	
}//end mouseZoomClick:


#pragma mark -

//========== cancelClickAndHoldTimer ===========================================
//
// Purpose:		Something has happened which interrupts a click-and-hold, such 
//				as maybe a mouseUp. 
//
//==============================================================================
- (void) cancelClickAndHoldTimer
{
	if(self->mouseDownTimer != nil)
	{
		[self->mouseDownTimer invalidate];
		self->mouseDownTimer = nil;
	}
	self->canBeginDragAndDrop	= NO;
	
}//end cancelClickAndHoldTimer


//========== autoscrollTimerFired: ===========================================
//
// Purpose:		If we got here, it means the user has successfully executed a 
//				click-and-hold, which means that the mouse button was clicked, 
//				held down, and not moved for a certain period of time. 
//
//				We use this action to initiate a drag-and-drop.
//
//==============================================================================
- (void) autoscrollTimerFired:(NSTimer*)theTimer
{
	NSView * view = self;
	NSEvent * event = [NSApp currentEvent];
	if ([event type] == NSLeftMouseDragged )
		[view autoscroll:event];
}



//========== clickAndHoldTimerFired: ===========================================
//
// Purpose:		If we got here, it means the user has successfully executed a 
//				click-and-hold, which means that the mouse button was clicked, 
//				held down, and not moved for a certain period of time. 
//
//				We use this action to initiate a drag-and-drop.
//
//==============================================================================
- (void) clickAndHoldTimerFired:(NSTimer*)theTimer
{
	NSEvent	*clickEvent	= [theTimer userInfo];

	// the timer has expired; nil it out so nobody tries to message it after 
	// it's been released. 
	self->mouseDownTimer = nil;
	
	[self mousePartSelection:clickEvent];
	
	// Actual Mac Drag-and-Drop can only be initiated upon a mouseDown or 
	// mouseDragged. So we wait until one of those actually happens to do 
	// anything, and set this flag to tell us what to do when the moment comes.
	self->canBeginDragAndDrop	= YES;
	
}//end clickAndHoldTimerFired:


#pragma mark -
#pragma mark Gestures

//========== beginGestureWithEvent: ============================================
//
// Purpose:		A multitouch trackpad gesture has begun. (Scrolling counts.)
//
//==============================================================================
- (void) beginGestureWithEvent:(NSEvent *)theEvent
{
	[[self openGLContext] makeCurrentContext];
	self->startingGestureType = [theEvent type];
	[self->renderer beginGesture];
	
}//end beginGestureWithEvent:


//========== endGestureWithEvent: ==============================================
//
// Purpose:		A multitouch trackpad gesture has ended.
//
//==============================================================================
- (void) endGestureWithEvent:(NSEvent *)theEvent
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer endGesture];
	
}//end endGestureWithEvent:


//========== magnifyWithEvent: =================================================
//
// Purpose:		User is doing the pinch (zoom) trackpad gesture.
//
//==============================================================================
- (void) magnifyWithEvent:(NSEvent *)theEvent
{
	[[self openGLContext] makeCurrentContext];
	
	NSPoint windowPoint     = [theEvent locationInWindow];
	NSPoint viewPoint       = [self convertPoint:windowPoint fromView:nil];
	CGFloat magnification   = [theEvent magnification]; // 1 = increase 100%; -1 = decrease 100%
	CGFloat zoomChange      = 1.0 + magnification;
	CGFloat currentZoom     = [self->renderer zoomPercentage];
	
	//Negative means down
	[self->renderer setZoomPercentage:(currentZoom * zoomChange)
						preservePoint:V2Make(viewPoint.x, viewPoint.y)];

}//end magnifyWithEvent:


//========== rotateWithEvent: ==================================================
//
// Purpose:		User is doing the twist (rotate) trackpad gesture.
//
//				I have decided to interpret this as spinning the "baseplate" 
//				plane of the model (that is, spinning around -y). 
//
//==============================================================================
- (void) rotateWithEvent:(NSEvent *)theEvent
{
	CGFloat	angle = [theEvent rotation]; // degrees counterclockwise
	
	// Do not allow rotating in orthographic views if we started out doing a 
	// zoom gesture. Rotating will automatically change an orthographic view to 
	// perspective, and we don't want to do that when unexpected. 
	if(		[self->renderer projectionMode] == ProjectionModePerspective
	   ||	self->startingGestureType == NSEventTypeRotate )
	{
		CGLLockContext([[self openGLContext] CGLContextObj]);
		{
			[[self openGLContext] makeCurrentContext];
			
			[self->renderer rotateByDegrees:angle];
			[self setNeedsDisplay: YES];
		}
		CGLUnlockContext([[self openGLContext] CGLContextObj]);
	}
	
}//end rotateWithEvent:


//========== swipeWithEvent: ===================================================
//
// Purpose:		User is doing the three-finger swipe (forward and back) trackpad 
//				gesture. 
//
//==============================================================================
- (void) swipeWithEvent:(NSEvent *)theEvent
{
	CGFloat horizontalDirection = [theEvent deltaX];
	
	if(horizontalDirection == 0)
	{
		// vertical swipe; we don't recognize them.
	}
	else if(horizontalDirection < 0)
	{
		// forward
		// On the MacBook Air (1st generation), -1 means forward. That seems 
		// wrong and contradictory to a certain release note *ahem*; I guess I'm 
		// going with actual behavior right now. 
		[NSApp sendAction:self->forwardAction to:self->target from:self];
	}
	else
	{
		// back
		[NSApp sendAction:self->backAction to:self->target from:self];
	}
	
}//end swipeWithEvent:


#pragma mark -
#pragma mark DRAG AND DROP
#pragma mark -

//========== draggingEntered: ==================================================
//
// Purpose:		A drag-and-drop part operation entered this view. We need to 
//			    initiate interactive dragging. 
//
//==============================================================================
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)info
{
	[[self openGLContext] makeCurrentContext];

	NSPasteboard			*pasteboard 		= [info draggingPasteboard];
	id						sourceView			= [info draggingSource];
	NSDragOperation 		dragOperation		= NSDragOperationNone;
	BOOL					setTransform		= NO;
	NSArray 				*archivedDirectives = nil;
	NSMutableArray			*directives 		= nil;
	NSData					*data				= nil;
	id						currentObject		= nil;
	NSUInteger				directiveCount		= 0;
	NSUInteger				counter 			= 0;
	NSPoint 				dragPointInWindow	= [info draggingLocation];
	NSPoint 				viewPoint			= [self convertPoint:dragPointInWindow fromView:nil];
	
	// local drag?
	if(sourceView == self)
		dragOperation = NSDragOperationMove;
	else
		dragOperation = NSDragOperationCopy;
	
	
	//---------- unarchive the directives --------------------------------------
	
	archivedDirectives	= [pasteboard propertyListForType:LDrawDraggingPboardType];
	directiveCount		= [archivedDirectives count];
	directives			= [NSMutableArray arrayWithCapacity:directiveCount];
	
	for(counter = 0; counter < directiveCount; counter++)
	{
		data			= [archivedDirectives objectAtIndex:counter];
		currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		// while a part is dragged, it is drawn selected
		[currentObject setSelected:YES];
		
		[directives addObject:currentObject];
	}
	
	if([[pasteboard propertyListForType:LDrawDraggingIsUninitializedPboardType] boolValue] == YES)
	{
		setTransform = YES;
	}

	//---------- Find Location -------------------------------------------------
	
	[self->renderer draggingEnteredAtPoint:V2Make(viewPoint.x, viewPoint.y)
								directives:directives
							  setTransform:setTransform
						 originatedLocally:(sourceView == self)];
						 
	return dragOperation;
	
}//end draggingEntered:


//========== draggingUpdated: ==================================================
//
// Purpose:		As the mouse moves around the screen, we need to update the 
//			    location of the parts being drug. 
//
//==============================================================================
- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)info
{
	[[self openGLContext] makeCurrentContext];

	id				sourceView			= [info draggingSource];
	NSPoint 		dragPointInWindow	= [info draggingLocation];
	NSPoint 		viewPoint			= [self convertPoint:dragPointInWindow fromView:nil];
	BOOL			constrainDragAxis	= NO;
	NSDragOperation dragOperation		= NSDragOperationNone;
	
	// local drag?
	if(sourceView == self)
		dragOperation = NSDragOperationMove;
	else
		dragOperation = NSDragOperationCopy;
	
	// If the shift key is down, only allow dragging along one axis as is 
	// conventional in graphics programs. Cocoa gives us no way to get at 
	// the event that initiated this call, so we have to hack. 
	constrainDragAxis = ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) != 0;
	
	[self->renderer updateDragWithPosition:V2Make(viewPoint.x, viewPoint.y)
							 constrainAxis:constrainDragAxis];

	return dragOperation;
	
}//end draggingUpdated:


//========== draggingExited: ===================================================
//
// Purpose:		The drag has left the building.
//
//==============================================================================
- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[self concludeDragOperation:sender];

}//end draggingExited:


//========== performDragOperation: =============================================
//
// Purpose:		Okay, we're done. It's time to import the directives which are 
//			    on the dragging pasteboard into the model itself. 
//
// Notes:		Fortunately, we have already unpacked all the directives when 
//			    dragging first entered the view, so all we need to do is move 
//			    those directives from the file's drag list and dump them in the 
//			    main model. 
//
//==============================================================================
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	[[self openGLContext] makeCurrentContext];
	
	id				file				= [self->renderer LDrawDirective];
	NSArray 		*directives 		= nil;
	LDrawGLView 	*senderView 		= nil;
	LDrawDirective	*senderDirective	= nil;
	
	if([file respondsToSelector:@selector(draggingDirectives)])
	{
		directives = [file draggingDirectives];
		
		if([self->delegate respondsToSelector:@selector(LDrawGLView:acceptDrop:directives:)])
		   [self->delegate LDrawGLView:self acceptDrop:sender directives:directives];
	}
	
	if([[sender draggingSource] respondsToSelector:@selector(LDrawDirective)])
	{
		senderView      = [sender draggingSource];
		senderDirective = [senderView LDrawDirective];
		
		if(senderDirective == [self LDrawDirective])
			[senderView setDragEndedInOurDocument:YES];
	}
	
	return YES;
	
}//end performDragOperation:


//========== concludeDragOperation: ============================================
//
// Purpose:		The drag is accepted, imported, and over with. Clean up the 
//			    display to remove the dragging directives from the display.
//
//==============================================================================
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[[self openGLContext] makeCurrentContext];
	
	[self->renderer endDragging];

}//end concludeDragOperation:


//========== draggedImage:endedAt:operation: ===================================
//
// Purpose:		The drag ended somewhere. Maybe it was here, maybe it wasn't.
//
//				If it ended in some other file, we need to instruct our delegate 
//				to actually delete the dragged directives. When they are written 
//				to the pasteboard, they are only hidden so that they can be 
//				modified when the drag ends. 
//
//==============================================================================
- (void)draggedImage:(NSImage *)anImage
			 endedAt:(NSPoint)aPoint
		   operation:(NSDragOperation)operation
{
	if([self->delegate respondsToSelector:@selector(LDrawGLViewPartDragEnded:)])
	{
		[self->delegate LDrawGLViewPartDragEnded:self];
	}
	
	// If the drag didn't wind up in one of the GL views belonging to this 
	// document, then we need to delete the part's ghost from our model.
	if(self->dragEndedInOurDocument == NO)
	{
		if([self->delegate respondsToSelector:@selector(LDrawGLViewPartsWereDraggedIntoOblivion:)])
			[self->delegate LDrawGLViewPartsWereDraggedIntoOblivion:self];
	}
	
	// When nobody else received the drag and nobody cares, the part is just 
	// deleted and is gone forever. We bring the solemnity of this sad and 
	// otherwise obscure passing to the user's attention by running that cute 
	// little poof animation. 
	if(		operation == NSDragOperationNone
	   &&	[self->delegate respondsToSelector:@selector(LDrawGLViewPartsWereDraggedIntoOblivion:)] )
	{
		NSShowAnimationEffect (NSAnimationEffectDisappearingItemDefault,
							   aPoint, NSZeroSize, nil, NULL, NULL);
	}
}//end draggedImage:endedAt:operation:


//========== wantsPeriodicDraggingUpdates ======================================
//
// Purpose:		By default, Cocoa gives us dragging updates even when nothing 
//				updates. We don't want that. 
//
//				By refusing periodic updates, we achieve deterministic dragging 
//				behavior. Otherwise, parts can oscillate between two positions 
//				when the mouse is held exactly halfway between two grid 
//				positions. 
//
//==============================================================================
- (BOOL) wantsPeriodicDraggingUpdates
{
	return NO;

}//end wantsPeriodicDraggingUpdates


#pragma mark -
#pragma mark MENUS
#pragma mark -

//========== validateMenuItem: =================================================
//
// Purpose:		We control our own contextual menu. Since all its actions point 
//				into this class, this is where we manage the menu items.
//
//==============================================================================
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	[[self openGLContext] makeCurrentContext];
	
	// Check the appropriate item for the viewing angle. We have to check the 
	// action selector here so as not to start checking other items like zoomIn: 
	// that happen to have a tag which matches one of the viewing angles.) 
	if([menuItem action] == @selector(viewOrientationSelected:))
	{
		if([menuItem tag] == [self->renderer viewOrientation])
			[menuItem setState:NSOnState];
		else
			[menuItem setState:NSOffState];
	}
	
	return YES;
}//end validateMenuItem:


#pragma mark -
#pragma mark RENDERER DELEGATE
#pragma mark -

//========== LDrawGLRenderer:scrollToRect: =====================================
//
// Purpose:		Update the scrollbars to reflect the new visible rect computed 
//				by the renderer. 
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer scrollToRect:(Box2)scrollRect
{
	BOOL	success 	= NO;
	NSRect	nsRect		= NSMakeRect(scrollRect.origin.x, scrollRect.origin.y,
									 scrollRect.size.width, scrollRect.size.height);
	NSRect	visibleRect = [self visibleRect];
	
	if( NSEqualRects(nsRect, visibleRect) == NO ) // don't depend on this, it's often wrong
	{
		success = [self scrollRectToVisible:nsRect];
//		NSLog(@"%d", success);
	}
}


//========== LDrawGLRenderer:didSetBoundsToSize: ===============================
//
// Purpose:		Update the full size of the NSOpenGLView.
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer didSetBoundsToSize:(Size2)newBoundsSize
{
	[self setFrameSize:NSMakeSize(newBoundsSize.width, newBoundsSize.height)];
}


//========== LDrawGLRenderer:didSetZoomPercentage: =============================
//
// Purpose:		Update the scrollview to match the new rendering size.
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer didSetZoomPercentage:(CGFloat)newPercentage
{
	NSScrollView    *scrollView             = [self enclosingScrollView];
	
	// Don't zoom if we aren't cabale of zooming or if the zoom level isn't 
	// actually changing (to avoid unnecessary re-draw) 
	if(scrollView != nil)
	{
		NSClipView  *clipView       = [scrollView contentView];
		NSRect      clipFrame       = [clipView frame];
		NSRect      clipBounds      = [clipView bounds];
		CGFloat     scaleFactor     = newPercentage / 100;
		
		// Change the magnification level of the clip view, which has the 
		// effect of zooming us in and out. 
		clipBounds.size.width	= NSWidth(clipFrame)  / scaleFactor;
		clipBounds.size.height	= NSHeight(clipFrame) / scaleFactor;
		// Note: must use -setBoundsSize:, not -setBounds:. The latter 
		//		 causes bad things to happen when called on a collapsed 
		//		 split view. 
		[clipView setBoundsSize:clipBounds.size];
		
		// update KVO
		[self willChangeValueForKey:@"zoomPercentage"];
		[self didChangeValueForKey:@"zoomPercentage"];
	}
}


//========== LDrawGLRendererNeedsCurrentContext: ===============================
//
// Purpose:		While almost all calls to the renderer are initiated from this 
//				class, there is unfortunately one entry point in the renderer 
//				itself: directive-change notifications. When the renderer 
//				receives one, it will issue OpenGL calls which must be directed 
//				toward the renderer's context--which it knows nothing about. 
//
//==============================================================================
- (void) LDrawGLRendererNeedsCurrentContext:(LDrawGLRenderer *)renderer
{
	[[self openGLContext] makeCurrentContext];
}


//========== LDrawGLRendererNeedsFlush: ========================================
//
// Purpose:		Drawing is complete; do a flush.
//
// Notes:		This is implemented as a callback because flushing might be a 
//				time-sensitive operation, and we want to do the framerate 
//				calculation (in the renderer) after drawing is done. Otherwise, 
//				we'd just do it in -[LDrawOpenGLView draw]. 
//
//==============================================================================
- (void) LDrawGLRendererNeedsFlush:(LDrawGLRenderer*)renderer
{
	[[self openGLContext] flushBuffer];
}


//========== LDrawGLRendererNeedsRedisplay: ====================================
//
// Purpose:		Request a redraw.
//
//==============================================================================
- (void) LDrawGLRendererNeedsRedisplay:(LDrawGLRenderer*)renderer
{
	[self setNeedsDisplay:YES];
}

//========== LDrawGLRenderer:mouseIsOverPoint:confidence: ======================
//
// Purpose:		Reflect the mouse coordinates in the UI.
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer mouseIsOverPoint:(Point3)modelPoint confidence:(Tuple3)confidence
{
	if([self->delegate respondsToSelector:@selector(LDrawGLView:mouseIsOverPoint:confidence:)])
	{
		[self->delegate LDrawGLView:self mouseIsOverPoint:modelPoint confidence:confidence];
	}
}


//========== LDrawGLRendererMouseNotPositioning: ===============================
//
// Purpose:		The mouse is no longer reflecting coordinates.
//
//==============================================================================
- (void) LDrawGLRendererMouseNotPositioning:(LDrawGLRenderer *)renderer
{
	if([self->delegate respondsToSelector:@selector(LDrawGLViewMouseNotPositioning:)])
	{
		[self->delegate LDrawGLViewMouseNotPositioning:self];
	}
}


//========== LDrawGLRendererPreferredPartTransform: ============================
//
// Purpose:		Returns a preferred transform for new parts.
//
// Notes:		Returns the identity if we don't have a supporting delegate. Our 
//				renderer won't be aware if our delegate doesn't support this 
//				message. Double-delegate indirection is not a directly-supported 
//				feature! 
//
//==============================================================================
- (TransformComponents) LDrawGLRendererPreferredPartTransform:(LDrawGLRenderer*)renderer
{
	TransformComponents components = IdentityComponents;
	
	if([self->delegate respondsToSelector:@selector(LDrawGLViewPreferredPartTransform:)])
	{
		components = [self->delegate LDrawGLViewPreferredPartTransform:self];
	}
	
	return components;
}


//========== LDrawGLRenderer:wantsToSelectDirective:byExtendingSelection: ======
//
// Purpose:		Pass a selection notification on to our delegate.
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer
  wantsToSelectDirective:(LDrawDirective *)directiveToSelect
	byExtendingSelection:(BOOL)shouldExtend
{
	if([self->delegate respondsToSelector:@selector(LDrawGLView:wantsToSelectDirective:byExtendingSelection:)])
	{
		[self->delegate LDrawGLView:self wantsToSelectDirective:directiveToSelect byExtendingSelection:shouldExtend];
	}
}

//========== LDrawGLRenderer:wantsToSelectDirectives:selectMode ================
//
// Purpose:		Pass a multi-selection notification on to our delegate.
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer wantsToSelectDirectives:(NSArray *)directivesToSelect selectionMode:(SelectionModeT) selectionMode
{
	if([self->delegate respondsToSelector:@selector(LDrawGLView:wantsToSelectDirectives:selectionMode:)])
	{
		[self->delegate LDrawGLView:self wantsToSelectDirectives:directivesToSelect selectionMode:selectionMode];
	}
}

//========== markPreviousSelection ============================================
//
// Purpose:		Pass the start of multi-selection to our delegate.
//
//==============================================================================
- (void) markPreviousSelection:(LDrawGLRenderer*)renderer
{
	if([self->delegate respondsToSelector:@selector(markPreviousSelection)])
		[self->delegate markPreviousSelection];
}

//========== unmarkPreviousSelection ============================================
//
// Purpose:		Pass the end start of multi-selection to our delegate.
//
//==============================================================================
- (void) unmarkPreviousSelection:(LDrawGLRenderer*)renderer
{
	if([self->delegate respondsToSelector:@selector(unmarkPreviousSelection)])
		[self->delegate unmarkPreviousSelection];
}

//========== LDrawGLRenderer:willBeginDraggingHandle: ==========================
//
// Purpose:		Pass the drag-begin notification on to the operating system 
//				interface that can do something with it. 
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer
 willBeginDraggingHandle:(LDrawDragHandle *)dragHandle
{
	if([self->delegate respondsToSelector:@selector(LDrawGLView:willBeginDraggingHandle:)])
	{
		[self->delegate LDrawGLView:self willBeginDraggingHandle:dragHandle];
	}
}


//========== LDrawGLRenderer:dragHandleDidMove: ================================
//
// Purpose:		Pass the drag notification on to the operating system interface 
//				that can do something with it. 
//
//==============================================================================
- (void) LDrawGLRenderer:(LDrawGLRenderer*)renderer
	   dragHandleDidMove:(LDrawDragHandle *)dragHandle
{
	if([self->delegate respondsToSelector:@selector(LDrawGLView:dragHandleDidMove:)])
	{
		[self->delegate LDrawGLView:self dragHandleDidMove:dragHandle];
	}
}


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -


//========== backgroundColorDidChange: =========================================
//
// Purpose:		The global preference for the LDraw views' background color has 
//				been changed. We need to update our display accordingly.
//
//==============================================================================
- (void) backgroundColorDidChange:(NSNotification *)notification
{
	[self takeBackgroundColorFromUserDefaults];
	
}//end backgroundColorDidChange:


//========== mouseToolDidChange: ===============================================
//
// Purpose:		Someone (likely our file) has notified us that it has changed, 
//				and thus we need to redraw.
//
//				We also use this opportunity to grow the canvas if necessary.
//
//==============================================================================
- (void) mouseToolDidChange:(NSNotification *)notification
{
	[self resetCursor];
	
}//end mouseToolDidChange



//========== scrollViewFrameDidChange: =========================================
//
// Purpose:		This view supposed to fill its entire scrollview even when 
//				zoomed out, to maintain the illusion of being a viewport into 
//				limitless space. However, we get no -reshape message when the 
//				scrollview expands to a size larger than our frame. So we have 
//				to snoop on the scroll view instead.
//
//==============================================================================
- (void) scrollViewFrameDidChange:(NSNotification *)notification
{
	[[self openGLContext] makeCurrentContext];
	
	NSSize maxVisibleSize = [[self enclosingScrollView] contentSize];
	[self->renderer setMaximumVisibleSize:V2MakeSize(maxVisibleSize.width, maxVisibleSize.height)];
	
	[self->renderer resetFrameSize];
	[self->renderer scrollRectToVisible:NSRectToBox2([self visibleRect]) notifyDelegate:NO];
	
}//end scrollViewFrameDidChange:


//========== renewGState =======================================================
//
// Purpose:		NSOpenGLViews' content is drawn directly by a hardware surface 
//				that, when being moved, is moved before the surrounding regular 
//				window content gets drawn and flushed. This causes an annoying 
//				flicker, especially with NSSplitViews. Overriding this method 
//				gives us a chance to compensate for this problem. 
//
//==============================================================================
- (void) renewGState
{
    NSWindow *window = [self window];
	
	// Disabling screen updates should allow the redrawing of the surrounding 
	// window to catch up with the new position of the OpenGL hardware surface. 
	//
	// Note: In Apple's "GLChildWindow" sample code, Apple put this in 
	//		 -splitViewWillResizeSubviews:. But that doesn't actually solve the 
	//		 problem. Putting it here *does*. 
	//
	[window disableScreenUpdatesUntilFlush];
	
    [super renewGState];
	
}//end renewGState


//========== reshape ===========================================================
//
// Purpose:		Something changed in the viewing department; we need to adjust 
//				our projection and viewing area.
//
//==============================================================================
- (void) reshape
{
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] makeCurrentContext];
				
		NSSize maxVisibleSize = [[self enclosingScrollView] contentSize];
		[self->renderer setMaximumVisibleSize:V2MakeSize(maxVisibleSize.width, maxVisibleSize.height)];
		
		NSRect visibleRect = [self visibleRect];
		[self->renderer scrollRectToVisible:NSRectToBox2(visibleRect) notifyDelegate:NO];
		
		[self->renderer reshape];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end reshape


//========== update ============================================================
//
// Purpose:		This method is called by the AppKit whenever our drawable area 
//				changes somehow. Ordinarily, we wouldn't be concerned about what 
//				happens here. However, calling -update is highly thread-unsafe, 
//				so we guard the context with a mutex here so as to avoid truly 
//				hideous system crashes.
//
//==============================================================================
- (void) update
{
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		[[self openGLContext] update];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}//end update


//========== viewDidMoveToSuperview ============================================
//
// Purpose:		Moving to a new superview. We can use this message to catch when 
//				we are being enclosed in a scroll view, so we can watch when the 
//				scrollview frame changes and we need to resize to artificially 
//				fill it. 
//
//==============================================================================
- (void) viewDidMoveToSuperview
{
	NSScrollView            *scrollView         = [self enclosingScrollView];
	NSNotificationCenter    *notificationCenter = [NSNotificationCenter defaultCenter];
	
	if(scrollView != nil)
	{
		[notificationCenter addObserver:self
							   selector:@selector(scrollViewFrameDidChange:)
								   name:NSViewFrameDidChangeNotification
								 object:scrollView];
	}
	else
	{
		[notificationCenter removeObserver:self
									  name:NSViewFrameDidChangeNotification
									object:nil];
	}

}//end viewDidMoveToSuperview


//========== viewDidMoveToWindow ===============================================
//
// Purpose:		The view is either being added to a window (on creation) or 
//				removed from one (on destruction).
//
//==============================================================================
- (void) viewDidMoveToWindow
{
	// Kill of any existing render thread. This is especially important for 
	// deallocation, since the thread holds a retain on us.
	if(hasThread == YES)
	{
		[self->canDrawLock lock];
		self->keepDrawThreadAlive = NO;
		[self->canDrawLock unlockWithCondition:YES]; // thread guard loop will die as soon as this is hit.
		
		self->hasThread = NO;
	}
	
	// Create a new render thread if we are moving to an actual window
	// (otherwise, we're probably being deallocated).
	if([self window] != nil)
	{
		// Multithreading didn't work out too hot; it was incompatible with nested display lists.
//		[self->canDrawLock lockWhenCondition:NO]; // wait for other thread to finish
//		self->keepDrawThreadAlive = YES;
//		[self->canDrawLock unlockWithCondition:NO];
//		[NSThread detachNewThreadSelector:@selector(threadDrawLoop:) toTarget:self withObject:nil];
//		hasThread = YES;
	}
	
}//end viewDidMoveToWindow


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== restoreConfiguration ==============================================
//
// Purpose:		Restores the viewing configuration (such as camera location and 
//				projection mode) based on data found in persistent storage. Only 
//				has effect if an autosave name has been specified.
//
//==============================================================================
- (void) restoreConfiguration
{
	if(self->autosaveName != nil)
	{
		NSUserDefaults      *userDefaults       = [NSUserDefaults standardUserDefaults];
		NSString            *viewingAngleKey    = [NSString stringWithFormat:@"%@ %@", LDRAW_GL_VIEW_ANGLE, self->autosaveName];
		NSString            *projectionModeKey  = [NSString stringWithFormat:@"%@ %@", LDRAW_GL_VIEW_PROJECTION, self->autosaveName];
		ViewOrientationT    orientation         = [userDefaults integerForKey:viewingAngleKey];
		ProjectionModeT     projection			= [userDefaults integerForKey:projectionModeKey];
		
		// It's imperative to read the modes from defaults prior to calling this 
		// methods, since -setViewOrientation automatically saves current values 
		// back into defaults! 
		[self setViewOrientation:orientation];
		[self setProjectionMode:projection];
	}
	
}//end restoreConfiguration


//========== saveConfiguration =================================================
//
// Purpose:		Saves the viewing configuration (such as camera location and 
//				projection mode) into persistent storage. Only has effect if an 
//				autosave name has been specified.
//
//==============================================================================
- (void) saveConfiguration
{
	[[self openGLContext] makeCurrentContext];
	
	if(self->autosaveName != nil)
	{
		NSUserDefaults	*userDefaults		= [NSUserDefaults standardUserDefaults];
		NSString		*viewingAngleKey	= [NSString stringWithFormat:@"%@ %@", LDRAW_GL_VIEW_ANGLE, self->autosaveName];
		NSString		*projectionModeKey	= [NSString stringWithFormat:@"%@ %@", LDRAW_GL_VIEW_PROJECTION, self->autosaveName];
		
		[userDefaults setInteger:[self->renderer viewOrientation]	forKey:viewingAngleKey];
		[userDefaults setInteger:[self->renderer projectionMode]	forKey:projectionModeKey];
		
		[userDefaults synchronize]; //because we may be quitting, we have to force this here.
	}

}//end saveConfiguration


//========== saveImage =========================================================
//
// Purpose:		Dumps the current glReadBuffer to the given file. Debugging aid.
//
//==============================================================================
- (void) saveImageToPath:(NSString *)path
{
	[[self openGLContext] makeCurrentContext];
	
	GLint   viewport [4]  = {0};
	NSSize  viewportSize    = NSZeroSize;
	size_t  byteWidth       = 0;
	uint8_t *byteBuffer     = NULL;
	
	glGetIntegerv(GL_VIEWPORT, viewport);
	viewportSize    = NSMakeSize(viewport[2], viewport[3]);
	
	byteWidth   = viewportSize.width * 4;	// Assume 4 bytes/pixel for now
	byteWidth   = (byteWidth + 3) & ~3;    // Align to 4 bytes
	
	byteBuffer  = malloc(byteWidth * viewportSize.height);
	
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	{
		glPixelStorei(GL_PACK_ALIGNMENT, 4); // Force 4-byte alignment
		glPixelStorei(GL_PACK_ROW_LENGTH, 0);
		glPixelStorei(GL_PACK_SKIP_ROWS, 0);
		glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
		
		glReadPixels(0, 0, viewportSize.width, viewportSize.height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, byteBuffer);
		NSLog(@"read error = %d", glGetError());
	}
	glPopClientAttrib();
	
	
    //---------- Save to image -------------------------------------------------
	
	CGColorSpaceRef         cSpace  = NULL;
	CGContextRef            bitmap  = NULL;
	CGImageRef              image   = NULL;
	CGImageDestinationRef   dest    = NULL;
	
	
	cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
    bitmap = CGBitmapContextCreate(byteBuffer, viewportSize.width, viewportSize.height, 8, byteWidth,
												cSpace,  
												kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host);
	
    // Make an image out of our bitmap; does a cheap vm_copy of the bitmap
    image = CGBitmapContextCreateImage(bitmap);
    NSAssert( image != NULL, @"CGBitmapContextCreate failure");
	
    // Save the image to the file
    dest = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path], CFSTR("public.tiff"), 1, nil);
    NSAssert( dest != 0, @"CGImageDestinationCreateWithURL failed");
	
    // Set the image in the image destination to be `image' with
    // optional properties specified in saved properties dict.
    CGImageDestinationAddImage(dest, image, nil);
    
    bool success = CGImageDestinationFinalize(dest);
    NSAssert( success != 0, @"Image could not be written successfully");
	
	CFRelease(cSpace);
	CFRelease(dest);
	CGImageRelease(image);
	CFRelease(bitmap);
	free(byteBuffer);
	
}//end saveImageToPath:


//========== scrollCenterToModelPoint: =========================================
//
// Purpose:		Scrolls the receiver (if it is inside a scroll view) so that 
//				newCenter is at the center of the viewing area. newCenter is 
//				given in LDraw model coordinates.
//
//==============================================================================
- (void) scrollCenterToModelPoint:(Point3)modelPoint
{
	[[self openGLContext] makeCurrentContext];
	[self->renderer scrollCenterToModelPoint:modelPoint];
}


//========== takeBackgroundColorFromUserDefaults ===============================
//
// Purpose:		The user gets to choose a background color used throughout the 
//				application. Read and use it here.
//
//==============================================================================
- (void) takeBackgroundColorFromUserDefaults
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSColor			*newColor		= [userDefaults colorForKey:LDRAW_VIEWER_BACKGROUND_COLOR_KEY];
	NSColor			*rgbColor		= nil;
	
	if(newColor == nil)
		newColor = [NSColor whiteColor];
	
	// the new color may not be in the RGB colorspace, so we need to convert.
	rgbColor = [newColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	
	CGLLockContext([[self openGLContext] CGLContextObj]);
	{
		//This method can get called from -prepareOpenGL, which is itself called 
		// from -makeCurrentContext. That's a recipe for infinite recursion. So, 
		// we only makeCurrentContext if we *need* to.
		if([NSOpenGLContext currentContext] != [self openGLContext])
			[[self openGLContext] makeCurrentContext];
			
		[self->renderer setBackgroundColorRed:[rgbColor redComponent]
										green:[rgbColor greenComponent]
										 blue:[rgbColor blueComponent] ];
	}
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
//	[[self enclosingScrollView] setDrawsBackground:YES];
//	[[self enclosingScrollView] setBackgroundColor:rgbColor];

	[self setNeedsDisplay:YES];
	
}//end takeBackgroundColorFromUserDefaults


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
	[self saveConfiguration];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[renderer		release];
	[canDrawLock	release];
	[autosaveName	release];

	[super dealloc];
	
}//end dealloc


@end
