//
//  LDrawShaderRenderer.h
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LDrawRenderer.h"

#define COLOR_STACK_DEPTH 512
#define TEXTURE_STACK_DEPTH 64

@interface LDrawShaderRenderer : NSObject<LDrawRenderer> {

	GLfloat		color_now[4];
	GLfloat		color_stack[COLOR_STACK_DEPTH*4];
	int			color_stack_top;
	
	int			wire_frame_count;
	
	
	GLfloat		texture_coef_stack[TEXTURE_STACK_DEPTH*8];
	GLuint		texture_id_stack[TEXTURE_STACK_DEPTH];
	int			texture_stack_top;

}

- (void) syncTexState;

@end
