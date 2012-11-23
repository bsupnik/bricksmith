//
//  LDrawDisplayList.m
//  Bricksmith
//
//  Created by bsupnik on 11/12/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawDisplayList.h"
#import "LDrawRenderer.h"
#import "LDrawBDPAllocator.h"
#import "LDrawShaderRenderer.h"
#import "LDrawDataStream.h"

#define USE_VAO 0

#define VERT_STRIDE 10
#define INST_CUTOFF 3
#define INST_MAX_COUNT (1024 * 128)
#define INST_RING_BUFFER_COUNT 4
#define MODE_FOR_INST_STREAM GL_DYNAMIC_DRAW

#define INST_STREAM_SIZE (1024 * 1024 * 32)

enum {
	dl_has_alpha = 1,
	dl_has_meta = 2,
	dl_has_tex = 4
};

static void applyMatrix(GLfloat dst[4], const GLfloat m[16], const GLfloat v[4])
{
	dst[0] = v[0] * m[0] + v[1] * m[4] + v[2] * m[8] + v[3] * m[12];
	dst[1] = v[0] * m[1] + v[1] * m[5] + v[2] * m[9] + v[3] * m[13];
	dst[2] = v[0] * m[2] + v[1] * m[6] + v[2] * m[10] + v[3] * m[14];
	dst[3] = v[0] * m[3] + v[1] * m[7] + v[2] * m[11] + v[3] * m[15];
}


static void copy_vec3(GLfloat d[3], const GLfloat s[3]) { d[0] = s[0]; d[1] = s[1]; d[2] = s[2];				}
static void copy_vec4(GLfloat d[4], const GLfloat s[4]) { d[0] = s[0]; d[1] = s[1]; d[2] = s[2]; d[3] = s[3]; }

//static struct LDrawDataStream *	inst_vbo = NULL;
static GLuint	inst_vbo_ring[INST_RING_BUFFER_COUNT] = { 0 };
static int inst_ring_last = 0;

struct LDrawDLPerTex {
	struct LDrawTextureSpec	spec;
	GLuint					line_off;
	GLuint					line_count;
	GLuint					tri_off;
	GLuint					tri_count;
	GLuint					quad_off;
	GLuint					quad_count;
};

struct LDrawDLInstance {
	struct LDrawDLInstance *next;
	GLfloat					color[4];
	GLfloat					comp[4];
	GLfloat					transform[16];
};

struct LDrawDL {
	struct LDrawDL *		next_dl;
	struct LDrawDLInstance *instance_head;
	struct LDrawDLInstance *instance_tail;
	int						instance_count;
	int						flags;
	GLuint					vbo;
#if USE_VAO
	GLuint					vao;
#endif	
	int						tex_count;
	struct LDrawDLPerTex	texes[0];		// Struct is variable sized based on actual tex_count.
};

struct LDrawDLSegment {
	GLuint					vbo;
	struct LDrawDLPerTex *	dl;
	float *					inst_base;
	int						inst_count;
};
	

struct LDrawDLSortedInstanceLink {
	union {
		struct LDrawDLSortedInstanceLink *	next;
		float								eval;
	};
	struct	LDrawDL *						dl;
	struct LDrawTextureSpec					spec;
	GLfloat									color[4];
	GLfloat									comp[4];
	GLfloat									transform[16];
};

struct LDrawDLSession {
	struct LDrawBDP *				alloc;
	struct LDrawDL *				dl_head;
	int								dl_count;
	struct LDrawDLSortedInstanceLink *	sorted_head;
	int								sort_count;
	GLfloat							model_view[16];		// modelview matrix of base transform
	GLuint							inst_ring;
};



// ---------------------------------------------------------------------------------------------------------------------


struct	LDrawDLBuilderVertexLink {
	struct LDrawDLBuilderVertexLink * next;
	int		vcount;
	float	data[0];
};

