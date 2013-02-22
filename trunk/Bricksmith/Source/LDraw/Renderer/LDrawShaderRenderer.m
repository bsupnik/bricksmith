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
#import "LDrawBDPAllocator.h"
#import "ColorLibrary.h"

// This list of attribute names matches the text of the GLSL attribute declarations - 
// and its order must match the attr_position...array in the .h.
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

// Drag handle linked list.  When we get drag handle requests we transform the location into eye-space (to 'capture' the 
// drag handle location, then we draw it later when our coordinate system isn't possibly scaled.
struct	LDrawDragHandleInstance {
	struct LDrawDragHandleInstance * next;
	float	xyz[3];
	float	size;
};

//========== set_color4fv ========================================================
//
// Purpose:	Copies an RGBA color, but handles the special ptrs 0L and -1L by 
//			converting them into the 'magic' colors 0,0,0,0 and 1,1,1,0 that 
//			the shader wants.
//
// Notes:	The shader, when it sees alpha = 0, mixes between the attribute-set
//			current and compliment by blending with the red channel: red = 0 is
//			current, red = 1 is compliment.
//
//================================================================================
static void set_color4fv(GLfloat * c, GLfloat storage[4])
{
	if(c == LDrawRenderCurrentColor)
	{
		storage[0] = 0;
		storage[1] = 0;
		storage[2] = 0;
		storage[3] = 0;
	}
	else if(c == LDrawRenderComplimentColor)
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
}//end set_color4fv


//========== applyMatrix =========================================================
//
// Purpose:	Apply a 4x4 matrix to a 4-component vector with copy.  
//
// Notes:	This routine takes data in direct "OpenGL" format.
//
//================================================================================
static void applyMatrix(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0] + v[1] * m[4] + v[2] * m[8 ] + v[3] * m[12];
	dst[1] = v[0] * m[1] + v[1] * m[5] + v[2] * m[9 ] + v[3] * m[13];
	dst[2] = v[0] * m[2] + v[1] * m[6] + v[2] * m[10] + v[3] * m[14];
	dst[3] = v[0] * m[3] + v[1] * m[7] + v[2] * m[11] + v[3] * m[15];
}//end applyMatrix


//========== perspectiveDivide ===================================================
//
// Purpose: perform a "perspective divide' on a 4-component vector - if the 'w'
//			is not zero, we convert x,y,z.  This lets us get to clip space 
//			coordinates.
//
//================================================================================
static void perspectiveDivide(GLfloat p[4])
{
	if(p[3] != 0.0f)
	{
		float f = 1.0f / p[3];
		p[0] *= f;
		p[1] *= f;
		p[2] *= f;
	}
}//end perspectiveDivide


//========== applyMatrixTranspose ================================================
//
// Purpose: Apply the transpose of a matrix to a 4-component vector.  This
//			saves us from having to transpose our matrices that we've stashed.
//
//================================================================================
static void applyMatrixTranspose(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0 ] + v[1] * m[1 ] + v[2] * m[2 ] + v[3] * m[3 ];
	dst[1] = v[0] * m[4 ] + v[1] * m[5 ] + v[2] * m[6 ] + v[3] * m[7 ];
	dst[2] = v[0] * m[8 ] + v[1] * m[9 ] + v[2] * m[10] + v[3] * m[11];
	dst[3] = v[0] * m[12] + v[1] * m[13] + v[2] * m[14] + v[3] * m[15];
}//end applyMatrixTranspose


//========== multMatrices ========================================================
//
// Purpose: compose two matrices in OpenGL format.
//
//================================================================================
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
}//end multMatrices


//================================================================================
@implementation LDrawShaderRenderer
//================================================================================


