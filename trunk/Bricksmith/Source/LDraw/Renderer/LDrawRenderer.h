//
//  LDrawRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LDrawRenderer.h"

@protocol LDrawRenderable;
@protocol LDrawRenderer;

enum {
	tex_proj_planar = 0
};

struct	LDrawTextureSpec {
	int		projection;
	GLuint	tex_obj;
	float	plane_s[4];
	float	plane_t[4];
};

typedef void *	LDrawDLHandle;									// Opaque handle to some kinf of cached drawing representation.
typedef void (* LDrawDLCleanup_f)(LDrawDLHandle  who);			// Cleanup function associated with a given DL.

//@protocol LDrawRenderable
//@required
//
//- (void) acceptDL:(LDrawDLHandle)dl cleanupFunc:(LDrawDLCleanup_f)func;
//
//@end

@protocol LDrawCollector

// Texture stack - sets up new texturing.  When the stack is totally popped, no texturing is applied.
- (void) pushTexture:(struct LDrawTextureSpec *)tex_spec;
- (void) popTexture;

// Raw drawing APIs to push one quad/tri/line.  Vertices are consecutive float verts, e.g. 12 for quad, 9 for tri, 6 for line/
// Color can be null to use the current color.  Normal is a float[3] normal ptr.
- (void) drawQuad:(GLfloat *) vertices normal:(GLfloat *) normal color:(GLfloat *)color;
- (void) drawTri:(GLfloat *) vertices normal:(GLfloat *) normal color:(GLfloat *)color;
- (void) drawLine:(GLfloat *) vertices normal:(GLfloat *) normal color:(GLfloat *)color;

@end


@protocol LDrawRenderer
@required

// Matrix stack.  The new matrix is accumulated onto the existing transform.
- (void) pushMatrix:(GLfloat *)matrix;
- (void) popMatrix;

- (BOOL) checkCull:(GLfloat *)minXYZ to:(GLfloat *)maxXYZ;

// Color stack.  Pushing a color overrides the current color.  If no one ever sets the current color we get
// that generic beige that is the RGBA of color 16.
- (void) pushColor:(GLfloat *)color;
- (void) popColor;

// Wire frame count - if a non-zero number of wire frame requests are outstanding, we render in wireframe.
- (void) pushWireFrame;
- (void) popWireFrame;

// Texture stack - sets up new texturing.  When the stack is totally popped, no texturing is applied.
- (void) pushTexture:(struct LDrawTextureSpec *)tex_spec;
- (void) popTexture;

// Drag handle is simply the location of the handle (float[3]).
- (void) drawDragHandle:(GLfloat *) vertices;

- (id<LDrawCollector>) beginDL;
- (void) endDL:(LDrawDLHandle *) outHandle cleanupFunc:(LDrawDLCleanup_f *)func;
- (void) drawDL:(LDrawDLHandle)dl;

@end