struct LDrawDLBuilderPerTex {
	struct LDrawTextureSpec				spec;
	struct LDrawDLBuilderPerTex *		next;
	struct LDrawDLBuilderVertexLink *	tri_head;
	struct LDrawDLBuilderVertexLink *	tri_tail;
	struct LDrawDLBuilderVertexLink *	quad_head;
	struct LDrawDLBuilderVertexLink *	quad_tail;
	struct LDrawDLBuilderVertexLink *	line_head;
	struct LDrawDLBuilderVertexLink *	line_tail;
};

struct	LDrawDLBuilder {
	int								flags;
	struct LDrawBDP *				alloc;
	struct LDrawDLBuilderPerTex *	head;
	struct LDrawDLBuilderPerTex *	cur;
};

// ---------------------------------------------------------------------------------------------------------------------


struct LDrawDLBuilder *		LDrawDLBuilderCreate()
{
	struct LDrawBDP * alloc = LDrawBDPCreate();

	struct LDrawDLBuilderPerTex * untex = (struct LDrawDLBuilderPerTex *) LDrawBDPAllocate(alloc,sizeof(struct LDrawDLBuilderPerTex));
	memset(untex,0,sizeof(struct LDrawDLBuilderPerTex));

	struct LDrawDLBuilder * bld = (struct LDrawDLBuilder *) LDrawBDPAllocate(alloc,sizeof(struct LDrawDLBuilder));
	bld->cur = bld->head = untex;
	
	bld->alloc = alloc;
	bld->flags = 0;
	
	return bld;
}

void						LDrawDLBuilderSetTex(struct LDrawDLBuilder * ctx, struct LDrawTextureSpec * spec)
{
	struct LDrawDLBuilderPerTex * prev = ctx->head;
	for(ctx->cur = ctx->head; ctx->cur; ctx->cur = ctx->cur->next)
	{
		if(memcmp(spec,&ctx->cur->spec,sizeof(struct LDrawTextureSpec)) == 0)
			break;
		prev = ctx->cur;
	}
	if(ctx->cur == NULL)
	{
		struct LDrawDLBuilderPerTex * new_tex = (struct LDrawDLBuilderPerTex *) LDrawBDPAllocate(ctx->alloc,sizeof(struct LDrawDLBuilderPerTex));
		memset(new_tex,0,sizeof(struct LDrawDLBuilderPerTex));
		memcpy(&new_tex->spec,spec,sizeof(struct LDrawTextureSpec));
		prev->next = new_tex;
		ctx->cur = new_tex;
	}
}

void						LDrawDLBuilderAddTri(struct LDrawDLBuilder * ctx, const GLfloat v[9], GLfloat n[3], GLfloat c[4])
{
		 if(c[3] == 0.0f)	ctx->flags |= dl_has_meta;
	else if(c[3] != 1.0f)	ctx->flags |= dl_has_alpha;
	
	int i;
	struct LDrawDLBuilderVertexLink * nl = (struct LDrawDLBuilderVertexLink *) LDrawBDPAllocate(ctx->alloc, sizeof(struct LDrawDLBuilderVertexLink) + sizeof(GLfloat) * VERT_STRIDE * 3);
	nl->next = NULL;
	nl->vcount = 3;
	for(i = 0; i < 3; ++i)
	{
		copy_vec3(nl->data+VERT_STRIDE*i  ,v+i*3);
		copy_vec3(nl->data+VERT_STRIDE*i+3,n    );
		copy_vec4(nl->data+VERT_STRIDE*i+6,c    );
	}
	
	if(ctx->cur->tri_tail)
	{
		ctx->cur->tri_tail->next = nl;
		ctx->cur->tri_tail = nl;
	}
	else
	{
		ctx->cur->tri_head = nl;
		ctx->cur->tri_tail = nl;
	}
}

