/*
 *  MeshSmooth.c
 *  Bricksmith
 *
 *  Created by bsupnik on 3/10/13.
 *  Copyright 2013 __MyCompanyName__. All rights reserved.
 *
 */

#include "MeshSmooth.h"

#define UNKNOWN_FACE ((struct Face *) -1)

#define WANT_SNAP 0
#define SNAP_PRECISION 64.0

#define WANT_CREASE 1

// This causes us to smooth normals against BFC-flipped tris.
// An app like BrickSmith that ignores BFC and just draws two-sided
// pretty much has to 
#define WANT_INVERTS 1

// This puts the normals into the color of each part - useful for
// visualizing normal bugs.
#define DEBUG_SHOW_NORMALS_AS_COLOR 0

/*
todo
	- index faces and measure perf
	- index lines too if faces are a win
*/


static int compare_points(const float * __restrict p1, const float * __restrict p2)
{
	// The std c lib rule is that we are fundamentally returning p1-p2.
	// So when p1 < p2, we return a negative number, etc.
	if(p1[0] < p2[0])	return -1;
	if(p1[0] > p2[0])	return  1;

	if(p1[1] < p2[1])	return -1;
	if(p1[1] > p2[1])	return  1;

	if(p1[2] < p2[2])	return -1;
	if(p1[2] > p2[2])	return  1;
	
	return 0;
}

static int compare_vertices(const struct Vertex * __restrict v1, const struct Vertex * __restrict v2)
{
	if(v1->location[0] < v2->location[0])	return -1;
	if(v1->location[0] > v2->location[0])	return  1;
	if(v1->location[1] < v2->location[1])	return -1;
	if(v1->location[1] > v2->location[1])	return  1;
	if(v1->location[2] < v2->location[2])	return -1;
	if(v1->location[2] > v2->location[2])	return  1;

	if(v1->normal[0] < v2->normal[0])	return -1;
	if(v1->normal[0] > v2->normal[0])	return  1;
	if(v1->normal[1] < v2->normal[1])	return -1;
	if(v1->normal[1] > v2->normal[1])	return  1;
	if(v1->normal[2] < v2->normal[2])	return -1;
	if(v1->normal[2] > v2->normal[2])	return  1;

	if(v1->color[0] < v2->color[0])	return -1;
	if(v1->color[0] > v2->color[0])	return  1;
	if(v1->color[1] < v2->color[1])	return -1;
	if(v1->color[1] > v2->color[1])	return  1;
	if(v1->color[2] < v2->color[2])	return -1;
	if(v1->color[2] > v2->color[2])	return  1;
	if(v1->color[3] < v2->color[3])	return -1;
	if(v1->color[3] > v2->color[3])	return  1;	
	
	return 0;
	
}

static void swap_blocks(void * __restrict a, void * __restrict b, int num_words)
{
	assert(a != b);
	int * __restrict aa = (int *) a;
	int * __restrict bb = (int *) b;
	while(num_words--)
	{
		int t = *aa;
		*aa = *bb;
		*bb = t;
		++aa;
		++bb;
	}	
}

static void bubble_sort_10(struct Vertex * items, int count)
{
	int swapped, i;
	do {
		int high_count = 0;
		swapped = 0;
		for(i = 1; i < count; ++i)
		if(compare_vertices(items+i-1,items+i) > 0)
		{
			swap_blocks(items+i-1,items+i,sizeof(struct Vertex) / sizeof(int));
			swapped = true;
			high_count = i;
		}
		count = high_count;
	} while (swapped);
}

static void sort_vertices_10(struct Vertex * base, int count)
{
	bubble_sort_10(base,count);
}

static void quickSort_3(struct Vertex * arr, int left, int right) 
{
	int i = left, j = right;

	struct Vertex * pivot_ptr = arr + (left + right) / 2;
	float pivot[3] = { pivot_ptr->location[0], pivot_ptr->location[1], pivot_ptr->location[2] };
	
	/* partition */

	while (i <= j) 
	{

		while(compare_points(arr[i].location,pivot) < 0)
			++i;

		while(compare_points(arr[j].location,pivot) > 0)
			--j;

		if (i <= j) 
		{
			if(i != j)
				swap_blocks(arr+i,arr+j,sizeof(struct Vertex) / sizeof(int));
			++i;
			--j;
		}
	}

	if (left < j)
		quickSort_3(arr, left, j);

	if (i < right)
		quickSort_3(arr, i, right);

}

