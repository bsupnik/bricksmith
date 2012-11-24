//
//  LDrawShaderRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LDrawRenderer.h"

/*

	LDrawShaderRenderer - an implementation of the LDrawRenderer API using GL shaders.

	The renderer maintains a stack view of OpenGL state; as directives push their
	info to the renderer, containing LDraw parts push and pop state to affect the
	child parts that are drawn via the depth-first traversal.
	

*/

enum {
	attr_position = 0,		// This defines the attribute indices for our particular shader.
	attr_normal,			// This must be kept in sync with the string list in the .m file.
	attr_color,
	attr_transform_x,
	attr_transform_y,
	attr_transform_z,
	attr_transform_w,
	attr_color_current,
	attr_color_compliment,
	attr_texture_mix,
	attr_count
};


// Stack depths for renderer.
#define COLOR_STACK_DEPTH 64		
#define TEXTURE_STACK_DEPTH 128
#define TRANSFORM_STACK_DEPTH 64
#define DL_STACK_DEPTH 64

struct	LDrawDLBuilder;

@interface LDrawShaderRenderer : NSObject<LDrawRenderer,LDrawCollector> {

	struct LDrawDLSession *			session;										// DL session - this accumulates draw calls and sorts them.

	GLfloat							color_now[4];									// Color stack.
	GLfloat							compl_now[4];
	GLfloat							color_stack[COLOR_STACK_DEPTH*4];
	int								color_stack_top;
	
	int								wire_frame_count;								// wire frame stack is just a count.
	
	
	struct LDrawTextureSpec			tex_stack[TEXTURE_STACK_DEPTH];					// Texture stack from push/pop texture.
	int								texture_stack_top;
	struct LDrawTextureSpec			tex_now;

	GLfloat							transform_stack[TRANSFORM_STACK_DEPTH*16];		// Transform stack from push/pop matrix.
	int								transform_stack_top;
	GLfloat							transform_now[16];
	GLfloat							cull_now[16];
	
	struct LDrawDLBuilder*			dl_stack[DL_STACK_DEPTH];						// DL stack from begin/end DL builds.
	int								dl_stack_top;
	struct LDrawDLBuilder*			dl_now;											// This is the DL being built "right now".
	
	GLfloat							mvp[16];										// Cached MVP from when shader is built.

}

@end