//========== init: ===============================================================
//
// Purpose: initialize our renderer, and grab all basic OpenGL state we need.
//
//================================================================================
- (id) initWithScale:(float)initial_scale;
{	
	pool = LDrawBDPCreate();
	// Build our shader if it doesn't exist yet.  For now, just stash the GL 
	// object statically.
	static GLuint prog = 0;
	if(!prog)
	{
		prog = LDrawLoadShaderFromResource(@"test.glsl", attribs);
		GLint u_tex = glGetUniformLocation(prog,"u_tex");
		glUseProgram(prog);
		
		// This matches up texture unit 0 with the sampler in the shader.
		glUniform1i(u_tex, 0);
	}
	else
		glUseProgram(prog);
	
	self = [super init];

	self->scale = initial_scale;

	[[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor] getColorRGBA:color_now];
	glVertexAttrib1f(attr_texture_mix,0.0f);
	complimentColor(color_now, compl_now);
	
	// Set up the basic transform to be identity - our transform is on top of the MVP matrix.
	memset(transform_now,0,sizeof(transform_now));
	transform_now[0] = transform_now[5] = transform_now[10] = transform_now[15] = 1.0f;
	
	// "Rip" the MVP matrix from OpenGL.  (TODO: does LDraw just have this info?)  
	// We use this for culling.
	GLfloat m[16], p[16];
	glGetFloatv(GL_MODELVIEW_MATRIX,m);
	glGetFloatv(GL_PROJECTION_MATRIX,p);
	multMatrices(mvp,p,m);
	memcpy(cull_now,mvp,sizeof(mvp));

	// Create a DL session to match our lifetime.
	session = LDrawDLSessionCreate(m);
	
	// Set up GL state for attribute drawing, not the fixed function drawing we used to do.
	glEnableVertexAttribArray(attr_position);
	glEnableVertexAttribArray(attr_normal);
	glEnableVertexAttribArray(attr_color);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
				
	drag_handles = NULL;
				
	return self;
}//end init:


//========== dealloc: ============================================================
//
// Purpose: Clean up our state.  Note that this "triggers" the draw from our
//			display list session that has stored up some of our draw calls.
//
//================================================================================
- (void) dealloc
{
	struct LDrawDragHandleInstance * dh;
	LDrawDLSessionDrawAndDestroy(session);
	session = nil;
	
	// Go through and draw the drag handles...
	
	for(dh = drag_handles; dh != NULL; dh = dh->next)
	{
		GLfloat s = dh->size / self->scale;
		GLfloat m[16] = { s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, dh->xyz[0], dh->xyz[1],dh->xyz[2], 1.0 };

		[self pushMatrix:m];		
		[self drawDragHandleImm:dh->xyz withSize:dh->size];
		[self popMatrix];
	}

	// Put back OGL state to what LDraw usually has.
	glUseProgram(0);

	int a;
	for(a = 0; a < attr_count; ++a)
		glDisableVertexAttribArray(a);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);

	LDrawBDPDestroy(pool);

	[super dealloc];
	
}//end dealloc:


//========== pushMatrix: =========================================================
//
// Purpose: accumulate a transform temporarily.  The transform will be 'grabbed'
//			later if a DL is made.
//
// Notes:	our current texture is mapped in _object_ coordinates.  So if we are
//			going to transform our coordinate system AND we have textures active
//			we produce a new texture whose planar projection matches our new
//			coordinates.
//
//			IF we used eye-space texturing this would not be necessary.  But
//			eye space texturing was actually more complex than this case in the
//			shader.
//
//================================================================================
- (void) pushMatrix:(GLfloat *)matrix
{
	assert(transform_stack_top < TRANSFORM_STACK_DEPTH);
	memcpy(transform_stack + 16 * transform_stack_top, transform_now, sizeof(transform_now));
	multMatrices(transform_now, transform_stack + 16 * transform_stack_top, matrix);
	++transform_stack_top;

	[self pushTexture:&tex_now];
	if(tex_now.tex_obj)
	{
		// If we have a current texture, transform the tetxure by "matrix".
		// TODO: doc _why_ this works mathematically.
		GLfloat	s[4], t[4];
		applyMatrixTranspose(s,matrix,tex_now.plane_s);
		applyMatrixTranspose(t,matrix,tex_now.plane_t);
		memcpy(tex_now.plane_s,s,sizeof(s));
		memcpy(tex_now.plane_t,t,sizeof(t));
	}
	multMatrices(cull_now,mvp,transform_now);
}//end pushMatrix:


