//
//  LDrawViewerContainer.h
//  Bricksmith
//
//  Created by Allen Smith on 1/9/21.
//

#import <Foundation/Foundation.h>

#import "MatrixMath.h"

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

@property (nonatomic, readonly) LDrawGLView* glView;
@property (nonatomic, assign) BOOL showsScrollbars;

- (void) setVerticalPlacard:(NSView *)placardView;
- (void) reflectLogicalDocumentRect:(Box2)newDocumentRect visibleRect:(Box2)visibleRect;

@end

NS_ASSUME_NONNULL_END
