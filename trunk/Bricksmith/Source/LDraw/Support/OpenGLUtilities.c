/*
 *  OpenGLUtilities.c
 *  Bricksmith
 *
 *  Created by bsupnik on 7/5/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

#include "OpenGLUtilities.h"

#if DEBUG

GLboolean		glIsDisabled(GLenum cap)
{
	return !glIsEnabled(cap);
}

GLboolean		glCheckInteger(GLenum cap, GLint value)
{
	GLint v = 0;
	glGetIntegerv(cap, &v);
	if(v != value)
		printf("Expected tag %04x to be %d but was %d\n", cap, value, v);
	return (v == value);
}

#endif
