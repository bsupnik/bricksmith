//
//  LDrawShaderRenderer.m
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawShaderRenderer.h"
#import "ColorLibrary.h"

@implementation LDrawShaderRenderer

- (id) init
{
	self = [super init];

	[[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor] getColorRGBA:color_now];

	return self;
}

- (void) syncTexState
{
	if(texture_stack_top == 0)
		glBindTexture(GL_TEXTURE_2D, 0);
	else
	{
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
		glBindTexture(GL_TEXTURE_2D, texture_id_stack[texture_stack_top-1]);
		
		GLfloat * coef = texture_coef_stack + texture_stack_top * 8;

		glEnable(GL_TEXTURE_GEN_S);
		glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
		glTexGenfv(GL_S, GL_EYE_PLANE, coef-8);

		glEnable(GL_TEXTURE_GEN_T);
		glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
		glTexGenfv(GL_T, GL_EYE_PLANE, coef-4);
	}
}



- (void) pushMatrix:(GLfloat *)matrix
{
	glPushMatrix();
	glMultMatrixf(matrix);
}

- (void) popMatrix
{
	glPopMatrix();
}

- (void) pushColor:(GLfloat *)color
{
	assert(color_stack_top < COLOR_STACK_DEPTH);
	GLfloat * top = color_stack + color_stack_top * 4;
	top[0] = color_now[0];
	top[1] = color_now[1];
	top[2] = color_now[2];
	top[3] = color_now[3];
	++color_stack_top;
	color_now[0] = color[0];
	color_now[1] = color[1];
	color_now[2] = color[2];
	color_now[3] = color[3];
}

- (void) popColor
{
	assert(color_stack_top > 0);
	--color_stack_top;
	GLfloat * top = color_stack + color_stack_top * 4;
	color_now[0] = top[0];
	color_now[1] = top[1];
	color_now[2] = top[2];
	color_now[3] = top[3];
}

- (void) pushTexture:(GLuint) tag planeS:(float *)coefS planeT:(float *)coefT
{
	int n;
	texture_id_stack[texture_stack_top] = tag;
	for(n = 0; n < 4; ++n)
	{
		texture_coef_stack[texture_stack_top*8+n  ]=coefS[n];
		texture_coef_stack[texture_stack_top*8+n+4]=coefT[n];
	}
	++texture_stack_top;
	
	[self syncTexState];
}

- (void) popTexture
{
	assert(texture_stack_top > 0);
	--texture_stack_top;

	[self syncTexState];
}

- (void) pushWireFrame
{
	if(wire_frame_count++ == 0)
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
		
}

- (void) popWireFrame
{
	if(--wire_frame_count == 0)
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
}

- (void) drawQuad:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	glColor4fv(color ? color : color_now);
	glNormal3fv(normal);
	glBegin(GL_QUADS);
	glVertex3fv(vertices);
	glVertex3fv(vertices+3);
	glVertex3fv(vertices+6);
	glVertex3fv(vertices+9);
	glEnd();
}

- (void) drawTri:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	glColor4fv(color ? color : color_now);
	glNormal3fv(normal);
	glBegin(GL_TRIANGLES);
	glVertex3fv(vertices);
	glVertex3fv(vertices+3);
	glVertex3fv(vertices+6);
	glEnd();
}
- (void) drawLine:(GLfloat *) vertices color:(GLfloat *)color;
{
	glColor4fv(color ? color : color_now);
	glBegin(GL_LINES);
	glVertex3fv(vertices);
	glVertex3fv(vertices+3);
	glEnd();
}

- (void) drawDragHandle:(GLfloat *) vertices
{
	glPointSize(5);
	glColor4f(0,0,0,1);
	glBegin(GL_POINTS);
	glVertex3fv(vertices);
	glEnd();
	glPointSize(1);

}


@end