static void sort_vertices_3(struct Vertex * base, int count)
{
	quickSort_3(base,0,count-1);
}

static void range_for_point(struct Vertex * base, int count, struct Vertex ** begin, struct Vertex ** end, const float p[3])
{
	int len = count;
	struct Vertex * first = base;
	struct Vertex * stop = base + count;
	while(len > 0)
	{
		int half = len >> 1;
		struct Vertex * middle = first + half;
		
		int res = compare_points(middle->location,p);

		if(res < 0)
		{
			first = middle + 1;
			len = len - half - 1;
		}
		else {
			len = half;
		}
	}

	*begin = first;
	
	while(first < stop && compare_points(first->location,p) == 0)
		++first;
	*end = first;
}

// ------------------------------------------------------------------------------------------------------------

inline void snap_position(float p[3])
{
	p[0] = round(p[0] * SNAP_PRECISION) / SNAP_PRECISION;
	p[1] = round(p[1] * SNAP_PRECISION) / SNAP_PRECISION;
	p[2] = round(p[2] * SNAP_PRECISION) / SNAP_PRECISION;
}

inline void vec3f_normalize(float N[3])
{
	float len = sqrt(N[0]*N[0]+N[1]*N[1]+N[2]*N[2]);
	if(len)
	{
		len = 1.0f / len;
		N[0] *= len;
		N[1] *= len;
		N[2] *= len;
	}
}

inline void vec3f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
}

inline void vec4f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
	d[3] = s[3];
}

inline float vec3f_dot(const float * __restrict v1, const float * __restrict v2)
{
	return v1[0]*v2[0]+v1[1]*v2[1]+v1[2]*v2[2];
}

inline void vec3_cross(float * __restrict dst, const float * __restrict v1, const float * __restrict v2)
{
	dst[0] = (v1[1] * v2[2]) - (v1[2] * v2[1]);
	dst[1] = (v1[2] * v2[0]) - (v1[0] * v2[2]);
	dst[2] = (v1[0] * v2[1]) - (v1[1] * v2[0]);	
}


int CCW(const struct Face * f, int i) { assert(i >= 0 && i < f->degree); return (i          +1)%f->degree; }
int CW (const struct Face * f, int i) { assert(i >= 0 && i < f->degree); return (i+f->degree-1)%f->degree; }

int is_crease(const float n1[3], const float n2[3], int flip)
{
	float dot = vec3f_dot(n1,n2);
	if(flip)
	{
		return (dot > -0.5);
	}
	else	
		return (dot < 0.5);
}

#if DEBUG
// Given a point on a tri, return its index.  This routine works by a spatial comparison and thus
// does not need a Vertex* struct (which is SPECIFIC to a given tri anyway.)
int index_of(struct Face * f, const float p[3])
{
	int r;
	for(r = 0; r < f->degree; ++r)
	if(compare_points(f->vertex[r]->location,p) == 0)
		return r;
	assert(!"Vertex not found.");
	return -1;
}
#endif

#define mirror(f,n) ((f)->index[(n)])

static struct Vertex *		circulate_ccw(struct Vertex * v, int * did_reverse)
{
	//	.------V,M		We use "leading neighbor" syntax, so (2) is the cw(v) neighbor of 1.
	//   \     / \		Conveniently, "M" is the defining vertex for edge X as defined by 2.
	//    \ 1 x   \		So 1->neigbhor(cw(v)) is M's index.
	//	   \ /  2  \	One special case: if we are flipped, we need to go CCW from 'M'.
	//	   cw-------.	
	
	struct Face * face_1 = v->face;
	int cw = CW(face_1,v->index);
	struct Face * face_2 = face_1->neighbor[cw];
	assert(face_2 != UNKNOWN_FACE);
	if(face_2 == NULL)					
		return NULL;					
	int M = mirror(v->face, cw);
	
	*did_reverse = face_1->flip[cw];
	struct Vertex * ret = (face_1->flip[cw]) ? face_2->vertex[CCW(face_2,M)] : face_2->vertex[M];	
	assert(compare_points(v->location,ret->location)==0);
	assert(ret != v);
	return ret;
}

static struct Vertex *		circulate_cw(struct Vertex * v, int * did_reverse)
{
	//	.-------V		V itself defines the edge we want to traverse, but M is out of position - to 
	//   \     / \		recover V we want CCW(M).  But if we are flipped, we just need M itself.
	//    \ 2 x   \		...
	//	   \ /  1  \	...
	//	    M-------.
	