//========== checkCull:to: =======================================================
//
// Purpose: cull out bounding boxes that are off-screen.  We transform to clip
//			coordinates and see if the AABB (in screen space) of the original
//			bounding cube (in MV coordinates) is now entirely out of clip bounds.
//
//================================================================================
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
		maxb[2] = MAX(maxb[2],p[2]);
	}

	if(maxb[0] < -1.0f ||
	   maxb[1] < -1.0f ||
	   minb[0] > 1.0f ||
	   minb[1] > 1.0f)
	{
		return FALSE;
	}
	
	return TRUE;
}//end pushMatrix:to:


//========== popMatrix: ==========================================================
//
// Purpose: reset one level of the matrix stack.
//
//================================================================================
- (void) popMatrix
{
	// We always push a texture frame with every matrix frame for now, so that
	// we can re-transform the tex projection.  We simply have 2x the slots
	// in our stacks.
	[self popTexture];
	
	assert(transform_stack_top > 0);
	--transform_stack_top;
	memcpy(transform_now, transform_stack + 16 * transform_stack_top, sizeof(transform_now));
	multMatrices(cull_now,mvp,transform_now);
}//end popMatrix:


//========== pushColor: ==========================================================
//
// Purpose: push a color change onto the stack.  This sets the RGBA for the 
//			current and compliment color for DLs that use the current color.
//
//================================================================================
- (void) pushColor:(GLfloat *)color
{
	assert(color_stack_top < COLOR_STACK_DEPTH);
	GLfloat * top = color_stack + color_stack_top * 4;
	top[0] = color_now[0];
	top[1] = color_now[1];
	top[2] = color_now[2];
	top[3] = color_now[3];
	++color_stack_top;
	if(color != LDrawRenderCurrentColor)
	{
		if(color == LDrawRenderComplimentColor)
			color = compl_now;
		color_now[0] = color[0];
		color_now[1] = color[1];
		color_now[2] = color[2];
		color_now[3] = color[3];
		complimentColor(color_now, compl_now);
	}
}//end pushColor:


//========== popColor: ===========================================================
//
// Purpose: pop the stack of current colors that has previously been pushed.
//
//================================================================================
- (void) popColor
{
	assert(color_stack_top > 0);
	--color_stack_top;
	GLfloat * top = color_stack + color_stack_top * 4;
	color_now[0] = top[0];
	color_now[1] = top[1];
	color_now[2] = top[2];
	color_now[3] = top[3];
	complimentColor(color_now, compl_now);
}//end popColor:


//========== pushTexture: ========================================================
//
// Purpose: change the current texture to a new one, specified by a spec with
//			textures and projection.
//
//================================================================================
- (void) pushTexture:(struct LDrawTextureSpec *) spec;
{
	assert(texture_stack_top < TEXTURE_STACK_DEPTH);
	memcpy(tex_stack+texture_stack_top,&tex_now,sizeof(tex_now));
	++texture_stack_top;
	memcpy(&tex_now,spec,sizeof(tex_now));
	
	if(dl_stack_top)
		LDrawDLBuilderSetTex(dl_now,&tex_now);
		
}//end pushTexture:


//========== popTexture: =========================================================
//
// Purpose: pop a texture off the stack that was previously pushed.  When the
//			last texture is popped, we go back to being untextured.
//
//================================================================================
- (void) popTexture
{
	assert(texture_stack_top > 0);
	--texture_stack_top;
	memcpy(&tex_now,tex_stack+texture_stack_top,sizeof(tex_now));

	if(dl_stack_top)
		LDrawDLBuilderSetTex(dl_now,&tex_now);
		
}//end popTexture:


//========== pushWireFrame: ======================================================
//
// Purpose: push a change to wire frame mode.  This is nested - when the last 
//			"wire frame" is popped, we are no longer wire frame.
//
//================================================================================
- (void) pushWireFrame
{
	if(wire_frame_count++ == 0)
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);		
		
}//end pushWireFrame:


//========== popWireFrame: =======================================================
//
// Purpose: undo a previous wire frame command - the push and pops must be
//			balanced.
//
//================================================================================
- (void) popWireFrame
{
	if(--wire_frame_count == 0)
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

}//end popWireFrame:


