/*
 *  GLMatrixMath.c
 *  Bricksmith
 *
 *  Created by bsupnik on 9/24/13.
 *  Copyright 2013 __MyCompanyName__. All rights reserved.
 *
 */

#include "GLMatrixMath.h"


#if !defined(MIN)
    #define MIN(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#endif

#if !defined(MAX)
    #define MAX(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })
#endif


// copy vec3: d = s.
static inline void vec3f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
}

// copy vec4: d = s
static inline void vec4f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
	d[3] = s[3];
}

//========== applyMatrix =========================================================
//
// Purpose:	Apply a 4x4 matrix to a 4-component vector with copy.  
//
// Notes:	This routine takes data in direct "OpenGL" format.
//
//================================================================================
void applyMatrix(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0] + v[1] * m[4] + v[2] * m[8] + v[3] * m[12];
	dst[1] = v[0] * m[1] + v[1] * m[5] + v[2] * m[9] + v[3] * m[13];
	dst[2] = v[0] * m[2] + v[1] * m[6] + v[2] * m[10] + v[3] * m[14];
	dst[3] = v[0] * m[3] + v[1] * m[7] + v[2] * m[11] + v[3] * m[15];
}


//========== applyMatrixInPlace ==================================================
//
// Purpose:	Apply a 4x4 matrix to a 4-component vector.
//
// Notes:	This routine takes data in direct "OpenGL" format.
//
//================================================================================
void applyMatrixInPlace(GLfloat dst[4], const GLfloat m[16])
{
	float v[4] = { dst[0], dst[1], dst[2], dst[3] };
	applyMatrix(dst,m,v);
}


//========== perspectiveDivideInPlace ============================================
//
// Purpose: perform a "perspective divide' on a 4-component vector - if the 'w'
//			is not zero, we convert x,y,z.  This lets us get to clip space 
//			coordinates.
//
//================================================================================
void perspectiveDivideInPlace(GLfloat p[4])
{
	if(p[3] != 0.0f)
	{
		float f = 1.0f / p[3];
		p[0] *= f;
		p[1] *= f;
		p[2] *= f;
		p[3] = f;
	}
}//end perspectiveDivideInPlace


//========== perspectiveDivide ===================================================
//
// Purpose: perform a "perspective divide' on a 4-component vector - if the 'w'
//			is not zero, we convert x,y,z.  This lets us get to clip space 
//			coordinates.
//
//================================================================================
void perspectiveDivide(GLfloat o[3], const GLfloat p[4])
{
	if(p[3] != 0.0f)
	{
		float f = 1.0f / p[3];
		o[0] = p[0] * f;
		o[1] = p[1] * f;
		o[2] = p[2] * f;
	}
}//end perspectiveDivide