void						LDrawDLBuilderAddQuad(struct LDrawDLBuilder * ctx, const GLfloat v[12], GLfloat n[3], GLfloat c[4])
{
		 if(c[3] == 0.0f)	ctx->flags |= dl_has_meta;
	else if(c[3] != 1.0f)	ctx->flags |= dl_has_alpha;

	int i;
	struct LDrawDLBuilderVertexLink * nl = (struct LDrawDLBuilderVertexLink *) LDrawBDPAllocate(ctx->alloc, sizeof(struct LDrawDLBuilderVertexLink) + sizeof(GLfloat) * VERT_STRIDE * 4);
	nl->next = NULL;
	nl->vcount = 4;
	for(i = 0; i < 4; ++i)
	{
		copy_vec3(nl->data+VERT_STRIDE*i  ,v+i*3);
		copy_vec3(nl->data+VERT_STRIDE*i+3,n    );
		copy_vec4(nl->data+VERT_STRIDE*i+6,c    );
	}
	
	if(ctx->cur->quad_tail)
	{
		ctx->cur->quad_tail->next = nl;
		ctx->cur->quad_tail = nl;
	}
	else
	{
		ctx->cur->quad_head = nl;
		ctx->cur->quad_tail = nl;
	}
}

void						LDrawDLBuilderAddLine(struct LDrawDLBuilder * ctx, const GLfloat v[6], GLfloat n[3], GLfloat c[4])
{
		 if(c[3] == 0.0f)	ctx->flags |= dl_has_meta;
	else if(c[3] != 1.0f)	ctx->flags |= dl_has_alpha;

	int i;
	struct LDrawDLBuilderVertexLink * nl = (struct LDrawDLBuilderVertexLink *) LDrawBDPAllocate(ctx->alloc, sizeof(struct LDrawDLBuilderVertexLink) + sizeof(GLfloat) * VERT_STRIDE * 2);
	nl->next = NULL;
	nl->vcount = 2;
	for(i = 0; i < 2; ++i)
	{
		copy_vec3(nl->data+VERT_STRIDE*i  ,v+i*3);
		copy_vec3(nl->data+VERT_STRIDE*i+3,n    );
		copy_vec4(nl->data+VERT_STRIDE*i+6,c    );
	}
	
	if(ctx->cur->line_tail)
	{
		ctx->cur->line_tail->next = nl;
		ctx->cur->line_tail = nl;
	}
	else
	{
		ctx->cur->line_head = nl;
		ctx->cur->line_tail = nl;
	}
}

struct LDrawDL *			LDrawDLBuilderFinish(struct LDrawDLBuilder * ctx)
{
	int total_texes = 0;
	int total_vertices = 0;
	
	struct LDrawDLBuilderVertexLink * l;
	struct LDrawDLBuilderPerTex * s;
	for(s = ctx->head; s; s = s->next)
	{
		if(s->tri_head || s->line_head || s->quad_head)
			++total_texes;
		for(l = s->tri_head; l; l = l->next)
			total_vertices += l->vcount;
		for(l = s->quad_head; l; l = l->next)
			total_vertices += l->vcount;
		for(l = s->line_head; l; l = l->next)
			total_vertices += l->vcount;
	}
	if(total_texes == 0)
	{
		LDrawBDPDestroy(ctx->alloc);
		return NULL;
	}
	
	struct LDrawDL * dl = (struct LDrawDL *) malloc(sizeof(struct LDrawDL) + sizeof(struct LDrawDLPerTex) * total_texes);
	
	dl->next_dl = NULL;
	dl->instance_head = NULL;
	dl->instance_tail = NULL;
	dl->instance_count = 0;
	
	dl->tex_count = total_texes;
	
	glGenBuffers(1,&dl->vbo);
#if USE_VAO	
	glGenVertexArraysAPPLE(1,&dl->vao);
#endif	
	glBindBuffer(GL_ARRAY_BUFFER, dl->vbo);
	glBufferData(GL_ARRAY_BUFFER, total_vertices * sizeof(GLfloat) * VERT_STRIDE, NULL, GL_STATIC_DRAW);
	GLfloat * buf_ptr = (GLfloat *) glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
	int cur_v = 0;
	struct LDrawDLPerTex * cur_tex = dl->texes;
	
