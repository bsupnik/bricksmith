//
//  LDrawDataStream.m
//  Bricksmith
//
//  Created by bsupnik on 11/18/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawDataStream.h"
#import <OpenGL/glext.h>

#define WINDOWED_STREAM 1


#if WINDOWED_STREAM

struct LDrawDataStream {
	GLuint			vbo;
	int				total_size;
	int				cur_base;
	int				cur_size;
};

//========== LDrawDataStreamCreate ===============================================
//
// Purpose:		Create a new data stream.
//
// Notes:		Buffer size is the size of the entire VBO allocation that
//				we will window.
//
//================================================================================
struct LDrawDataStream *	LDrawDataStreamCreate(int buffer_size)
{
	struct LDrawDataStream * r = (struct LDrawDataStream *) malloc(sizeof(struct LDrawDataStream));
	glGenBuffers(1,&r->vbo);
	glBindBuffer(GL_ARRAY_BUFFER,r->vbo);
	glBufferData(GL_ARRAY_BUFFER, buffer_size, NULL, GL_DYNAMIC_DRAW);
	// Disable auto-flush and auto-sync.  It would be nice to use the gl 2.0 API but it's not on
	// 10.6.8.
	glBufferParameteriAPPLE(GL_ARRAY_BUFFER, GL_BUFFER_FLUSHING_UNMAP_APPLE, GL_FALSE);
	glBufferParameteriAPPLE(GL_ARRAY_BUFFER, GL_BUFFER_SERIALIZED_MODIFY_APPLE, GL_FALSE);	

 	glBindBuffer(GL_ARRAY_BUFFER,0);
	r->cur_base = 0;
	r->cur_size = 0;
	r->total_size = buffer_size;
	return r;
}//end LDrawDataStreamCreate


//========== LDrawDataStreamDestroy ==============================================
//
// Purpose:		Deallocate a data stream, clean up VBO.
//
//================================================================================
void LDrawDataStreamDestroy(struct LDrawDataStream * str)
{
	glDeleteBuffers(1,&str->vbo);
	free(str);
}//end LDrawDataStreamDestroy


//========== LDrawDataStreamMap ==================================================
//
// Purpose:		Maps a sub-section of the VBO into memory so that we can write
//				data to it.
//
// Notes:		The ptr returned is the start of our data, with size_desired
//				bytes available.
//
//				Data should always be written in consecutively in ascending order
//				and should never be read back or used for other calculations.
//				The memory we get may be write-combined memory and/or may be in
//				VRAM, so we will get maximum data throughput with consecutive
//				asecnding writes.
//
//================================================================================
void *	LDrawDataStreamMap(struct LDrawDataStream * str,int size_desired)
{
	assert(size_desired <= str->total_size);
	glBindBuffer(GL_ARRAY_BUFFER,str->vbo);
	
	int remaining = str->total_size - str->cur_base;
	if(remaining < size_desired)
	{
		glBufferData(GL_ARRAY_BUFFER, str->total_size, NULL, GL_DYNAMIC_DRAW);
		str->cur_base = 0;
		str->cur_size = 0;		
	}
	
	str->cur_size = size_desired;	
	char * r = (char *) glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
	glBindBuffer(GL_ARRAY_BUFFER,0);
	return r + str->cur_base;
}//end LDrawDataStreamMap


//========== LDrawDataStreamUnmap ================================================
//
// Purpose:		Commit data written to a mapping for use by the GPU.
//
// Notes:		This routine returns a ptr relative to the VBO that can be used
//				for OpenGL routines.  The underlying VBO is left 'current' for
//				use by glVertexAttribPointer.
//
//================================================================================
void *	LDrawDataStreamUnmap(struct LDrawDataStream * str)
{
	glBindBuffer(GL_ARRAY_BUFFER, str->vbo);
	glUnmapBuffer(GL_ARRAY_BUFFER);
	glFlushMappedBufferRangeAPPLE(GL_ARRAY_BUFFER,str->cur_base,str->cur_size);
	char * p = NULL;
	p += str->cur_base;
	str->cur_base += str->cur_size;
	str->cur_size = 0;
	return p;	
}//end LDrawDataStreamUnmap


#else

// Fallback: simply redo the VBO every time we remap it.  Regress to this to test
// for bugs in the streaming implementatin.

struct LDrawDataStream {
	GLuint			vbo;
};

//========== LDrawDataStreamCreate ===============================================
//
// Purpose:		Create a new data stream.
//
// Notes:		Buffer size is the size of the entire VBO allocation that
//				we will window.
//
//================================================================================
struct LDrawDataStream *	LDrawDataStreamCreate(int buffer_size)
{
	struct LDrawDataStream * r = (struct LDrawDataStream *) malloc(sizeof(struct LDrawDataStream));
	glGenBuffers(1,&r->vbo);
	return r;
}//end LDrawDataStreamCreate


//========== LDrawDataStreamDestroy ==============================================
//
// Purpose:		Deallocate a data stream, clean up VBO.
//
//================================================================================
void						LDrawDataStreamDestroy(struct LDrawDataStream * str)
{
	glDeleteBuffers(1,&str->vbo);
	free(str);
}//end LDrawDataStreamDestroy


//========== LDrawDataStreamMap ==================================================
//
// Purpose:		Maps a sub-section of the VBO into memory so that we can write
//				data to it.
//
// Notes:		The ptr returned is the start of our data, with size_desired
//				bytes available.
//
//				Data should always be written in consecutively in ascending order
//				and should never be read back or used for other calculations.
//				The memory we get may be write-combined memory and/or may be in
//				VRAM, so we will get maximum data throughput with consecutive
//				asecnding writes.
//
//================================================================================
void *	LDrawDataStreamMap(struct LDrawDataStream * str,int size_desired)
{
	glBindBuffer(GL_ARRAY_BUFFER,str->vbo);
	glBufferData(GL_ARRAY_BUFFER, size_desired, NULL, GL_DYNAMIC_DRAW);
	return glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
}//end LDrawDataStreamMap


//========== LDrawDataStreamUnmap ================================================
//
// Purpose:		Commit data written to a mapping for use by the GPU.
//
// Notes:		This routine returns a ptr relative to the VBO that can be used
//				for OpenGL routines.  The underlying VBO is left 'current' for
//				use by glVertexAttribPointer.
//
//================================================================================
void *	LDrawDataStreamUnmap(struct LDrawDataStream * str)
{
	glBindBuffer(GL_ARRAY_BUFFER, str->vbo);
	glUnmapBuffer(GL_ARRAY_BUFFER);
	return NULL;	
}//end LDrawDataStreamUnmap

#endif