//========== applyMatrixTranspose ================================================
//
// Purpose: Apply the transpose of a matrix to a 4-component vector.  This
//			saves us from having to transpose our matrices that we've stashed.
//
//================================================================================
void applyMatrixTranspose(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
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
void multMatrices(GLfloat dst[16], const GLfloat a[16], const GLfloat b[16])
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


//========== buildRotationMatrix =================================================
//
// Purpose:	calculates a matrix that applies the axis-angle rotation.
//			The matrix matches the results of glRotatef.
//
// Notes:	I found the formula here:
//
// http://www.gamedev.net/topic/600537-instead-of-glrotatef-build-a-matrix/
//
//================================================================================
void buildRotationMatrix(GLfloat m[16], GLfloat angle, GLfloat x, GLfloat y, GLfloat z)
{
//			|	x^2*(1-c)+c		x*y*(1-c)-z*s	x*z*(1-c)+y*s	0	|
//	R = 	|	y*x*(1-c)+z*s	y^2*(1-c)+c		y*z*(1-c)-x*s	0	|
//			|	x*z*(1-c)-y*s	y*z*(1-c)+x*s	z^2*(1-c)+c		0	|
//			|	0				0				0				1	|

	GLfloat c = cos(angle * M_PI / 180.0f);
	GLfloat s = sin(angle * M_PI / 180.0f);

	m[0] = x*x*(1-c)+c;		m[4] = x*y*(1-c)-z*s;		m[8 ] = x*z*(1-c)+y*s;		m[12] = 0;
	m[1] = y*x*(1-c)+z*s;	m[5] = y*y*(1-c)+c;			m[9 ] = y*z*(1-c)-x*s;		m[13] = 0;
	m[2] = x*z*(1-c)-y*s;	m[6] = y*z*(1-c)+x*s;		m[10] = z*z*(1-c)+c;		m[14] = 0;
	m[3] = 0;				m[7] = 0;					m[11] = 0;					m[15] = 1;
	
}


//========== buildTranslationMatrix ==============================================
//
// Purpose: creates a matrix that applies a translation by (x,y,z).  This matches
//			the behavior of glTranslatef.
//
//================================================================================
void buildTranslationMatrix(GLfloat m[16], GLfloat x, GLfloat y, GLfloat z)
{
	m[0] = 1;	m[4] = 0;	m[8 ] = 0;	m[12] = x;
	m[1] = 0;	m[5] = 1;	m[9 ] = 0;	m[13] = y;
	m[2] = 0;	m[6] = 0;	m[10] = 1;	m[14] = z;
	m[3] = 0;	m[7] = 0;	m[11] = 0;	m[15] = 1;
}


//========== buildIdentity =======================================================
//
// Purpose: sets the passed in matrix to an identiy matrix.
//
//================================================================================
void buildIdentity(GLfloat m[16])
{
	m[0] = 1;	m[4] = 0;	m[8 ] = 0;	m[12] = 0;
	m[1] = 0;	m[5] = 1;	m[9 ] = 0;	m[13] = 0;
	m[2] = 0;	m[6] = 0;	m[10] = 1;	m[14] = 0;
	m[3] = 0;	m[7] = 0;	m[11] = 0;	m[15] = 1;	
}


//========== buildFrustumMatrix ==================================================
//
// Purpose: sets m to the frustum matrix specified by the input parameters.
//			This matches the math of glFrustum.
//
//================================================================================
void buildFrustumMatrix(GLfloat m[16], GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat zNear, GLfloat zFar)
{
	GLfloat dx=right-left;
	GLfloat dy=top-bottom;
	GLfloat dz=zFar-zNear;

	m[0]=2.0f*zNear/dx;		m[4]=0;					m[8 ]=(right+left)/dx;		m[12]=0;
	m[1]=0;					m[5]=2.0f*zNear/dy;		m[9 ]=(top+bottom)/dy;		m[13]=0;
	m[2]=0;					m[6]=0;					m[10]=-(zFar+zNear)/dz;		m[14]=-2.0*zFar*zNear/dz;
	m[3]=0;					m[7]=0;					m[11]=-1;					m[15]=0;
}


//========== buildIdentity =======================================================
//
// Purpose: sets the passed in matrix to an ortho matrix based on the input
//			parameters; matches the behavior of glOrtho.
//
//================================================================================
void buildOrthoMatrix(GLfloat m[16], GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat zNear, GLfloat zFar)
{
	GLfloat dx=right-left;
	GLfloat dy=top-bottom;
	GLfloat dz=zFar-zNear;

	m[0]=2.0f/dx;		m[4]=0;			m[8 ]=0;		m[12]=-(right+left)/dx;
	m[1]=0;				m[5]=2.0f/dy;	m[9 ]=0;		m[13]=-(top+bottom)/dy;
	m[2]=0;				m[6]=0;			m[10]=-2.0f/dz;	m[14]=-(zFar+zNear)/dz;
	m[3]=0;				m[7]=0;			m[11]=0;		m[15]=1;
}


//========== applyRotationMatrix =================================================
//
// Purpose: applies a rotation ot an existing matrix.  This is just a convenience
//			function, since often rotations need to be stacked up.
//
//================================================================================
void applyRotationMatrix(GLfloat m[16], GLfloat angle, GLfloat x, GLfloat y, GLfloat z)
{
	GLfloat temp[16], r[16];
	buildRotationMatrix(r, angle, x, y, z);
	memcpy(temp,m,sizeof(temp));
	multMatrices(m, temp, r);
}


//========== hintersect =======================================================
//
// Purpose: Given two homogeneous points A and B, intersect them with the plane
//			Z + W = 0, write the result into X.
//
// Requirement: At least one of A or B must be in front of the plane Z + W = 0.
//
//================================================================================
static void hintersect(const float a[4], const float b[4], float x[4])
{
	float v[4] = { b[0] - a[0], b[1] - a[1], b[2] - a[2], b[3] - a[3] };
	
	// Math note: the equation for intersecting a plane and a line is exactly
	// the same in homogeneous coordinates as in cartesian.  So we could
	// have said T = -PN dot a / PN dot (b - a), where PN is the plane equation
	// coefficients.  
	//
	// Using A=0,B=0,C=1,D=-1 and expanding the dot products would result in
	// the exact same formula as below.
	//
	// Here's how we do it by substitution:
	//
	// p = a + t v			z = a[2] + t v[2]
	//						w = a[3] + t v[3]
	//
	// we want: z + w = 0
	//
	// a[2] + t v[2] + w = a[3] + t v[3] = 0
	//
	// a[2] + a[3] = t -(v[2] + v[3])
	//
	// t = -(a[2] + a[3]) / (v[2] + v[3])
	
	assert((v[2] + v[3]) != 0.0);
	
	float t = -(a[2] + a[3]) / (v[2] + v[3]);
	
	assert(t >= 0.0);			// Ben says: we might need to back off this check to account for floating point fuglies; when the
	assert(t <= 1.0);			// two points are very near each other, the math is going go get inaccurate and our intersection may be on
								// the wrong side of the segments.  Since we're just using this for bounding volumes, we can live with some
								// error.  Hurray for IEEE floating point.
	
	x[0] = a[0] + t * v[0];
	x[1] = a[1] + t * v[1];
	x[2] = a[2] + t * v[2];
	x[3] = a[3] + t * v[3];
	
}//end hintersect


//========== hclip =======================================================
//
// Purpose: Given two homogeneous points A and B, clip them against the
//			plane Z + W = 0 and return the clipped line in r (which has
//			storage for two consecutive 4-d points.
//
//			The return value is 0 if the entire line is clipped, or 2 if
//			two points are provided.
//
//================================================================================
static int hclip(const float a[4], const float b[4], float r[8])
{
	int a_clip = a[2] < -a[3];
	int b_clip = b[2] < -b[3];
	
	if(a_clip)
	{
		if(b_clip)
		{
			return 0;				// All points are clipped.
		}
		else
		{
			hintersect(a,b,r);		// A is clipped away, replaced with intersection.

			r[4] = b[0];
			r[5] = b[1];
			r[6] = b[2];
			r[7] = b[3];
			
			return 2;
		}
	}
	else
	{
		if(b_clip)
		{
			r[0] = a[0];
			r[1] = a[1];
			r[2] = a[2];
			r[3] = a[3];
			hintersect(a,b,r+4);	// B is clipped away, replaced with intersection.
			return 2;
		}
		else
		{
			r[0] = a[0];			// Entire line is unclipped.
			r[1] = a[1];
			r[2] = a[2];
			r[3] = a[3];
			r[4] = b[0];
			r[5] = b[1];
			r[6] = b[2];
			r[7] = b[3];
			return 2;
		}
	}
}


//========== accum_bounds =======================================================
//
// Purpose: Given two vertices A and B in clip coordinates, clip them to the near
//			clip plane and accumulate the result (if any) into the NDC AABB passed
//			in.
//
//================================================================================
static void accum_bounds(const float a[4], const float b[4], float aabb[6])
{
	float p[8];
	
	if(hclip(a,b,p) == 0)		// Early exit if both points are in front of the
		return;					// near clip plane.
	
	// Perspective divide AFTER clipping, ensures we don't get insane results.
	perspectiveDivideInPlace(p);
	perspectiveDivideInPlace(p+4);
	
	aabb[0] = MIN(aabb[0],p[0]);
	aabb[1] = MIN(aabb[1],p[1]);
	aabb[2] = MIN(aabb[2],p[2]);

	aabb[3] = MAX(aabb[3],p[0]);
	aabb[4] = MAX(aabb[4],p[1]);
	aabb[5] = MAX(aabb[5],p[2]);

	aabb[0] = MIN(aabb[0],p[4]);
	aabb[1] = MIN(aabb[1],p[5]);
	aabb[2] = MIN(aabb[2],p[6]);

	aabb[3] = MAX(aabb[3],p[4]);
	aabb[4] = MAX(aabb[4],p[5]);
	aabb[5] = MAX(aabb[5],p[6]);
	
}


//========== meshToClipbox =======================================================
//
// Purpose:		Take a model-view axis-aligned mesh and calculate a bounding 
//				volume in normalized device coordinates.
//
// Arguments:	Oh look, this isn't an argument.
//				Yes it is!
//				No it isn't.  It's just contradiction.
//				No it isn't.
//				
//				The input mesh is an array of vertices; each one is a float[4]
//				storing x, y, z, and w.  This argument is MUTABLe: meshToClipbox
//				will trash this data.  vcount is the number of vertices passed in.
//				lines is a -1 terminated list of index pairs - for each 0-based
//				index pairs, that line segment is clipped to the near clip plane 
//				and the resulting clipped line segment is accumulated into the 
//				AABB.
//
//				The output AABB is stored as six floats:
//
//					min_x, min_y, min_z, max_x, max_y, max_z.
//
//				If a standard GL model-view + projection matrix is used, the 
//				result is a bounding volume in normalized device coordinates.
//
//================================================================================
void meshToClipbox(
				GLfloat *			vertices, 
				int					vcount, 
				const int *			lines, 
				const GLfloat		m[16], 
				GLfloat				out_aabb_ndc[6])
{
	int i; 
	
	out_aabb_ndc[0] = out_aabb_ndc[1] = out_aabb_ndc[2] =  INFINITY;
	out_aabb_ndc[3] = out_aabb_ndc[4] = out_aabb_ndc[5] = -INFINITY;

	for(i = 0; i < 8; ++i)
		applyMatrixInPlace(vertices + 4 * i, m);
		
	while(*lines != -1)
	{
		accum_bounds(vertices + 4 * lines[0], vertices + 4 * lines[1], out_aabb_ndc);
		lines += 2;
	}	
}//end meshToClipbox


//========== aabbToClipbox =========================================================
//
// Purpose:	Take a model-view axis-aligned bounding box and create a new bounding
//			box that encloses the original in normalized device coordinates.
//
//			The output is a bounding box in normalized device coordinates - that is,
//			it tells us the bounds in screen space and depth range of our box.
//
//			By convention, our bounding boxes are arrays of six floats, storing:
//
//				min_x, min_y, min_z, max_x, max_y, max_z.
//
//			Our matrix is stored in standard OpenGL column-major format.
//
// Notes:	In order for this routine to be safe with projections, it has to clip
//			the bounding box at the near clip plane.  Why?  Because the math of the
//			3-d projection goes straight to hell when points are closer than the 
//			near clip plane.  For examlpe, the X and Y coordinate (in normalized 
//			device coordinates) of geometry behind us are going to be negated!
//			Accumulating these points into a bounding volume makes for wrong 
//			results.
//
//			So we clip the volume at the near clip plane.  We don't waste effort 
//			on the other five planes because the other ones won't screw up our 
//			projection.  (Our Z value will exceed 1.0 out the back of the far clip
//			plane but we can live with this.)
//
//			Here's a diagram explaining what goes wrong if we do the naive thing
//			(namely matrix transform, perspective divide, accum bounding box):
//
//
//                  B |    |
//                 / \|    |
//                /   |    |
//               A    |\   |
//                \   | \  |
//                 \  |  \ |
//                  \ 1   \2						//
//                   \|    |						//
//                    |    |\						//
//                    |\   | \						//
//                    +-F--+  E						//
//                       \     \					//
//               C'       \     C					//
//                         \   /
//                          \ / 
//                 D'        D
//
//			In this diagram the AABB ABCD is quite huge - so much so that A and B
//			are fully to the left of the left clip plane, D and C are fully to the
//			right, and D and C are also..behind the camera!  The problem is that
//			if we naively apply a complete tranform and divide, C and D get 
//			mirrored to C' and D' due to the negative W value in clip coordinates.
//
//			This will mean that our entire NDC bounding volume is to the left of
//			the left clip plane and we fail to draw.
//
//			This function fundamentally finds E and F and computes the bounds of
//			ABEF, which does span our view volume, which is the intuitively 
//			correct result.
//
//================================================================================
void aabbToClipbox(
				const GLfloat			aabb_mv[6], 
				const GLfloat			m[16], 
				GLfloat					aabb_ndc[6])
{
	// We basically use the utility meshToClipbox to do the heavy lifting; we
	// have a hard coded 'index list' for the 12 edges of a box.

	GLfloat  vin[32] = {	
							aabb_mv[0], aabb_mv[1], aabb_mv[2],1.0f,
							aabb_mv[0], aabb_mv[1], aabb_mv[5],1.0f,
							aabb_mv[0], aabb_mv[4], aabb_mv[2],1.0f,
							aabb_mv[0], aabb_mv[4], aabb_mv[5],1.0f,
							
							aabb_mv[3], aabb_mv[1], aabb_mv[2],1.0f,
							aabb_mv[3], aabb_mv[1], aabb_mv[5],1.0f,
							aabb_mv[3], aabb_mv[4], aabb_mv[2],1.0f,
							aabb_mv[3], aabb_mv[4], aabb_mv[5],1.0f,
						  };

	static const int line_list[] = {
		0, 1, 2, 3, 4, 5, 6, 7,
		0, 2, 1, 3, 4, 6, 5, 7,
		0, 4, 1, 5, 2, 6, 3, 7,
		-1 };

	meshToClipbox(vin,8,line_list, m, aabb_ndc);
	
}//end aabbToClipbox


//========== clipTriangle ========================================================
//
// Purpose:		Given a triangle in homogeneous clip-space coordinates, this 
//				routine clips the triangle against the near clip plane (z = -w in
//				clip coords) and returns zero, one, or two triangles in 
//				normalized-device-coordinates.
//
// Arguments:	The input triangle is 12 floats: three consecutive x,y,z,w points
//				in clip coordinates.
//
//				The output triangles are 18 floats: two consecutive triangles,
//				each containing three consecutive x,y,z coordinates in device 
//				coords.  Only some of these floats are filled out, depending on
//				the number of triangles post-clipping:
//
// Return:		The number of triangles after clipping, 0, 1, or 2.  9 * return
//				floats are copied into out_tri.
//
// Notes:		If a triangle has a single vertex clipped (resulting in a quad
//				then two adjacent triangles are returned).
//
//================================================================================
int clipTriangle(const GLfloat in_tri[12], GLfloat out_tri[18])
{
	// Ihe idea is that we determine whether each of the three
	// vertices is outside our clip plane.  Then based on the
	// resulting code, we can know which vertices to output and
	// which triangle edges need to be 'split'.
	
	int code = 0;
	if (in_tri[2 ] < -in_tri[3 ])	code |= 1;		// vert 0 is clipped
	if (in_tri[6 ] < -in_tri[7 ])	code |= 2;		// vert 1 is clipped
	if (in_tri[10] < -in_tri[11])	code |= 4;		// vert 2 is clipped

	float r[16];

	switch(code) {
	case 0:
		perspectiveDivide(out_tri  ,in_tri);
		perspectiveDivide(out_tri+3,in_tri+4);
		perspectiveDivide(out_tri+6,in_tri+8);
		return 1;
	case 1:
		// Vertex 0 is clipped, leaving a quad
		hclip(in_tri,in_tri+4,r);
		hclip(in_tri+8,in_tri,r+8);
		perspectiveDivide(out_tri   ,r   );
		perspectiveDivide(out_tri+3 ,r+4 );
		perspectiveDivide(out_tri+6 ,r+8 );

		perspectiveDivide(out_tri+9 ,r   );
		perspectiveDivide(out_tri+12,r+8 );
		perspectiveDivide(out_tri+15,r+12);
		return 2;
	case 2:
		// Vertex 1 is clipped, leaving a quad
		hclip(in_tri+4,in_tri+8,r);
		hclip(in_tri  ,in_tri+4,r+8);
		perspectiveDivide(out_tri   ,r   );
		perspectiveDivide(out_tri+3 ,r+4 );
		perspectiveDivide(out_tri+6 ,r+8 );

		perspectiveDivide(out_tri+9 ,r   );
		perspectiveDivide(out_tri+12,r+8 );
		perspectiveDivide(out_tri+15,r+12);
		return 2;
	case 3:
		// Vertex 0 and 1 are both clipped.
		hclip(in_tri+4,in_tri+8,r);
		perspectiveDivide(out_tri,r);
		perspectiveDivide(out_tri+3,in_tri+8);
		hclip(in_tri+8,in_tri,r);
		perspectiveDivide(out_tri+6,r+4);
		return 1;
	case 4:
		// Vertex 2 is clipped, leaving a quad
		hclip(in_tri+8,in_tri  ,r);
		hclip(in_tri+4,in_tri+8,r+8);
		perspectiveDivide(out_tri   ,r   );
		perspectiveDivide(out_tri+3 ,r+4 );
		perspectiveDivide(out_tri+6 ,r+8 );

		perspectiveDivide(out_tri+9 ,r   );
		perspectiveDivide(out_tri+12,r+8 );
		perspectiveDivide(out_tri+15,r+12);
		return 2;	
	case 5:
		// Vertices 0 and 2 are both clipped
		hclip(in_tri,in_tri+4,r);
		perspectiveDivide(out_tri,r);
		perspectiveDivide(out_tri+3,in_tri+4);
		hclip(in_tri+4,in_tri+8,r);
		perspectiveDivide(out_tri+6,r+4);
		return 1;			
	case 6:
		// Vertices 1 and 2 are both clipped
		perspectiveDivide(out_tri,in_tri);
		hclip(in_tri,in_tri+4,r);
		perspectiveDivide(out_tri+3,r+4);
		hclip(in_tri+8,in_tri,r);
		perspectiveDivide(out_tri+6,r);
		return 1;
	case 7:
		return 0;
	default:
		return 0;
	}
	
}//end cliTriangle
