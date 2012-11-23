//
//  LDrawDisplayList.h
//  Bricksmith
//
//  Created by bsupnik on 11/12/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

struct LDrawTextureSpec;

struct	LDrawDL;
struct	LDrawDLBuilder;
struct	LDrawDLSession;


struct LDrawDLBuilder *		LDrawDLBuilderCreate();
struct LDrawDL *			LDrawDLBuilderFinish(struct LDrawDLBuilder * ctx);

void						LDrawDLBuilderSetTex(struct LDrawDLBuilder * ctx, struct LDrawTextureSpec * spec);
void						LDrawDLBuilderAddTri(struct LDrawDLBuilder * ctx, const GLfloat v[9], GLfloat n[3], GLfloat c[4]);
void						LDrawDLBuilderAddQuad(struct LDrawDLBuilder * ctx, const GLfloat v[12], GLfloat n[3], GLfloat c[4]);
void						LDrawDLBuilderAddLine(struct LDrawDLBuilder * ctx, const GLfloat v[6], GLfloat n[3], GLfloat c[4]);

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
									
void						LDrawDLDestroy(struct LDrawDL * dl);