	dl->flags = ctx->flags;
	
	for(s = ctx->head; s; s = s->next)
	{
		if(s->tri_head == NULL && s->line_head == NULL && s->quad_head == NULL)
			continue;
		if(s->spec.tex_obj != 0)
			dl->flags |= dl_has_tex;
		memcpy(&cur_tex->spec, &s->spec, sizeof(struct LDrawTextureSpec));
		cur_tex->line_off = cur_v;
		cur_tex->line_count = 0;

		for(l = s->line_head; l; l = l->next)
		{
			memcpy(buf_ptr,l->data,VERT_STRIDE * sizeof(GLfloat) * l->vcount);
			cur_tex->line_count += l->vcount;
			cur_v += l->vcount;
			buf_ptr += (VERT_STRIDE * l->vcount);
		}

		cur_tex->tri_off = cur_v;
		cur_tex->tri_count = 0;

		for(l = s->tri_head; l; l = l->next)
		{
			memcpy(buf_ptr,l->data,VERT_STRIDE * sizeof(GLfloat) * l->vcount);
			cur_tex->tri_count += l->vcount;
			cur_v += l->vcount;
			buf_ptr += (VERT_STRIDE * l->vcount);
		}

		cur_tex->quad_off = cur_v;
		cur_tex->quad_count = 0;

		for(l = s->quad_head; l; l = l->next)
		{
			memcpy(buf_ptr,l->data,VERT_STRIDE * sizeof(GLfloat) * l->vcount);
			cur_tex->quad_count += l->vcount;
			cur_v += l->vcount;
			buf_ptr += (VERT_STRIDE * l->vcount);
		}

		++cur_tex;
	}
	
	glUnmapBuffer(GL_ARRAY_BUFFER);
	glBindBuffer(GL_ARRAY_BUFFER,0);

#if USE_VAO	
	GLfloat * p = NULL;
	glBindVertexArrayAPPLE(dl->vao);
	glBindBuffer(GL_ARRAY_BUFFER,dl->vbo);
	glEnableVertexAttribArray(attr_position);
	glEnableVertexAttribArray(attr_normal);
	glEnableVertexAttribArray(attr_color);
	glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p);
	glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+3);
	glVertexAttribPointer(attr_color, 4, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+6);
	glBindBuffer(GL_ARRAY_BUFFER,0);
	glBindVertexArrayAPPLE(0);
#endif
	LDrawBDPDestroy(ctx->alloc);
	
	return dl;
}

static void setup_tex_spec(struct LDrawTextureSpec * spec)
{
	if(spec && spec->tex_obj)
	{
		glVertexAttrib1f(attr_texture_mix,1.0f);
		glBindTexture(GL_TEXTURE_2D, spec->tex_obj);		
		glTexGenfv(GL_S, GL_OBJECT_PLANE, spec->plane_s);
		glTexGenfv(GL_T, GL_OBJECT_PLANE, spec->plane_t);				
	}
	else
	{
		glVertexAttrib1f(attr_texture_mix,0.0f);
//		glBindTexture(GL_TEXTURE_2D, 0);		
	}
}

struct LDrawDLSession *		LDrawDLSessionCreate(const GLfloat model_view[3])
{
	struct LDrawBDP * alloc = LDrawBDPCreate();
	struct LDrawDLSession * session = (struct LDrawDLSession *) LDrawBDPAllocate(alloc,sizeof(struct LDrawDLSession));
	session->alloc = alloc;
	session->dl_head = NULL;
	session->dl_count = 0;
	session->sorted_head = NULL;
	session->sort_count = 0;
	memcpy(session->model_view,model_view,sizeof(GLfloat)*16);
	session->inst_ring = inst_ring_last;
	inst_ring_last = (inst_ring_last+1)%INST_RING_BUFFER_COUNT;
	//printf("----Session start %p----\n", session);
	return session;
}

