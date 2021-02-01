//
//  LDrawViewerContainer.m
//  Bricksmith
//
//  Created by Allen Smith on 1/9/21.
//

#import "LDrawViewerContainer.h"

#import "LDrawGLView.h"

@interface LDrawViewerContainer ()

@property (nonatomic, strong) NSView* verticalPlacard;

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
	
	_glView = [[LDrawGLView alloc] initWithFrame:self.bounds];
	[self addSubview:_glView];
	
	[_glView release];
	
	return self;
}

// MARK: - ACCESSORS -

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
	[newPlacard retain];
	
	[_verticalPlacard removeFromSuperview];
	[_verticalPlacard release];
	
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
	
	// Stupid; for now we will just carve out space like there used to be with
	// scrollbars. Either we add scrollers back, or the placard should move to
	// the LDrawGLView's overlay view.
	if(self.verticalPlacard != nil)
	{
		NSRect		placardFrame		= [_verticalPlacard frame];
		
		placardFrame.origin.x = NSMaxX(self.bounds) - NSWidth(placardFrame);
		placardFrame.origin.y = NSMaxY(self.bounds) - NSHeight(placardFrame);
		
		viewerFrame.size.width -= NSWidth(placardFrame);
		
		[_verticalPlacard	setFrame:placardFrame];
	}

	_glView.frame = viewerFrame;
}

@end