	struct Face * face_1 = v->face;
	struct Face * face_2 = face_1->neighbor[v->index];
	assert(face_2 != UNKNOWN_FACE);	
	if(face_2 == NULL)					
		return NULL;					
	int M = mirror(v->face, v->index);
	*did_reverse = face_1->flip[v->index];
	struct Vertex * ret = (face_1->flip[v->index]) ? face_2->vertex[M] : face_2->vertex[CCW(face_2,M)];	
	assert(compare_points(v->location,ret->location)==0);
	assert(ret != v);
	return ret;
}

static struct Vertex * circulate_any(struct Vertex * v, int * dir)
{
	int did_reverse = 0;
	struct Vertex * ret;

	assert(*dir == -1 || *dir == 1);
	if(*dir > 0)
		ret = circulate_ccw(v,&did_reverse);
	else
		ret = circulate_cw(v,&did_reverse);
	if(did_reverse)
		*dir *= -1;
	return ret;		
}

// ------------------------------------------------------------------------------------------------------------

#if DEBUG
void validate_vertex_sort_10(struct Mesh * mesh)
{
	int i;
	for(i = 1; i < mesh->vertex_count; ++i)
	{
		assert(compare_vertices(mesh->vertices+i-1,mesh->vertices+i) <= 0);
	}
}

void validate_vertex_sort_3(struct Mesh * mesh)
{
	int i;
	for(i = 1; i < mesh->vertex_count; ++i)
	{
		int comp = compare_points(mesh->vertices[i-1].location,mesh->vertices[i].location);
		if(comp > 0)
		{
			assert(!"out of order");
		}
	}
}

void validate_vertex_links(struct Mesh * mesh)
{
	int i, j;
	for(i = 0; i < mesh->vertex_count; ++i)
	{
		assert(mesh->vertices[i].face->vertex[mesh->vertices[i].index] == mesh->vertices+i);
	}
	for(i = 0; i < mesh->face_count; ++i)
	for(j = 0; j < mesh->faces[i].degree; ++j)
	{
		assert(mesh->faces[i].vertex[j]->face == mesh->faces+i);
	}	
}

void validate_neighbors(struct Mesh * mesh)
{
	int f,i;
	for(f = 0; f < mesh->face_count; ++f)
	for(i = 0; i < mesh->faces[f].degree; ++i)
	{
		struct Face * face = mesh->faces+f;
		if(face->neighbor[i] && face->neighbor[i] != UNKNOWN_FACE)
		{			
			struct Face * n = face->neighbor[i];
			int ni = face->index[i];			
			assert(n->neighbor[ni] == face);
		
			assert(face->flip[i] == n->flip[ni]);
					
			struct Vertex * p1 = face->vertex[         i ];
			struct Vertex * p2 = face->vertex[CCW(face,i)];

			struct Vertex * n1 = n->vertex[      ni ];
			struct Vertex * n2 = n->vertex[CCW(n,ni)];
			
			int okay_fwd = 			
				(compare_points(n1->location,p2->location) == 0) &&
				(compare_points(n2->location,p1->location) == 0);

			int okay_rev = 			
				(compare_points(n1->location,p1->location) == 0) &&
				(compare_points(n2->location,p2->location) == 0);
			
			assert(!okay_fwd || face->flip[i] == 0);
			assert(!okay_rev || face->flip[i] == 1);
			
			assert(okay_fwd != okay_rev);
			#if WANT_CREASE
			assert(!okay_fwd || vec3f_dot(face->normal,n->normal) > 0.0);
			assert(!okay_rev || vec3f_dot(face->normal,n->normal) < 0.0);
			#endif
		}
	}
}
#endif

// ------------------------------------------------------------------------------------------------------------

struct Mesh *		create_mesh(int tri_count, int quad_count)
{
	struct Mesh * ret = (struct Mesh *) malloc(sizeof(struct Mesh));
	ret->vertex_count = 0;
	ret->vertex_capacity = tri_count*3+quad_count*4;
	ret->vertices = (struct Vertex *) malloc(sizeof(struct Vertex) * ret->vertex_capacity);
	
	ret->face_count = 0;
	ret->face_capacity = tri_count+quad_count;
	ret->faces = (struct Face *) malloc(sizeof(struct Face) * ret->face_capacity);
	return ret;
}

