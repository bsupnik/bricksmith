/*
 *  OpenGLUtilities.h
 *  Bricksmith
 *
 *  Created by bsupnik on 7/5/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef OpenGLUtilities_h
#define OpenGLUtilities_h

#include <OpenGL/gl.h>

#if DEBUG

GLboolean		glIsDisabled(GLenum cap);
GLboolean		glCheckInteger(GLenum cap, GLint value);

#endif

#endif /* OpenGLUtilities_h */
