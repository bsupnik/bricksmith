//
//  LDrawRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// TEXTURE DEFINITIONS
//
////////////////////////////////////////////////////////////////////////////////////////////////////

// The rendering API defines a public structure for standard LDraw texturing for the purpose of
// drawing.

enum {
	tex_proj_planar = 0
};

struct	LDrawTextureSpec {
	int		projection;
	GLuint	tex_obj;
	float	plane_s[4];
	float	plane_t[4];
};

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// META-COLOR BEHAVIOR
//
////////////////////////////////////////////////////////////////////////////////////////////////////

// These "fake" ptrs can be used in place of a float[4] RGBA color for the meta-colors.
#define LDrawRenderCurrentColor ((float *) 0)
#define LDrawRenderComplimentColor ((float *) -1)


////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Opaque Display List Handles
//
////////////////////////////////////////////////////////////////////////////////////////////////////

// The rendering API defines an opaque display list handle that a renderer/collector can return.
// The cleanup function defines a function ptr used to dispose of the display list that a directive
// might be retaining.

typedef void *	LDrawDLHandle;									// Opaque handle to some kinf of cached drawing representation.
typedef void (* LDrawDLCleanup_f)(LDrawDLHandle  who);			// Cleanup function associated with a given DL.


////////////////////////////////////////////////////////////////////////////////////////////////////
// 
// LDrawCollector
//
////////////////////////////////////////////////////////////////////////////////////////////////////

// An LDraw collector accumulates meshes in a fixed coordinate system.  A texture stack can be used
// to push/pop texture state; if no texture state is pushed, the mesh ends up capable of "taking current
// texture."
//
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


////////////////////////////////////////////////////////////////////////////////////////////////////
//
// LDrawRenderer
//
////////////////////////////////////////////////////////////////////////////////////////////////////

// Renderer class - it visits each directive, which calls the various state routines.
// It provies stacks for color, transform, wire frame, and texture.
//
// When we actually want to draw a mesh, we use the begin/end/draw DL routine to create a display
// list containing the mesh.  beginDL provides a "collector" protocol capable of actually receiving
// the mesh.

@protocol LDrawRenderer
@required

// Matrix stack.  The new matrix is accumulated onto the existing transform.
- (void) pushMatrix:(GLfloat *)matrix;
- (void) popMatrix;

// Returns true if the AABB between the points is on screen, false if it is entirely off-screen.
// Useful for culling parts.
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
- (void) endDL:(LDrawDLHandle *) outHandle cleanupFunc:(LDrawDLCleanup_f *)func;		// Returns NULL if the display list is empty (e.g. no calls between begin/end)
- (void) drawDL:(LDrawDLHandle)dl;

@end

