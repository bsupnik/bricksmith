/*
 *  GLMatrixMath.c
 *  Bricksmith
 *
 *  Created by bsupnik on 9/24/13.
 *  Copyright 2013 __MyCompanyName__. All rights reserved.
 *
 */

#include "GLMatrixMath.h"

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

//========== perspectiveDivide ===================================================
//
// Purpose: perform a "perspective divide' on a 4-component vector - if the 'w'
//			is not zero, we convert x,y,z.  This lets us get to clip space 
//			coordinates.
//
//================================================================================
void perspectiveDivide(GLfloat p[4])
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

