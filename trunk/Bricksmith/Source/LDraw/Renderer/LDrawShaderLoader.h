//
//  LDrawShaderLoader.h
//  Bricksmith
//
//  Created by bsupnik on 11/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

// OpenGL shader loader.  attrib list is a null terminated list of strings that will
// be assigned to GL attributes starting at attribute index 0.
// Return code is a GLuint program object or 0 on fail.

GLuint	LDrawLoadShaderFromFile(NSString * file_path,const char * attrib_list[]);
GLuint	LDrawLoadShaderFromResource(NSString * name,const char * attrib_list[]);