//========== drawQuad:normal:color: ==============================================
//
// Purpose: Adds one quad to the current display list.
//
// Notes:	This should only be called after a dlBegin has been called; client 
//			code only gets a protocol interface to this API by calling beginDL
//			first.
//
//================================================================================
- (void) drawQuad:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	assert(dl_stack_top);
	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddQuad(dl_now,vertices,normal,c);

}//end drawQuad:normal:color:


//========== drawTri:normal:color: ===============================================
//
// Purpose: Adds one triangle to the current display list.
//
//================================================================================
- (void) drawTri:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	assert(dl_stack_top);

	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddTri(dl_now,vertices,normal,c);

}//end drawTri:normal:color:


//========== drawLine:normal:color: ==============================================
//
// Purpose: Adds one line to the current display list.
//
//================================================================================
- (void) drawLine:(GLfloat *) vertices normal:(GLfloat *)normal color:(GLfloat *)color;
{
	assert(dl_stack_top);

	GLfloat c[4];

	set_color4fv(color,c);
	
	LDrawDLBuilderAddLine(dl_now,vertices,normal,c);
}//end drawLine:normal:color:


//========== drawDragHandle:withSize: ============================================
//
// Purpose:	This draws one drag handle using the current transform.
//
// Notes:	We do'nt draw anything - we just grab a list link and stash the
//			drag handle in "global model space" - that is, the space that the 
//			root of all drawing happens, without the local part transform.
//			We do that so that when we pop out all local transforms and draw 
//			later we will be in the right place, but we'll have no local scaling 
//			that could deform our handle.
//
//================================================================================
- (void) drawDragHandle:(GLfloat *)xyz withSize:(GLfloat)size
{
	struct LDrawDragHandleInstance * dh = (struct LDrawDragHandleInstance *) LDrawBDPAllocate(pool,sizeof(struct LDrawDragHandleInstance));
	
	dh->next = drag_handles;	
	drag_handles = dh;
	dh->size = 7.0;
	
	GLfloat handle_local[4] = { xyz[0], xyz[1], xyz[2], 1.0f };
	GLfloat handle_world[4];
	
	applyMatrix(handle_world,transform_now, handle_local);
	
	dh->xyz[0] = handle_world[0];
	dh->xyz[1] = handle_world[1];
	dh->xyz[2] = handle_world[2];
	dh->size = size;

}//end drawDragHandle:withSize:


