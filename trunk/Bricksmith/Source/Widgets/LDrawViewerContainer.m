//
//  LDrawViewerContainer.m
//  Bricksmith
//
//  Created by Allen Smith on 1/9/21.
//

#import "LDrawViewerContainer.h"

#import "LDrawGLView.h"

@interface LDrawViewerContainer ()

@property (nonatomic, weak) LDrawGLView* glView;
@property (nonatomic, weak) NSView* verticalPlacard;

@property (nonatomic, weak) NSScroller* horizontalScroller;
@property (nonatomic, weak) NSScroller* verticalScroller;

@property (nonatomic, assign) Box2 documentRect;
@property (nonatomic, assign) Box2 scrollVisibleRect;

@end


@implementation LDrawViewerContainer

//========== initWithFrame: ====================================================
///
/// @abstract	Designated initializer
///
//==============================================================================
- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	
    LDrawGLView *glView = [[LDrawGLView alloc] initWithFrame:self.bounds];
    _glView = glView;
	[self addSubview:_glView];
	
	return self;
}

// MARK: - ACCESSORS -

//========== setShowsScrollbars: ===============================================
///
/// @abstract	Put scrollbars around the view
///
//==============================================================================
- (void) setShowsScrollbars:(BOOL)showsScrollbars
{
	if(showsScrollbars != _showsScrollbars)
	{
		_showsScrollbars = showsScrollbars;
		
		if(showsScrollbars)
		{
			NSScroller *scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 50, [NSScroller scrollerWidthForControlSize:NSControlSizeSmall scrollerStyle:NSScrollerStyleLegacy])];
			_horizontalScroller = scroller;
			_horizontalScroller.scrollerStyle = NSScrollerStyleLegacy;
			_horizontalScroller.controlSize = NSControlSizeSmall;
			_horizontalScroller.enabled = YES;
			_horizontalScroller.target = self;
			_horizontalScroller.action = @selector(scrollerDidChange:);
			[self addSubview:_horizontalScroller];
			
			scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, [NSScroller scrollerWidthForControlSize:NSControlSizeSmall scrollerStyle:NSScrollerStyleLegacy], 50)];
			_verticalScroller = scroller;
			_verticalScroller.scrollerStyle = NSScrollerStyleLegacy;
			_verticalScroller.controlSize = NSControlSizeSmall;
			_verticalScroller.enabled = YES;
			_verticalScroller.target = self;
			_verticalScroller.action = @selector(scrollerDidChange:);
			[self addSubview:_verticalScroller];
		}
		else
		{
			[_horizontalScroller removeFromSuperview];
			[_verticalScroller removeFromSuperview];
			_horizontalScroller = nil;
			_verticalScroller = nil;
		}
	}
}

//========== setVerticalPlacard: ===============================================
///
/// @abstract	Sets the placard view for the top of the vertical scrollbar.
///
/// @discussion	Placards are little views which nestle inside scrollbar areas to
///				provide additional compact document functionality.
///
//==============================================================================
- (void) setVerticalPlacard:(NSView *)newPlacard
{
	[_verticalPlacard removeFromSuperview];
	
	_verticalPlacard = newPlacard;
	
	// Add to view hierarchy and re-layout.
	[self addSubview:newPlacard];
	
}//end setVerticalPlacard:


// MARK: - LAYOUT -

//========== layout ============================================================
///
/// @abstract	Manual layout
///
//==============================================================================
- (void) layout
{
	[super layout];
	
	NSRect viewerFrame = self.bounds;
	
	if(self.showsScrollbars)
	{
		NSRect horizontalScrollRect = _horizontalScroller.frame;
		NSRect verticalScrollRect = _verticalScroller.frame;
		
		NSDivideRect(viewerFrame, &horizontalScrollRect, &viewerFrame, NSHeight(horizontalScrollRect), NSMinYEdge);
		horizontalScrollRect.size.width -= NSWidth(verticalScrollRect);
		
		NSDivideRect(viewerFrame, &verticalScrollRect, &viewerFrame, NSWidth(verticalScrollRect), NSMaxXEdge);

		_horizontalScroller.frame = horizontalScrollRect;
		_verticalScroller.frame = verticalScrollRect;
	}
	
	if(self.verticalPlacard != nil)
	{
		NSRect		placardFrame		= [_verticalPlacard frame];
		
		if(self.showsScrollbars)
		{
			NSRect verticalScrollRect = _verticalScroller.frame;
			
			NSDivideRect(verticalScrollRect, &placardFrame, &verticalScrollRect, NSHeight(placardFrame), NSMaxYEdge);
			
			_verticalScroller.frame = verticalScrollRect;
		}
		else
		{
			// this is a nonsense case
			placardFrame.origin.x = NSMaxX(self.bounds) - NSWidth(placardFrame);
			placardFrame.origin.y = NSMaxY(self.bounds) - NSHeight(placardFrame);
			
			viewerFrame.size.width -= NSWidth(placardFrame);
		}
		_verticalPlacard.frame = placardFrame;
	}

	_glView.frame = viewerFrame;
}


//========== reflectLogicalDocumentRect:visibleRect: ===========================
///
/// @abstract	Apply the given dimensions to the scrollbars.
///
//==============================================================================
- (void) reflectLogicalDocumentRect:(Box2)newDocumentRect visibleRect:(Box2)visibleRect
{
	CGFloat horizontalKnobProportion = V2BoxWidth(visibleRect) / V2BoxWidth(newDocumentRect);
	CGFloat horizontalKnobPosition = (V2BoxMinX(visibleRect) - V2BoxMinX(newDocumentRect)) / (V2BoxWidth(newDocumentRect) - V2BoxWidth(visibleRect));

	CGFloat verticalKnobProportion = V2BoxHeight(visibleRect) / V2BoxHeight(newDocumentRect);
	CGFloat verticalKnobPosition = (V2BoxMinY(visibleRect) - V2BoxMinY(newDocumentRect)) / (V2BoxHeight(newDocumentRect) - V2BoxHeight(visibleRect));

	_horizontalScroller.knobProportion = horizontalKnobProportion;
	_horizontalScroller.doubleValue = horizontalKnobPosition;
	_verticalScroller.knobProportion = verticalKnobProportion;
	_verticalScroller.doubleValue = verticalKnobPosition;
	
	self.documentRect = newDocumentRect;
	self.scrollVisibleRect = visibleRect;
}


// MARK: - ACTIONS -

//========== scrollerDidChange: ================================================
///
/// @abstract	User dragged scroll bar; scroll 3D view.
///
//==============================================================================
- (void) scrollerDidChange:(id)sender
{
	CGFloat horizontalKnobPosition = [_horizontalScroller doubleValue];
	CGFloat verticalKnobPosition = [_verticalScroller doubleValue];
	
	Box2 newDocumentRect = self.documentRect;
	Box2 visibleRect = self.scrollVisibleRect;

	Point2 newOrigin = V2Make(horizontalKnobPosition * (V2BoxWidth(newDocumentRect) -  V2BoxWidth(visibleRect))  + V2BoxMinX(self.documentRect),
							  verticalKnobPosition   * (V2BoxHeight(newDocumentRect) - V2BoxHeight(visibleRect)) + V2BoxMinY(self.documentRect));
	
	[self.glView scrollCameraVisibleRectToPoint:newOrigin];
}

@end