static int compare_sorted_link(const void * lhs, const void * rhs)
{
	const struct LDrawDLSortedInstanceLink * a = (const struct LDrawDLSortedInstanceLink *) lhs;
	const struct LDrawDLSortedInstanceLink * b = (const struct LDrawDLSortedInstanceLink *) rhs;
	return a->eval - b->eval;
}

void						LDrawDLSessionDrawAndDestroy(struct LDrawDLSession * session)
{
	struct LDrawDLInstance * inst;
	struct LDrawDL * dl;

	//printf("Draw session %p\n", session);

	if(session->dl_head)
	{

		struct LDrawDLSegment * segments = (struct LDrawDLSegment *) LDrawBDPAllocate(session->alloc, sizeof(struct LDrawDLSegment) * session->dl_count);
		struct LDrawDLSegment * cur_segment = segments;

		if(inst_vbo_ring[session->inst_ring] == 0)
			glGenBuffers(1,&inst_vbo_ring[session->inst_ring]);
		glBindBuffer(GL_ARRAY_BUFFER, inst_vbo_ring[session->inst_ring]);
		glBufferData(GL_ARRAY_BUFFER,INST_MAX_COUNT * sizeof(GLfloat)*24, NULL, GL_DYNAMIC_DRAW);
		GLfloat * inst_base = (GLfloat *) glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
		GLfloat * inst_data = inst_base;
		int		  inst_remain = INST_MAX_COUNT;

		while(session->dl_head)
		{
			dl = session->dl_head;

			if(dl->instance_count >= INST_CUTOFF && inst_remain >= dl->instance_count)
			{
				cur_segment->vbo = dl->vbo;
				cur_segment->dl = &dl->texes[0];
				cur_segment->inst_base = NULL; 
				cur_segment->inst_base += (inst_data - inst_base);
				cur_segment->inst_count = dl->instance_count;
			
				for (inst = dl->instance_head; inst; inst = inst->next)
				{			
					copy_vec4(inst_data,inst->color);
					copy_vec4(inst_data+4,inst->comp);
					inst_data[8] = inst->transform[0];
					inst_data[9] = inst->transform[4];
					inst_data[10] = inst->transform[8];
					inst_data[11] = inst->transform[12];
					inst_data[12] = inst->transform[1];
					inst_data[13] = inst->transform[5];
					inst_data[14] = inst->transform[9];
					inst_data[15] = inst->transform[13];
					inst_data[16] = inst->transform[2];
					inst_data[17] = inst->transform[6];
					inst_data[18] = inst->transform[10];
					inst_data[19] = inst->transform[14];
					inst_data[20] = inst->transform[3];
					inst_data[21] = inst->transform[7];
					inst_data[22] = inst->transform[11];
					inst_data[23] = inst->transform[15];
					inst_data += 24;
					--inst_remain;
				}
				++cur_segment;
			}
			else
			{
				//printf("\tDraw dl %p\n", dl);
				#if USE_VAO
					glBindVertexArrayAPPLE(dl->vao);
				#else
					glBindBuffer(GL_ARRAY_BUFFER,dl->vbo);
					float * p = NULL;
					glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p);
					glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+3);
					glVertexAttribPointer(attr_color, 4, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+6);
				#endif

				for(inst = dl->instance_head; inst; inst = inst->next)
				{
		//			printf("\t\tDraw inst %p\n", inst);
				
					int i;
					for(i = 0; i < 4; ++i)
						glVertexAttrib4f(attr_transform_x+i,inst->transform[i],inst->transform[4+i],inst->transform[8+i],inst->transform[12+i]);
					glVertexAttrib4fv(attr_color_current, inst->color);
					glVertexAttrib4fv(attr_color_compliment, inst->comp);
			
					struct LDrawDLPerTex * tptr = dl->texes;
					
					if(tptr->tri_count)
						glDrawArrays(GL_TRIANGLES,tptr->tri_off,tptr->tri_count);
					if(tptr->quad_count)
						glDrawArrays(GL_QUADS,tptr->quad_off,tptr->quad_count);
					if(tptr->line_count)
						glDrawArrays(GL_LINES,tptr->line_off,tptr->line_count);
				}
			}
			
			//printf("\tclean dl %p\n", dl);
			dl->instance_head = dl->instance_tail = NULL;
			dl->instance_count = 0;
			session->dl_head = dl->next_dl;
			dl->next_dl = NULL;		
		}

		glBindBuffer(GL_ARRAY_BUFFER, inst_vbo_ring[session->inst_ring]);
		glUnmapBuffer(GL_ARRAY_BUFFER);


		if(segments != cur_segment)
		{
			glEnableVertexAttribArray(attr_transform_x);
			glEnableVertexAttribArray(attr_transform_y);
			glEnableVertexAttribArray(attr_transform_z);
			glEnableVertexAttribArray(attr_transform_w);
			glEnableVertexAttribArray(attr_color_current);
			glEnableVertexAttribArray(attr_color_compliment);
			glVertexAttribDivisorARB(attr_transform_x,1);
			glVertexAttribDivisorARB(attr_transform_y,1);
			glVertexAttribDivisorARB(attr_transform_z,1);
			glVertexAttribDivisorARB(attr_transform_w,1);
			glVertexAttribDivisorARB(attr_color_current,1);
			glVertexAttribDivisorARB(attr_color_compliment,1);

			struct LDrawDLSegment * s;
			for(s = segments; s < cur_segment; ++s)
			{

				glBindBuffer(GL_ARRAY_BUFFER,s->vbo);
				float * p = NULL;
				glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p);
				glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+3);
				glVertexAttribPointer(attr_color, 4, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+6);

				glBindBuffer(GL_ARRAY_BUFFER,inst_vbo_ring[session->inst_ring]);

				p = s->inst_base;
				glVertexAttribPointer(attr_color_current, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p  );
				glVertexAttribPointer(attr_color_compliment, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p+4);
				glVertexAttribPointer(attr_transform_x, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p+8);
				glVertexAttribPointer(attr_transform_y, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p+12);
				glVertexAttribPointer(attr_transform_z, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p+16);
				glVertexAttribPointer(attr_transform_w, 4, GL_FLOAT, GL_FALSE, 24 * sizeof(GLfloat), p+20);

				if(s->dl->tri_count)
					glDrawArraysInstancedARB(GL_TRIANGLES,s->dl->tri_off,s->dl->tri_count, s->inst_count);
				if(s->dl->quad_count)
					glDrawArraysInstancedARB(GL_QUADS,s->dl->quad_off,s->dl->quad_count, s->inst_count);
				if(s->dl->line_count)
					glDrawArraysInstancedARB(GL_LINES,s->dl->line_off,s->dl->line_count, s->inst_count);
			}

			glDisableVertexAttribArray(attr_transform_x);
			glDisableVertexAttribArray(attr_transform_y);
			glDisableVertexAttribArray(attr_transform_z);
			glDisableVertexAttribArray(attr_transform_w);
			glDisableVertexAttribArray(attr_color_current);
			glDisableVertexAttribArray(attr_color_compliment);
			glVertexAttribDivisorARB(attr_transform_x,0);
			glVertexAttribDivisorARB(attr_transform_y,0);
			glVertexAttribDivisorARB(attr_transform_z,0);
			glVertexAttribDivisorARB(attr_transform_w,0);
			glVertexAttribDivisorARB(attr_color_current,0);
			glVertexAttribDivisorARB(attr_color_compliment,0);

		}

	}


	
	
	

	struct LDrawDLSortedInstanceLink * l;
	if(session->sorted_head)
	{
		struct LDrawDLSortedInstanceLink * arr = (struct LDrawDLSortedInstanceLink *) LDrawBDPAllocate(session->alloc,sizeof(struct LDrawDLSortedInstanceLink) * session->sort_count);
		struct LDrawDLSortedInstanceLink * p = arr;		
		for(l = session->sorted_head; l; l = l->next)
		{
			float v[4] = { 
				l->transform[12], 
				l->transform[13],
				l->transform[14], 1.0f };
			memcpy(p,l,sizeof(struct LDrawDLSortedInstanceLink));
			GLfloat mvp[16];
			glGetFloatv(GL_MODELVIEW_MATRIX,mvp);
			float v_eye[4];
			applyMatrix(v_eye,mvp,v);
			p->eval = v_eye[2];
			++p;
		}
		
		qsort(arr,session->sort_count,sizeof(struct LDrawDLSortedInstanceLink),compare_sorted_link);
		
		l = arr;
		int lc;
		for(lc = 0; lc < session->sort_count; ++lc)
		{			
			int i;
			for(i = 0; i < 4; ++i)
				glVertexAttrib4f(attr_transform_x+i,l->transform[i],l->transform[4+i],l->transform[8+i],l->transform[12+i]);
			glVertexAttrib4fv(attr_color_current, l->color);
//			glVertexAttrib4f(attr_color_current,(float) lc / (float) session->sort_count,0,0,1);
			glVertexAttrib4fv(attr_color_compliment, l->comp);
			
			dl = l->dl;
			#if VAO
			glBindVertexArrayAPPLE(dl->vao);
			#else
			glBindBuffer(GL_ARRAY_BUFFER,dl->vbo);
			float * p = NULL;
			glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p);
			glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+3);
			glVertexAttribPointer(attr_color, 4, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+6);
			#endif
			
			struct LDrawDLPerTex * tptr = dl->texes;
			
			int t;
			for(t = 0; t < dl->tex_count; ++t, ++tptr)
			{
				if(tptr->spec.tex_obj)
				{
					setup_tex_spec(&tptr->spec);
				}
				else 
					setup_tex_spec(&l->spec);
				
				if(tptr->tri_count)
					glDrawArrays(GL_TRIANGLES,tptr->tri_off,tptr->tri_count);
				if(tptr->quad_count)
					glDrawArrays(GL_QUADS,tptr->quad_off,tptr->quad_count);
				if(tptr->line_count)
					glDrawArrays(GL_LINES,tptr->line_off,tptr->line_count);
			}
			++l;
		}
	}
	
	
	
	
	
	#if USE_VAO
	glBindVertexArrayAPPLE(0);
	#else
	glBindBuffer(GL_ARRAY_BUFFER,0);
	#endif

