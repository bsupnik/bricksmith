//
//  LDrawShaderRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LDrawRenderer.h"


enum {
	attr_position = 0,
	attr_normal,
	attr_color,
	attr_transform_x,
	attr_transform_y,
	attr_transform_z,
	attr_transform_w,
	attr_color_current,
	attr_color_compliment,
	attr_texture_mix,
	attr_count };


#define CUSTOM_TRANSFORM 1

#define COLOR_STACK_DEPTH 512
#define TEXTURE_STACK_DEPTH 64

#if CUSTOM_TRANSFORM
	#define TRANSFORM_STACK_DEPTH 64
#endif
#define DL_STACK_DEPTH 64

struct	LDrawDLBuilder;

@interface LDrawShaderRenderer : NSObject<LDrawRenderer,LDrawCollector> {

	struct LDrawDLSession *	session;

	GLfloat		color_now[4];
	GLfloat		compl_now[4];
	GLfloat		color_stack[COLOR_STACK_DEPTH*4];
	int			color_stack_top;
	
	int			wire_frame_count;
	
	
	struct LDrawTextureSpec	
				tex_stack[TEXTURE_STACK_DEPTH];
	int			texture_stack_top;
	struct LDrawTextureSpec	
				tex_now;

#if CUSTOM_TRANSFORM	
	GLfloat		transform_stack[TRANSFORM_STACK_DEPTH*16];
	int			transform_stack_top;
	GLfloat		transform_now[16];
	GLfloat		cull_now[16];
#endif
	
	struct LDrawDLBuilder*		dl_stack[DL_STACK_DEPTH];
	int							dl_stack_top;
	struct LDrawDLBuilder*		dl_now;
	
	GLfloat		mvp[16];

}

- (void) syncTexState;

@end
