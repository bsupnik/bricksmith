//
//  LDrawShaderLoader.m
//  Bricksmith
//
//  Created by bsupnik on 11/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawShaderLoader.h"
#import "LDrawUtilities.h"

//========== load_shader ================================================
//
// Purpose:		Load a single shader object for linking later.
//
// Notes:		shader_prefix is a string pre-inserted into the string.
//				This is how we get VSHADER and FSHADER defined.  
//
//=======================================================================
static GLuint	load_shader(NSString * file_path, GLenum shader_type, const char * shader_prefix)
{
	GLuint	shader_obj = glCreateShader(shader_type);

	NSString *	shader_file_text	= [LDrawUtilities stringFromFile:file_path];
	
	const GLchar * shader_text[2] = { shader_prefix, [shader_file_text UTF8String] };
	glShaderSource(shader_obj,2,shader_text,NULL);
	glCompileShader(shader_obj);
	
	GLint result;
	glGetShaderiv(shader_obj,GL_COMPILE_STATUS,&result);
	if(!result)
	{
		GLint log_len;
		glGetShaderiv(shader_obj, GL_INFO_LOG_LENGTH, &log_len);
		GLchar * buf = (GLchar *) malloc(log_len);
		glGetShaderInfoLog(shader_obj,log_len,NULL,buf);
		printf("Shader %s failed.\n%s\n",[file_path UTF8String],buf);
		free(buf);
		glDeleteShader(shader_obj);
		return 0;
	}
	return shader_obj;	
}//end load_shader


//=========- LDrawLoadShaderFromFile ====================================
//
// Purpose:		Load a shader from disk.
//
// Notes:		Automatically adds prefixes to select GLSL 120 and define
//				FSHADER or VSHADER for the two types of shaders.
//				
//				Automatically binds the attribute list consecutively pre-
//				link.
//
//=======================================================================
GLuint	LDrawLoadShaderFromFile(NSString * file_path, const char * attrib_list[])
{
	GLuint vshader = load_shader(file_path,GL_VERTEX_SHADER,"#version 120\n#define VSHADER 1\n#define FSHADER 0\n");
	GLuint fshader = load_shader(file_path,GL_FRAGMENT_SHADER,"#version 120\n#define VSHADER 0\n#define FSHADER 1\n");
	if(!vshader || !fshader) 
		return 0;
	GLuint prog = glCreateProgram();
	glAttachShader(prog,vshader);
	glAttachShader(prog,fshader);
	
	if(attrib_list)
	{
		int a = 0;
		while(attrib_list[a])
		{
			glBindAttribLocation(prog, a, attrib_list[a]);
			++a;
		}
	}
	
	glLinkProgram(prog);
	
	GLint result;
	glGetProgramiv(prog,GL_LINK_STATUS,&result);
	if(!result)
	{
		GLint log_len;
		glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &log_len);
		GLchar * buf = (GLchar *) malloc(log_len);
		glGetProgramInfoLog(prog,log_len,NULL,buf);
		printf("Shader %s failed.\n%s\n",[file_path UTF8String],buf);
		free(buf);
		glDeleteShader(vshader);
		glDeleteShader(fshader);
		glDeleteProgram(prog);
		return 0;	
	}
	return prog;
}//end LDrawLoadShaderFromFile


//=========- LDrawLoadShaderFromResource ================================
//
// Purpose:		Load a shader from a resource.
//
// Notes:		Finds a shader in our app bundle, which is the preferred
//				way to use our shaders.
//
//=======================================================================
GLuint	LDrawLoadShaderFromResource(NSString * name, const char * attrib_list[])
{
	NSBundle * mainBundle	= [NSBundle mainBundle];
	NSString * path	= [mainBundle pathForResource:name ofType:nil];
	return LDrawLoadShaderFromFile(path,attrib_list);
}//end LDrawLoadShaderFromResource
