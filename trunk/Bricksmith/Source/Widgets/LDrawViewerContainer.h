//
//  LDrawViewerContainer.h
//  Bricksmith
//
//  Created by Allen Smith on 1/9/21.
//

#import <Foundation/Foundation.h>

@class LDrawGLView;

NS_ASSUME_NONNULL_BEGIN

//------------------------------------------------------------------------------
///
/// @class		LDrawViewerContainer
///
/// @abstract	Holds an LDrawGLView. You should always use an
/// 			LDrawViewerContainer instead of instantiating a 3D view
/// 			directly; this level of abstraction allows more flexibility in
/// 			decorating the view with other Cocoa components.
///
//------------------------------------------------------------------------------
@interface LDrawViewerContainer : NSView

@property (nonatomic, assign) LDrawGLView* glView;

- (void) setVerticalPlacard:(NSView *)placardView;

@end

NS_ASSUME_NONNULL_END
