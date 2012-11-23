//
//  LDrawShaderRenderer.m
//  Bricksmith
//
//  Created by bsupnik on 11/5/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawShaderRenderer.h"
#import "LDrawShaderLoader.h"
#import "LDrawDisplayList.h"
#import "ColorLibrary.h"

static const char * attribs[] = {
	"position",
	"normal",
	"color",
	"transform_x",
	"transform_y",
	"transform_z",
	"transform_w",
	"color_current",
	"color_compliment",
	"texture_mix", NULL };


static void set_color4fv(GLfloat * c, GLfloat storage[4])
{
	if(c == NULL)
	{
		storage[0] = 0;
		storage[1] = 0;
		storage[2] = 0;
		storage[3] = 0;
	}
	else if(c == (GLfloat *)-1)
	{
		storage[0] = 1;
		storage[1] = 1;
		storage[2] = 1;
		storage[3] = 0;
	}
	else 
	{
		memcpy(storage,c,sizeof(GLfloat)*4);
	}
}


#if CUSTOM_TRANSFORM

//static void applyAffineMatrix(GLfloat dst[3], const GLfloat m[16], const GLfloat v[3])
//{
//	assert(m[3] == 0.0f);
//	assert(m[7] == 0.0f);
//	assert(m[11] == 0.0f);
//	assert(m[15] == 1.0f);
//	dst[0] = v[0] * m[0] + v[1] * m[4] + v[2] * m[8] + m[12];
//	dst[1] = v[0] * m[1] + v[1] * m[5] + v[2] * m[9] + m[13];
//	dst[2] = v[0] * m[2] + v[1] * m[6] + v[2] * m[10] + m[14];
//}

static void applyMatrix(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0] + v[1] * m[4] + v[2] * m[8] + v[3] * m[12];
	dst[1] = v[0] * m[1] + v[1] * m[5] + v[2] * m[9] + v[3] * m[13];
	dst[2] = v[0] * m[2] + v[1] * m[6] + v[2] * m[10] + v[3] * m[14];
	dst[3] = v[0] * m[3] + v[1] * m[7] + v[2] * m[11] + v[3] * m[15];
}

static void perspectiveDivide(GLfloat p[4])
{
	if(p[3] != 0.0f)
	{
		float f = 1.0f / p[3];
		p[0] *= f;
		p[1] *= f;
		p[2] *= f;
	}
}

static void applyMatrixTranspose(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0 ] + v[1] * m[1 ] + v[2] * m[2 ] + v[3] * m[3 ];
	dst[1] = v[0] * m[4 ] + v[1] * m[5 ] + v[2] * m[6 ] + v[3] * m[7 ];
	dst[2] = v[0] * m[8 ] + v[1] * m[9 ] + v[2] * m[10] + v[3] * m[11];
	dst[3] = v[0] * m[12] + v[1] * m[13] + v[2] * m[14] + v[3] * m[15];
}

static void multMatrices(GLfloat dst[16], const GLfloat a[16], const GLfloat b[16])
{
	dst[0 ] = b[0 ]*a[0] + b[1 ]*a[4] + b[2 ]*a[8 ] + b[3 ]*a[12];
	dst[1 ] = b[0 ]*a[1] + b[1 ]*a[5] + b[2 ]*a[9 ] + b[3 ]*a[13];
	dst[2 ] = b[0 ]*a[2] + b[1 ]*a[6] + b[2 ]*a[10] + b[3 ]*a[14];
	dst[3 ] = b[0 ]*a[3] + b[1 ]*a[7] + b[2 ]*a[11] + b[3 ]*a[15];
	dst[4 ] = b[4 ]*a[0] + b[5 ]*a[4] + b[6 ]*a[8 ] + b[7 ]*a[12];
	dst[5 ] = b[4 ]*a[1] + b[5 ]*a[5] + b[6 ]*a[9 ] + b[7 ]*a[13];
	dst[6 ] = b[4 ]*a[2] + b[5 ]*a[6] + b[6 ]*a[10] + b[7 ]*a[14];
	dst[7 ] = b[4 ]*a[3] + b[5 ]*a[7] + b[6 ]*a[11] + b[7 ]*a[15];
	dst[8 ] = b[8 ]*a[0] + b[9 ]*a[4] + b[10]*a[8 ] + b[11]*a[12];
	dst[9 ] = b[8 ]*a[1] + b[9 ]*a[5] + b[10]*a[9 ] + b[11]*a[13];
	dst[10] = b[8 ]*a[2] + b[9 ]*a[6] + b[10]*a[10] + b[11]*a[14];
	dst[11] = b[8 ]*a[3] + b[9 ]*a[7] + b[10]*a[11] + b[11]*a[15];
	dst[12] = b[12]*a[0] + b[13]*a[4] + b[14]*a[8 ] + b[15]*a[12];
	dst[13] = b[12]*a[1] + b[13]*a[5] + b[14]*a[9 ] + b[15]*a[13];
	dst[14] = b[12]*a[2] + b[13]*a[6] + b[14]*a[10] + b[15]*a[14];
	dst[15] = b[12]*a[3] + b[13]*a[7] + b[14]*a[11] + b[15]*a[15];
}
#endif

