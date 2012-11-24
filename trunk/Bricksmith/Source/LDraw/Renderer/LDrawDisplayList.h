//
//  LDrawDisplayList.h
//  Bricksmith
//
//  Created by bsupnik on 11/12/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*

	LDrawDisplayList - THEORY OF OPERATION
	
	This API provides display-list-like capabilities for a GL 2.0 shader/VBO-based renderer.
	Our display lists consist of a mesh of lines, quads, and tris, some of which may be textured,
	and all of which have normals and colors.  The colors are straight RGBA tuples - the color stack
	behavior that we get in the shader renderer comes from the higher level code.
	
	Unlike the GL, we can open more than one display list for construction at a time - a 
	struct LDrawDLBuilder * opaque ptr gives us a context for DL creation.  When we close the
	builder we get a DL, or null if the DL would have been empty.  
	
	SESSIONS
	
	We draw one or more DLs using a drawing 'session', which is also an opaque struct ptr (just
	like the rest of the API).  The session accumulates requests to draw with given color/transform
	texture state and performs optimizations to improve drawing performance.  When the session is
	destroyed, any 'deferred' drawing takes place.
	
	Besides attempting to use hw instancing, the session will also draw translucent DLs last in 
	back-to-front order to improve transparency performance.

	FEATURES
	
	The DL API will draw translucent geomtry back-to-front ordered (the DLs are reordered, not the
	geometry in the DLs).  The API dynamically detects translucency from passed in colors, including
	meta-colors  (Meta colors are assumed to have alpha=0.0f).
	
	The API will draw non-textured, non-translucent geometry via instancing, either 
	attribute-instancing for small count or hardware instancing with attrib-array-divisor for large
	numbers of bricks.	

 */

// Forwrd declared from basic renderer API.
struct LDrawTextureSpec;

// Opaque structures we use as "handles".
struct	LDrawDL;
struct	LDrawDLBuilder;
struct	LDrawDLSession;

// Display list creation API.
struct LDrawDLBuilder *		LDrawDLBuilderCreate();
struct LDrawDL *			LDrawDLBuilderFinish(struct LDrawDLBuilder * ctx);
void						LDrawDLDestroy(struct LDrawDL * dl);

// Display list mesh accumulation APIs.
void						LDrawDLBuilderSetTex(struct LDrawDLBuilder * ctx, struct LDrawTextureSpec * spec);
void						LDrawDLBuilderAddTri(struct LDrawDLBuilder * ctx, const GLfloat v[9], GLfloat n[3], GLfloat c[4]);
void						LDrawDLBuilderAddQuad(struct LDrawDLBuilder * ctx, const GLfloat v[12], GLfloat n[3], GLfloat c[4]);
void						LDrawDLBuilderAddLine(struct LDrawDLBuilder * ctx, const GLfloat v[6], GLfloat n[3], GLfloat c[4]);

// Session/drawing APIs
struct LDrawDLSession *		LDrawDLSessionCreate(const GLfloat model_view[16]);
void						LDrawDLSessionDrawAndDestroy(struct LDrawDLSession * session);
void						LDrawDLDraw(
									struct LDrawDLSession *			session,
									struct LDrawDL *				dl, 
									struct LDrawTextureSpec *		spec,
									const GLfloat 					cur_color[4],
									const GLfloat 					cmp_color[4],
									const GLfloat					transform[16],
									int								draw_now);
									