void				add_face(struct Mesh * mesh, const float p1[3], const float p2[3], const float p3[3], const float p4[3], const float color[4])
{
	int i;
	
	float	v1[3] = { p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]};
	float	v2[3] = { p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]};
	
	// grab a new face, grab verts for it
	struct Face * f = mesh->faces + mesh->face_count++;

	vec3_cross(f->normal,v1,v2);
	vec3f_normalize(f->normal);
	
	f->degree = p4 ? 4 : 3;
	
	f->vertex[0] = mesh->vertices + mesh->vertex_count++;
	f->vertex[1] = mesh->vertices + mesh->vertex_count++;
	f->vertex[2]  = mesh->vertices + mesh->vertex_count++;
	f->vertex[3] = p4 ? (mesh->vertices + mesh->vertex_count++) : NULL;

	if (compare_points(p1,p2)==0 ||
		compare_points(p2,p3)==0 ||
		compare_points(p1,p3)==0)
	{
		f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = f->neighbor[3] = NULL;		
	}
	else {
		if(p4)
		{
			if(
				compare_points(p3,p4)==0 ||
				compare_points(p2,p4)==0 ||
				compare_points(p1,p4)==0)
			{
				f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = f->neighbor[3] = NULL;		
			}
			else
			{
				f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = f->neighbor[3] = UNKNOWN_FACE;		
			}
		}
		else
		{
			f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = f->neighbor[3] = UNKNOWN_FACE;		
		}
	}

	f->index[0] = f->index[1] = f->index[2] = f->index[3] = -1;
	f->flip[0] = f->flip[1] = f->flip[2] = f->flip[3] = -1;

	vec4f_copy(f->color, color);


	for(i = 0; i < f->degree; ++i)
	{
		vec3f_copy(f->vertex[i]->normal,f->normal);
		vec4f_copy(f->vertex[i]->color,color);
	}	

	vec3f_copy(f->vertex[0]->location,p1);
	vec3f_copy(f->vertex[1]->location,p2);
	vec3f_copy(f->vertex[2]->location,p3);
	if(p4)
	vec3f_copy(f->vertex[3]->location,p4);

	#if WANT_SNAP
	snap_position(f->vertex[0]->location);
	snap_position(f->vertex[1]->location);
	snap_position(f->vertex[2]->location);
	if(f->vertex[3])
	snap_position(f->vertex[3]->location);
	#endif

	f->vertex[0]->index = 0;
	f->vertex[1]->index = 1;
	f->vertex[2]->index = 2;
	if(f->vertex[3])
	f->vertex[3]->index = 3;

	f->vertex[0]->face = 
	f->vertex[1]->face = 
	f->vertex[2]->face = f;
	if(f->vertex[3])
	f->vertex[3]->face = f;
}


void				finish_faces_and_sort(struct Mesh * mesh)
{
	int v;

	// sort vertices by 10 params
	sort_vertices_3(mesh->vertices,mesh->vertex_count);

	// then re-build ptr indices into faces since we moved vertices
	for(v = 0; v < mesh->vertex_count; ++v)
	{
		mesh->vertices[v].face->vertex[mesh->vertices[v].index] = mesh->vertices+v;
	}
	
	#if DEBUG
	validate_vertex_sort_3(mesh);
	validate_vertex_links(mesh);
	#endif
}

void				add_crease(struct Mesh * mesh, const float p1[3], const float p2[3])
{
	struct Vertex * begin, * end, *v;
	
	float pp1[3] = { p1[0], p1[1],p1[2] };
	float pp2[3] = { p2[0], p2[1],p2[2] };

	#if WANT_SNAP
	snap_position(pp1);
	snap_position(pp2);
	#endif
	
	range_for_point(mesh->vertices,mesh->vertex_count,&begin,&end,pp1);
	for(v = begin; v < end; ++v)
	{
		struct Face * f = v->face;
		
		//       CCW		The index of neighbor "A" is index; the index of neighbor b is CCW.
		//      /   \		The index of neighbor C is CW.
		//     b     a		So...if CW=p2 we found c; 
		//	  /       \		if CCW=p2 we found a.
		//	CW---c---INDEX
		//
		//
		// 		// 		// 		
		int ccw = CCW(f,v->index);
		int cw  = CW (f,v->index);
		
		if(compare_points(f->vertex[cw]->location,pp2)==0)
		{
			// We found "C" - nuke at 'cw'
			f->neighbor[cw] = NULL;
			f->index[cw] = -1;
		}

		if(compare_points(f->vertex[ccw]->location,pp2)==0)
		{
			// We fond "A" - nuke at 'index'
			f->neighbor[v->index] = NULL;
			f->index[v->index] = -1;
		}
	}

}