//========== drawDragHandle:withSize: ============================================
//
// Purpose:	Draw a drag handle - for realzies this time
//
// Notes:	This routine builds a one-off sphere VBO as needed.  BrickSmith
//			guarantees that we never lose our shared group of GL contexts, so we
//			don't have to worry about the last context containing the VBO going
//			away.
//
//			The vertex format for the sphere handle is just pure vertices - since
//			the draw routine sets up its own VAO with its own internal format,
//			there's no need to depend on or conform to vertex formats for the rest
//			of the drawing system.
//
//================================================================================
- (void) drawDragHandleImm:(GLfloat *)xyz withSize:(GLfloat)size
{
	static GLuint   vaoTag          = 0;
	static GLuint   vboTag          = 0;
	static GLuint   vboVertexCount  = 0;

	if(vaoTag == 0)
	{
		// Bail if we've already done it.

		int latitudeSections = 8;
		int longitudeSections = 8;
		
		float           latitudeRadians     = (M_PI / latitudeSections); // lat. wraps halfway around sphere
		float           longitudeRadians    = (2*M_PI / longitudeSections); // long. wraps all the way
		int             vertexCount         = 0;
		GLfloat			*vertexes           = NULL;
		int             latitudeCount       = 0;
		int             longitudeCount      = 0;
		float           latitude            = 0;
		float           longitude           = 0;
		
		//---------- Generate Sphere -----------------------------------------------
		
		// Each latitude strip begins with two vertexes at the prime meridian, then 
		// has two more vertexes per segment thereafter. 
		vertexCount = (2 + longitudeSections*2) * latitudeSections; 

		glGenBuffers(1, &vboTag);
		glBindBuffer(GL_ARRAY_BUFFER, vboTag);	
		glBufferData(GL_ARRAY_BUFFER, vertexCount * 3 * sizeof(GLfloat), NULL, GL_STATIC_DRAW);
		vertexes = (GLfloat *) glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
		
		// Calculate vertexes for each strip of latitude.
		for(latitudeCount = 0; latitudeCount < latitudeSections; latitudeCount += 1 )
		{
			latitude = (latitudeCount * latitudeRadians);
			
			// Include the prime meridian twice; once to start the strip and once to 
			// complete the last triangle of the -1 meridian. 
			for(longitudeCount = 0; longitudeCount <= longitudeSections; longitudeCount += 1 )
			{
				longitude = longitudeCount * longitudeRadians;
			
				// Ben says: when we are "pushing" vertices into a GL_WRITE_ONLY mapped buffer, we should really
				// never read back from the vertices that we read to - the memory we are writing to often has funky
				// properties like being uncached which make it expensive to do anything other than what we said we'd
				// do (and we said: we are only going to write to them).  
				//
				// Mind you it's moot in this case since we only need to write vertices.
			
				// Top vertex
				*vertexes++ =cos(longitude)*sin(latitude);
				*vertexes++ =sin(longitude)*sin(latitude);
				*vertexes++ =cos(latitude);
			
				// Bottom vertex
				*vertexes++ = cos(longitude)*sin(latitude + latitudeRadians);
				*vertexes++ = sin(longitude)*sin(latitude + latitudeRadians);
				*vertexes++ = cos(latitude + latitudeRadians);
			}
		}

		glUnmapBuffer(GL_ARRAY_BUFFER);
		glBindBuffer(GL_ARRAY_BUFFER, 0);	

		//---------- Optimize ------------------------------------------------------
		
		vboVertexCount = vertexCount;
		
		// Encapsulate in a VAO
		glGenVertexArraysAPPLE(1, &vaoTag);
		glBindVertexArrayAPPLE(vaoTag);
		glBindBuffer(GL_ARRAY_BUFFER, vboTag);	
		glEnableVertexAttribArray(attr_position);
		glEnableVertexAttribArray(attr_normal);		
		// Normal and vertex use the same data - in a unit sphere the normals are the vertices!
		glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), NULL);
		glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), NULL);
		// The sphere color is constant - no need to get it from per-vertex data.
		glBindVertexArrayAPPLE(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
	}
	
	glDisable(GL_TEXTURE_2D);
	
	int i;
	for(i = 0; i < 4; ++i)
		glVertexAttrib4f(attr_transform_x+i,transform_now[i],transform_now[4+i],transform_now[8+i],transform_now[12+i]);

	glVertexAttrib4f(attr_color,0.50,0.53,1.00,1.00);		// Nice lavendar color for the whole sphere.
	
	glBindVertexArrayAPPLE(vaoTag);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, vboVertexCount);
	glBindVertexArrayAPPLE(0); // Failing to unbind can cause bizarre crashes if other VAOs are in display lists

	glEnable(GL_TEXTURE_2D);

}//end drawDragHandleImm:


//========== beginDL: ============================================================
//
// Purpose:	This begins accumulating a display list.
//
//================================================================================
- (id<LDrawCollector>) beginDL
{
	assert(dl_stack_top < DL_STACK_DEPTH);
	
	dl_stack[dl_stack_top] = dl_now;
	++dl_stack_top;
	dl_now = LDrawDLBuilderCreate();
	
	return self;

}//end beginDL:


//========== endDL:cleanupFunc: ==================================================
//
// Purpose: close off a DL, returning the display list if there is one.
//
//================================================================================
- (void) endDL:(LDrawDLHandle *) outHandle cleanupFunc:(LDrawDLCleanup_f *)func
{
	assert(dl_stack_top > 0);
	struct LDrawDL * dl = dl_now ? LDrawDLBuilderFinish(dl_now) : NULL;
	--dl_stack_top;
	dl_now = dl_stack[dl_stack_top];
	
	*outHandle = (LDrawDLHandle)dl;
	*func =  (LDrawDLCleanup_f) LDrawDLDestroy;

}//end endDL:cleanupFunc:


//========== drawDL: =============================================================
//
// Purpose:	draw a DL using the current state.  We pass this to our DL session 
//			that sorts out how to actually do tihs.
//
//================================================================================
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

}//end drawDL:

@end
