//
//  LDrawViewerContainer.m
//  Bricksmith
//
//  Created by Allen Smith on 1/9/21.
//

#import "LDrawViewerContainer.h"

#import "LDrawGLView.h"

@interface LDrawViewerContainer ()


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
	_glView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
	[self addSubview:_glView];
	
	[_glView release];
	
	return self;
}



@end
