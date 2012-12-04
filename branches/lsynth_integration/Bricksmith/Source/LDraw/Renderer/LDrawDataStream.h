//
//  LDrawDataStream.h
//  Bricksmith
//
//  Created by bsupnik on 11/18/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
	The LDrawDataStream is an experimental implementation of Rob Barris'
	ideas on OpenGL vertex streaming: unlike a standard "orphan" VBO
	(where we buffer null to get a new buffer, map it, write data, unmap,
	use it) the stream works by windowing one large buffer: we map
	asynchronously, write part, flush part, use part, and then move down
	the buffer.  
	
	For many very small draw calls, this saves us the overhead
	of orphaning very small buffers (which the VBO doesn't cope with well).
	
	When the stream is mapped, we get a base ptr to write data into.
	When it is umapped, we get a base ptr relative to the VBO, and the VBO is
	made current for setting up glVertexAttribPointer.

*/

struct	LDrawDataStream;

struct LDrawDataStream *	LDrawDataStreamCreate(int buffer_size);
void						LDrawDataStreamDestroy(struct LDrawDataStream * str);

void *						LDrawDataStreamMap(struct LDrawDataStream * str,int size_desired);
void *						LDrawDataStreamUnmap(struct LDrawDataStream * str);