void				finish_creases_and_join(struct Mesh * mesh)
{
	int fi;
	int i;
	struct Face * f;
	for(fi = 0; fi < mesh->face_count; ++fi)
	{
		f = mesh->faces+fi;
		for(i = 0; i < f->degree; ++i)
		{
			if(f->neighbor[i] == UNKNOWN_FACE)
			{
				//     CCW(i)/P1
				//      /   \		The directed edge we want goes FROM i TO ccw.
				//     /     i		So p2 = ccw, p1 = i, that is, we want our OTHER
				//	  /       \		neighbor to go FROM cw TO CCW
				//	 .---------i/P2

				struct Vertex * p1 = f->vertex[CCW(f,i)];
				struct Vertex * p2 = f->vertex[      i ];
				struct Vertex * begin, * end, * v;
				range_for_point(mesh->vertices,mesh->vertex_count,&begin,&end,p1->location);
				for(v = begin; v != end; ++v)
				{
					if(v->face == f)
						continue;
						
					//	P1/v-----x		Normal case - Since p1->p2 is the ideal direction of our
					//    \     /		neighbor, p2 = ccw(v).  Thus p1(v) names our edge.
					//     v   /		
					//      \ /
					//     P2/CCW(V)
					
					//	P1/v-----x		Backward winding case - thus p2 is CW from P1,
					//    \     /		and P2 (cw(v) names our edge.
					//   cw(v) /		
					//      \ /
					//     P2/CW(V)

					
					assert(compare_points(p1->location,v->location)==0);
					
					struct Face * n = v->face;
					struct Vertex * dst = n->vertex[CCW(n,v->index)];
					#if WANT_INVERTS
					struct Vertex * inv = n->vertex[ CW(n,v->index)];
					#endif
					if(compare_points(dst->location,p2->location)==0)
					{
						int ni = v->index;
						assert(f->neighbor[i] == UNKNOWN_FACE);
						if(n->neighbor[ni] == UNKNOWN_FACE)
						{	
							#if WANT_CREASE
							if(is_crease(f->normal,n->normal,false))
							{
								f->neighbor[i] = NULL;
								n->neighbor[ni] = NULL;
								f->index[i] = -1;
								n->index[ni] = -1;
								break;
							}
							else
							#endif
							{
								// v->dst matches p1->p2.  We have neighbors.
								// Store both - avoid half the work when we get to our neighbor.
								f->neighbor[i] = n;
								n->neighbor[ni] = f;
								f->index[i] = ni;
								n->index[ni] = i;
								f->flip[i] = 0;
								n->flip[ni] = 0;
								break;
							}							
						}
					}				
					#if WANT_INVERTS
					if(compare_points(inv->location,p2->location)==0)
					{
						int ni = CW(v->face,v->index);
						assert(f->neighbor[i] == UNKNOWN_FACE);
						if(n->neighbor[ni] == UNKNOWN_FACE)
						{	
							#if WANT_CREASE
							if(is_crease(f->normal,n->normal,true))
							{
								f->neighbor[i] = NULL;
								n->neighbor[ni] = NULL;
								f->index[i] = -1;
								n->index[ni] = -1;
								break;
							}
							else
							#endif
							{
								// v->dst matches p1->p2.  We have neighbors.
								// Store both - avoid half the work when we get to our neighbor.
								f->neighbor[i] = n;
								n->neighbor[ni] = f;
								f->index[i] = ni;
								n->index[ni] = i;
								f->flip[i] = 1;
								n->flip[ni] = 1;
								break;
							}							
						} 
					}				
					#endif

				}			
			}
			if(f->neighbor[i] == UNKNOWN_FACE)
			{
				f->neighbor[i] = NULL;
				f->index[i] = -1;
			}
		}
	}

	#if DEBUG
	validate_neighbors(mesh);
	#endif
}