@implementation LDrawShaderRenderer

- (id) init
{
	static GLuint prog = 0;
	if(!prog)
	{
		prog = LDrawLoadShaderFromResource(@"test.glsl", attribs);
		GLint u_tex = glGetUniformLocation(prog,"u_tex");
		glUseProgram(prog);
		glUniform1i(u_tex, 0);
	}
	else
		glUseProgram(prog);
	
	self = [super init];

	[[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor] getColorRGBA:color_now];

	glVertexAttrib1f(attr_texture_mix,0.0f);
	complimentColor(color_now, compl_now);
	
#if CUSTOM_TRANSFORM
	memset(transform_now,0,sizeof(transform_now));
	transform_now[0] = transform_now[5] = transform_now[10] = transform_now[15] = 1.0f;
	
//	int i;
//	for(i = 0; i < 4; ++i)
//		glMultiTexCoord4f(GL_TEXTURE4+i,transform_now[i],transform_now[4+i],transform_now[8+i],transform_now[12+i]);
#endif
	
	GLfloat m[16], p[16];
	glGetFloatv(GL_MODELVIEW_MATRIX,m);
	glGetFloatv(GL_PROJECTION_MATRIX,p);
	multMatrices(mvp,p,m);
	memcpy(cull_now,mvp,sizeof(mvp));

	session = LDrawDLSessionCreate(m);

	
	glEnableVertexAttribArray(attr_position);
	glEnableVertexAttribArray(attr_normal);
	glEnableVertexAttribArray(attr_color);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
				
	return self;
}

- (void) dealloc
{
	LDrawDLSessionDrawAndDestroy(session);
	session = nil;

	glUseProgram(0);

	int a;
	for(a = 0; a < attr_count; ++a)
		glDisableVertexAttribArray(a);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);

	[super dealloc];
}

- (void) syncTexState
{
	if(dl_stack_top)
	{
		if(!dl_now) dl_now = LDrawDLBuilderCreate();	
		LDrawDLBuilderSetTex(dl_now,&tex_now);
	}
}



- (void) pushMatrix:(GLfloat *)matrix
{
#if CUSTOM_TRANSFORM
	assert(transform_stack_top < TRANSFORM_STACK_DEPTH);
	memcpy(transform_stack + 16 * transform_stack_top, transform_now, sizeof(transform_now));
	multMatrices(transform_now, transform_stack + 16 * transform_stack_top, matrix);
	++transform_stack_top;
//	int i;
//	for(i = 0; i < 4; ++i)
//		glMultiTexCoord4f(GL_TEXTURE4+i,transform_now[i],transform_now[4+i],transform_now[8+i],transform_now[12+i]);

	[self pushTexture:&tex_now];
	if(tex_now.tex_obj)
	{
		GLfloat	s[4], t[4];
		applyMatrixTranspose(s,matrix,tex_now.plane_s);
		applyMatrixTranspose(t,matrix,tex_now.plane_t);
		memcpy(tex_now.plane_s,s,sizeof(s));
		memcpy(tex_now.plane_t,t,sizeof(t));
	}
#else
	glPushMatrix();
	glMultMatrixf(matrix);
#endif
	multMatrices(cull_now,mvp,transform_now);
}

