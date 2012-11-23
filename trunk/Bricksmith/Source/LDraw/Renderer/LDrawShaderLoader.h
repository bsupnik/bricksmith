//
//  LDrawShaderLoader.h
//  Bricksmith
//
//  Created by bsupnik on 11/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

GLuint	LDrawLoadShaderFromFile(NSString * file_path,const char * attrib_list[]);
GLuint	LDrawLoadShaderFromResource(NSString * name,const char * attrib_list[]);
