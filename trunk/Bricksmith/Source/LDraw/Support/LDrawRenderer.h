//
//  LDrawRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol LDrawRenderable;
@protocol LDrawRenderer;

typedef void *	LDrawDLHandle;

typedef void (* LDrawDLCleanup_f)(LDrawDLHandle * who);

@protocol LDrawRenderable
@required

- (void) drawSelf:(id<LDrawRenderer>)renderer;
- (void) acceptDL:(LDrawDLHandle)dl cleanupFunc:(LDrawDLCleanup_f)func;

@end


@protocol LDrawRenderer
@required

- (void) pushMatrix:(GLfloat *)matrix;
- (void) popMatrix;
- (void) pushColor:(GLfloat *)color;
- (void) popColor;
- (void) pushWireFrame;
- (void) popWireFrame;
- (void) pushTexture:(GLuint) tag planeS:(float *)coefS planeT:(float *)coefT;
- (void) popTexture;

- (void) drawQuad:(GLfloat *) vertices normal:(GLfloat *) normal color:(GLfloat *)color;
- (void) drawTri:(GLfloat *) vertices normal:(GLfloat *) normal color:(GLfloat *)color;
- (void) drawLine:(GLfloat *) vertices color:(GLfloat *)color;
- (void) drawDragHandle:(GLfloat *) vertices;



@end