- (BOOL) checkCull:(GLfloat *)minXYZ to:(GLfloat *)maxXYZ
{
	int     counter     = 0;
	GLfloat  vin[32] = {	
							minXYZ[0], minXYZ[1], minXYZ[2],1.0f,
							minXYZ[0], minXYZ[1], maxXYZ[2],1.0f,
							minXYZ[0], maxXYZ[1], maxXYZ[2],1.0f,
							minXYZ[0], maxXYZ[1], minXYZ[2],1.0f,
							
							maxXYZ[0], minXYZ[1], minXYZ[2],1.0f,
							maxXYZ[0], minXYZ[1], maxXYZ[2],1.0f,
							maxXYZ[0], maxXYZ[1], maxXYZ[2],1.0f,
							maxXYZ[0], maxXYZ[1], minXYZ[2],1.0f,
						  };
	GLfloat minb[3], maxb[3], p[4];
	
	applyMatrix(p,cull_now,vin);
	perspectiveDivide(p);
	minb[0] = maxb[0] = p[0];
	minb[1] = maxb[1] = p[1];
	minb[2] = maxb[2] = p[2];
	
	for(counter = 1; counter < 8; counter++)
	{
		applyMatrix(p,cull_now,vin+4*counter);
		perspectiveDivide(p);
		minb[0] = MIN(minb[0],p[0]);
		minb[1] = MIN(minb[1],p[1]);
		minb[2] = MIN(minb[2],p[2]);

		maxb[0] = MAX(maxb[0],p[0]);
		maxb[1] = MAX(maxb[1],p[1]);
		maxb[2] = MAX(minb[2],p[2]);
	}

	if(maxb[0] < -1.0f ||
	   maxb[1] < -1.0f ||
	   minb[0] > 1.0f ||
	   minb[1] > 1.0f)
	{
		return FALSE;
	}
	
	return TRUE;
}

- (void) popMatrix
{
#if CUSTOM_TRANSFORM
	[self popTexture];
	assert(transform_stack_top > 0);
	--transform_stack_top;
	memcpy(transform_now, transform_stack + 16 * transform_stack_top, sizeof(transform_now));
//	int i;
//	for(i = 0; i < 4; ++i)
//		glMultiTexCoord4f(GL_TEXTURE4+i,transform_now[i],transform_now[4+i],transform_now[8+i],transform_now[12+i]);
#else
	glPopMatrix();
#endif
	multMatrices(cull_now,mvp,transform_now);
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
//	glMultiTexCoord4fv(GL_TEXTURE1, color_now);
	complimentColor(color_now, compl_now);
//	glMultiTexCoord4fv(GL_TEXTURE3, comp);
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
//	glMultiTexCoord4fv(GL_TEXTURE1, color_now);
	complimentColor(color_now, compl_now);
//	glMultiTexCoord4fv(GL_TEXTURE3, comp);
}

- (void) pushTexture:(struct LDrawTextureSpec *) spec;
{
	assert(texture_stack_top < TEXTURE_STACK_DEPTH);
	memcpy(tex_stack+texture_stack_top,&tex_now,sizeof(tex_now));
	++texture_stack_top;
	memcpy(&tex_now,spec,sizeof(tex_now));
	
	[self syncTexState];
}

- (void) popTexture
{
	assert(texture_stack_top > 0);
	--texture_stack_top;
	memcpy(&tex_now,tex_stack+texture_stack_top,sizeof(tex_now));

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
	assert(dl_stack_top);
	if(!dl_now) dl_now = LDrawDLBuilderCreate();
	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddQuad(dl_now,vertices,normal,c);
}

- (void) drawTri:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	assert(dl_stack_top);
	if(!dl_now) dl_now = LDrawDLBuilderCreate();

	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddTri(dl_now,vertices,normal,c);
}

- (void) drawLine:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	assert(dl_stack_top);
	if(!dl_now) dl_now = LDrawDLBuilderCreate();

	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddLine(dl_now,vertices,normal,c);
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

- (id<LDrawCollector>) beginDL
{
//	GLfloat i[16] = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
//	[self pushMatrix:i];
//	memcpy(transform_now,i,sizeof(transform_now));
	
	assert(dl_stack_top < DL_STACK_DEPTH);
	
	dl_stack[dl_stack_top] = dl_now;
	++dl_stack_top;
	dl_now = NULL;
	
	return self;
}

- (void) endDL:(LDrawDLHandle *) outHandle cleanupFunc:(LDrawDLCleanup_f *)func
{
	assert(dl_stack_top > 0);
	struct LDrawDL * dl = dl_now ? LDrawDLBuilderFinish(dl_now) : NULL;
	--dl_stack_top;
	dl_now = dl_stack[dl_stack_top];
	
	*outHandle = (LDrawDLHandle)dl;
	*func =  (LDrawDLCleanup_f) LDrawDLDestroy;
//	[self popMatrix];
}

- (void) drawDL:(LDrawDLHandle)dl
{
	LDrawDLDraw(
		session,
		(struct LDrawDL *) dl,
		&tex_now,
		color_now,
		compl_now,
		transform_now,
		wire_frame_count > 0);
}

@end