//	if(session->inst_vbo)
//	{
//		glDeleteBuffers(1,&session->inst_vbo);
//	}

	LDrawBDPDestroy(session->alloc);
	//printf("----Session DONE %p----\n",session);
}


void LDrawDLDraw(
									struct LDrawDLSession *			session,
									struct LDrawDL *				dl, 
									struct LDrawTextureSpec *		spec,
									const GLfloat 					cur_color[4],
									const GLfloat 					cmp_color[4],
									const GLfloat					transform[16],
									int								draw_now)
{
	if(!draw_now)
	{
		int want_radial_sort = (dl->flags & dl_has_alpha) || ((dl->flags & dl_has_meta) && (cur_color[3] < 1.0f || cmp_color[3] < 1.0f));
		if(want_radial_sort)
		{
			struct LDrawDLSortedInstanceLink * link = LDrawBDPAllocate(session->alloc, sizeof(struct LDrawDLSortedInstanceLink));
			link->next = session->sorted_head;
			session->sorted_head = link;
			link->dl = dl;
			memcpy(link->color,cur_color,sizeof(GLfloat)*4);
			memcpy(link->comp,cmp_color,sizeof(GLfloat)*4);
			memcpy(link->transform,transform,sizeof(GLfloat)*16);
			session->sort_count++;
			if(spec)
				memcpy(&link->spec,spec,sizeof(struct LDrawTextureSpec));
			else
				memset(&link->spec,0,sizeof(struct LDrawTextureSpec));
			return;
		}

		if((spec == NULL || spec->tex_obj == 0) && (dl->flags & dl_has_tex) == 0)
		{
			//printf("\t\t\tseshead=%p beginDL %p: next=%p, head=%p, tail=%p\n", session->dl_head, dl, dl->next_dl, dl->instance_head, dl->instance_tail);
			//assert(dl->next_dl == NULL || session->dl_head != NULL);
			
			if(dl->instance_head == NULL)
			{
				session->dl_count++;
				dl->next_dl = session->dl_head;
				session->dl_head = dl;
			}
			
			struct LDrawDLInstance * inst = (struct LDrawDLInstance *) LDrawBDPAllocate(session->alloc,sizeof(struct LDrawDLInstance));
			{
				if(dl->instance_head == NULL)
				{
					//printf("\t\tFirst Q of DL %p inst %p\n",dl,inst);		
					dl->instance_head = inst;
					dl->instance_tail = inst;				
				}
				else
				{
					//printf("\t\tsubsequent Q of DL %p inst %p\n",dl,inst);		
					dl->instance_tail->next = inst;
					dl->instance_tail = inst;
				}
				inst->next = NULL;
				++dl->instance_count;

				memcpy(inst->color,cur_color,sizeof(GLfloat)*4);
				memcpy(inst->comp,cmp_color,sizeof(GLfloat)*4);
				memcpy(inst->transform,transform,sizeof(GLfloat)*16);
			}
			//printf("\t\t\tendDL %p: next=%p, head=%p, tail=%p\n", dl, dl->next_dl, dl->instance_head, dl->instance_tail);
			
			return;
		}
	}
	
	int i;
	for(i = 0; i < 4; ++i)
		glVertexAttrib4f(attr_transform_x+i,transform[i],transform[4+i],transform[8+i],transform[12+i]);
	glVertexAttrib4fv(attr_color_current, cur_color);
	glVertexAttrib4fv(attr_color_compliment, cmp_color);
	
	assert(dl->tex_count > 0);
	#if VAO
	glBindVertexArrayAPPLE(dl->vao);
	#else
	glBindBuffer(GL_ARRAY_BUFFER,dl->vbo);
	float * p = NULL;
	glVertexAttribPointer(attr_position, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p);
	glVertexAttribPointer(attr_normal, 3, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+3);
	glVertexAttribPointer(attr_color, 4, GL_FLOAT, GL_FALSE, VERT_STRIDE * sizeof(GLfloat), p+6);
	#endif
	
	struct LDrawDLPerTex * tptr = dl->texes;
	
	if(dl->tex_count == 1 && tptr->spec.tex_obj == 0 && spec == NULL)
	{
		if(tptr->tri_count)
			glDrawArrays(GL_TRIANGLES,tptr->tri_off,tptr->tri_count);
		if(tptr->quad_count)
			glDrawArrays(GL_QUADS,tptr->quad_off,tptr->quad_count);
		if(tptr->line_count)
			glDrawArrays(GL_LINES,tptr->line_off,tptr->line_count);
	}
	else
	{
		int t;
		for(t = 0; t < dl->tex_count; ++t, ++tptr)
		{
			if(tptr->spec.tex_obj)
			{
				setup_tex_spec(&tptr->spec);
			}
			else 
				setup_tex_spec(spec);
			
			if(tptr->tri_count)
				glDrawArrays(GL_TRIANGLES,tptr->tri_off,tptr->tri_count);
			if(tptr->quad_count)
				glDrawArrays(GL_QUADS,tptr->quad_off,tptr->quad_count);
			if(tptr->line_count)
				glDrawArrays(GL_LINES,tptr->line_off,tptr->line_count);
		}

		setup_tex_spec(spec);
	}
}
	
void LDrawDLDestroy(struct LDrawDL * dl)
{
	assert(dl->instance_head == NULL);
	#if USE_VAO
	glDeleteVertexArraysAPPLE(1,&dl->vao);
	#else
	glDeleteBuffers(1,&dl->vbo);
	#endif
	free(dl);
}