void				smooth_vertices(struct Mesh * mesh)
{
	int f;
	int i;
	for(f = 0; f < mesh->face_count; ++f)
	for(i = 0; i < mesh->faces[f].degree; ++i)
	{
		// For each vertex, we are going to circulate around attached faces, averaging up our normals.
	
		struct Vertex * v = mesh->faces[f].vertex[i];
		
		// First, go clock-wise around, starting at ourselves, until we loop back on ourselves (a closed smooth
		// circuite - the center vert on a stud top is like this) or we run out of vertices.
		
		struct Vertex * c = v;
		float N[3] = { 0 };
		int ctr = 0;
		int circ_dir = -1;
		do {
			++ctr;
			//printf("\tAdd: %f,%f,%f\n",c->normal[0],c->normal[1],c->normal[2]);
			
			if(vec3f_dot(v->face->normal,c->face->normal) > 0.0)
			{
				N[0] += c->face->normal[0];
				N[1] += c->face->normal[1];
				N[2] += c->face->normal[2];
			}
			else
			{
				N[0] -= c->face->normal[0];
				N[1] -= c->face->normal[1];
				N[2] -= c->face->normal[2];
			}
		
			c = circulate_any(c,&circ_dir);

		} while(c != NULL && c != v);
		
		// Now if we did NOT make it back to ourselves it means we are a disconnected circulation.  For example
		// a semi-circle fan's center will do this if we start from a middle tri.
		// Circulate in the OTHER direction, skipping ourselves, until we run out.
		
		if(c != v)
		{
			circ_dir = 1;
			c = circulate_any(v,&circ_dir);
			while(c)
			{
				++ctr;
				//printf("\tAdd: %f,%f,%f\n",c->normal[0],c->normal[1],c->normal[2]);
				if(vec3f_dot(v->face->normal,c->face->normal) > 0.0)
				{
					N[0] += c->face->normal[0];
					N[1] += c->face->normal[1];
					N[2] += c->face->normal[2];
				}
				else
				{
					N[0] -= c->face->normal[0];
					N[1] -= c->face->normal[1];
					N[2] -= c->face->normal[2];
				}
		
				c = circulate_any(c,&circ_dir);		
				
				// Invariant: if we did NOT close-loop up top, we should NOT close-loop down here - that would imply
				// a triangulation where our neighbor info was assymetric, which would be "bad".
				assert(c != v);		
			}
		}
		
		vec3f_normalize(N);
		//printf("Final: %f %f %f\t%f %f %f (%d)\n",v->location[0],v->location[1], v->location[2], N[0],N[1],N[2], ctr);
		v->normal[0] = N[0];
		v->normal[1] = N[1];
		v->normal[2] = N[2];
		#if DEBUG_SHOW_NORMALS_AS_COLOR
		v->color[0] = N[0] * 0.5 + 0.5;
		v->color[1] = N[1] * 0.5 + 0.5;
		v->color[2] = N[2] * 0.5 + 0.5;
		v->color[3] = 1.0f;
		#endif
		
	}
}

void				merge_vertices(struct Mesh * mesh)
{
	// Once smoothing is done, indexing the mesh is actually pretty easy:
	// First, we re-sort the vertex list; now that our normals and colors
	// are consolidated, equal-value vertices in the final mesh will pool
	// together.
	//
	// Then (having moved our vertices) we need to rebuild the face->vertex
	// pointers...when we do this, we simply use the FIRST vertex among 
	// equals for every face.
	//
	// The result is that for every redundent vertex, every face will 
	// agree on which ptr to use.  This means that we can build an indexed
	// mesh off of the ptrs and get maximum sharing.
	
	int v;

	int unique = 0;
	struct Vertex * first_of_equals = mesh->vertices;

	// Resort according ot our xyz + normal + color
	sort_vertices_10(mesh->vertices,mesh->vertex_count);
	
	// Re-set the tri ptrs again, but...for each IDENTICAL source vertex, use the FIRST of them as the ptr
	for(v = 0; v < mesh->vertex_count; ++v)
	{
		if(compare_vertices(first_of_equals, mesh->vertices+v) != 0)
		{
			first_of_equals = mesh->vertices+v;
			++unique;
		}
		mesh->vertices[v].face->vertex[mesh->vertices[v].index] = first_of_equals;
	}

	#if DEBUG
	validate_vertex_sort_10(mesh);
	#endif
	//printf("Before: %d vertices, after: %d\n", mesh->vertex_count, unique);
}

void				destroy_mesh(struct Mesh * mesh)
{
	free(mesh->vertices);
	free(mesh->faces);
	free(mesh);
}
