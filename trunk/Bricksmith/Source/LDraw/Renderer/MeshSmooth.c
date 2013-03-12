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

/*
todo
	- convert to "after vertex CCW" adjacency model, retest
	- add quads to mesh model
	- index faces and measure perf
	- index lines too if faces are a win
*/


int compare_points(const float * __restrict p1, const float * __restrict p2)
{
	// The std c lib rule is that we are fundamentally returning p1-p2.
	// So when p1 < p2, we return a negative number, etc.
//	return memcmp(p1,p2,3*sizeof(float));
	if(p1[0] < p2[0])	return -1;
	if(p1[0] > p2[0])	return  1;

	if(p1[1] < p2[1])	return -1;
	if(p1[1] > p2[1])	return  1;

	if(p1[2] < p2[2])	return -1;
	if(p1[2] > p2[2])	return  1;
	
	return 0;
}

int compare_vertices(const struct Vertex * __restrict v1, const struct Vertex * __restrict v2)
{
//	return memcmp(v1,v1,sizeof(struct Vertex));

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

void swap_blocks(void * __restrict a, void * __restrict b, int num_words)
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
//	qsort(base,count,sizeof(struct Vertex),compare_vertices);
	bubble_sort_10(base,count);
}

void quickSort_3(struct Vertex * arr, int left, int right) 
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
//	qsort(base,count,sizeof(struct Vertex),compare_points);
}



static void range_for_point(struct Vertex * base, int count, struct Vertex ** begin, struct Vertex ** end, const float p[3])
{
#if 0
	struct Vertex * test_begin, * test_end;
	{
	// Stupid linear-time search for testing.	
		int v;
		for(v = 0; v < count; ++v)
		{
			if(compare_points(p,base+v)==0)
				break;
		}
		test_begin = base+v;

		while(v < count && compare_points(p,base+v) == 0)
			++v;
		test_end = base+v;
	}
#endif

//	*begin = test_begin;
//	*end= test_end;
//	return;
//
#if 1

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
		
		if(compare_points(first->location,p) != 0)
		{
			*begin = *end = base + count;
		}
		else
		{		
			*begin = first;
			
			while(first < stop && compare_points(first->location,p) == 0)
				++first;
			*end = first;
		}
	}
	
//	assert(*begin == test_begin);
//	assert(*end == test_end);
#endif	

}

// ------------------------------------------------------------------------------------------------------------

void snap_position(float p[3])
{
	p[0] = round(p[0] * SNAP_PRECISION) / SNAP_PRECISION;
	p[1] = round(p[1] * SNAP_PRECISION) / SNAP_PRECISION;
	p[2] = round(p[2] * SNAP_PRECISION) / SNAP_PRECISION;
}

void normalize_normal(float N[3])
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

int CCW(int i) { return (i+1)%3; }
int CW (int i) { return (i+2)%3; }

int is_crease(const float n1[3], const float n2[3])
{
	float dot = n1[0]*n2[0]+n1[1]*n2[1]+n1[2]*n2[2];
	return (dot < 0.5);
}

// Given a point on a tri, return its index.  This routine works by a spatial comparison and thus
// does not need a Vertex* struct (which is SPECIFIC to a given tri anyway.)
int index_of(struct Face * f, const float p[3])
{
	int r;
	for(r = 0; r < 3; ++r)
	if(compare_points(f->vertex[r]->location,p) == 0)
		return r;
	assert(!"Vertex not found.");
	return -1;
}

int mirror(struct Face * f, int n)
{
	//	i------CW		Given edge "n", defined as the "ith" edge of triangle 1,
	//   \     / \		how do we know the index in tri 2 ("M")?  The vertices are NOT shared
	//    \ 1 N   \		So we recover the index of "CCW" relative to 2 and 
	//	   \ /  2  \	go CCW again.
	//	   CCW------M
	
	assert(f->neighbor[n]);
	
	struct Vertex * ccw_1 = f->vertex[CCW(n)];
	int ccw_2 = index_of(f->neighbor[n],ccw_1->location);
	return CCW(ccw_2);	
}

struct Vertex *		circulate_ccw(struct Vertex * v)
{
	//	ccw-----V		ccw is the ccw vertex of V in tri 1, and defines the neighbor-edge that gets us to 2.
	//   \     / \		buuuut once we get to 2, we need to recover that edge.  "M" defines that edge, and V
	//    \ 1 /   \		(in tri 2) is the CCW of M.
	//	   \ /  2  \	So....the total formula is ccw(mirror(ccw(v)))
	//	    .-------M
	
	struct Face * face_1 = v->face;
	int ccw = CCW(v->index);
	struct Face * face_2 = face_1->neighbor[ccw];
	assert(face_2 != UNKNOWN_FACE);
	if(face_2 == NULL)					// Bail out - we are NOT guaranteed complete connectivity; if we _have_ no neighbor
		return NULL;					// around V, bail out before we blow up.
	int M = mirror(v->face, ccw);
	return face_2->vertex[CCW(M)];	
}

struct Vertex *		circulate_cw(struct Vertex * v)
{
	//	 M------V		cw is the cw vertex of V in tri 1, and defines the neighbor-edge that gets us to 2.
	//   \     / \		buuuut once we get to 2, we need to recover that edge.  "M" defines that edge, and V
	//    \ 2 /   \		(in tri 2) is the CW of M.
	//	   \ /  1  \	So....the total formula is cw(mirror(cw(v)))
	//	    .------CW
	
	struct Face * face_1 = v->face;
	int cw = CW(v->index);
	struct Face * face_2 = face_1->neighbor[cw];
	assert(face_2 != UNKNOWN_FACE);
	if(face_2 == NULL)					// Bail out - we are NOT guaranteed complete connectivity; if we _have_ no neighbor
		return NULL;					// around V, bail out before we blow up.
	int M = mirror(v->face, cw);
	return face_2->vertex[CW(M)];	
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
	for(j = 0; j < 3; ++j)
	{
		assert(mesh->faces[i].vertex[j]->face == mesh->faces+i);
	}	
}

void validate_neighbors(struct Mesh * mesh)
{
	int f,i;
	for(f = 0; f < mesh->face_count; ++f)
	for(i = 0; i < 3; ++i)
	{
		struct Face * face = mesh->faces+f;
		if(face->neighbor[i] && face->neighbor[i] != UNKNOWN_FACE)
		{
			struct Face * n = face->neighbor[i];
			struct Vertex * p1 = face->vertex[CCW(i)];
			struct Vertex * p2 = face->vertex[ CW(i)];
			
			int n1 = index_of(n,p1->location);
			int n2 = index_of(n,p2->location);
			
			assert(n2==CW(n1));
			assert(n->neighbor[CCW(n1)] == face);
		}
	}
}
#endif

// ------------------------------------------------------------------------------------------------------------

struct Mesh *		create_mesh(int face_count)
{
	struct Mesh * ret = (struct Mesh *) malloc(sizeof(struct Mesh));
	ret->vertex_count = 0;
	ret->vertex_capacity = face_count*3;
	ret->vertices = (struct Vertex *) malloc(sizeof(struct Vertex) * ret->vertex_capacity);
	
	ret->face_count = 0;
	ret->face_capacity = face_count;
	ret->faces = (struct Face *) malloc(sizeof(struct Face) * ret->face_capacity);
	return ret;
}

void				add_face(struct Mesh * mesh, const float p1[3], const float p2[3], const float p3[3], const float normal[3], const float color[4])
{
	int i;
	// grab a new face, grab verts for it
	struct Face * f = mesh->faces + mesh->face_count++;
	f->vertex[0] = mesh->vertices + mesh->vertex_count++;
	f->vertex[1] = mesh->vertices + mesh->vertex_count++;
	f->vertex[2]  = mesh->vertices + mesh->vertex_count++;

	if (compare_points(p1,p2)==0 ||
		compare_points(p2,p3)==0 ||
		compare_points(p1,p3)==0)
	{
		f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = NULL;		
	}
	else {
		f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = UNKNOWN_FACE;		
	}

	for(i = 0; i < 4; ++i)
	{
		f->vertex[0]->color[i] = 
		f->vertex[1]->color[i] = 
		f->vertex[2]->color[i] = 
		f->color[i] =
		color[i];
	}
	
	for(i = 0; i < 3; ++i)
		f->normal[i] = normal[i];
	normalize_normal(f->normal);

	for(i = 0; i < 3; ++i)
	{
		f->vertex[0]->normal[i] = 
		f->vertex[1]->normal[i] = 
		f->vertex[2]->normal[i] = 
		f->normal[i];
		
		f->vertex[0]->location[i] = p1[i];
		f->vertex[1]->location[i] = p2[i];
		f->vertex[2]->location[i] = p3[i];
	}
	
	#if WANT_SNAP
	snap_position(f->vertex[0]->location);
	snap_position(f->vertex[1]->location);
	snap_position(f->vertex[2]->location);
	#endif

	f->vertex[0]->index = 0;
	f->vertex[1]->index = 1;
	f->vertex[2]->index = 2;

	f->vertex[0]->face = 
	f->vertex[1]->face = 
	f->vertex[2]->face = f;
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
		
		//       CCW		The index of neighbor "A" is cw; the index of neighbor c is CCW.
		//      /   \		Neighbor B _cannot_ be p1/p2 because p1 is index.
		//     b     a		So...if CW=p2 we found c; 
		//	  /       \		if CCW=p2 we found a.
		//	CW---c---INDEX
		//
		//
		// 		// 		// 		
		int ccw = CCW(v->index);
		int cw = CW(v->index);
		
		if(compare_points(f->vertex[cw]->location,pp2)==0)
		{
			f->neighbor[ccw] = NULL;
		}

		if(compare_points(f->vertex[ccw]->location,pp2)==0)
		{
			f->neighbor[cw] = NULL;
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
		for(i = 0; i < 3; ++i)
		{
			if(f->neighbor[i] == UNKNOWN_FACE)
			{
				//       P2
				//      /   \		The directed edge we want goes FROM ccw TO cw.
				//     i     \		So p2 = ccw, p1 = cw, that is, we want our OTHER
				//	  /       \		neighbor to go FROM cw TO CCW
				//	P1---------i
				
				struct Vertex * p1 = f->vertex[CW (i)];
				struct Vertex * p2 = f->vertex[CCW(i)];
				struct Vertex * begin, * end, * v;
				range_for_point(mesh->vertices,mesh->vertex_count,&begin,&end,p1->location);
				for(v = begin; v != end; ++v)
				{
					//       dst
					//      /   \		Here is our neighbor - P2 must be CCW from P1,
					//     /     x		and the edge X that connects us is CW of P1.
					//	  /       \		One search and we know exactly who we are.
					//	CW---------v
					
					assert(compare_points(p1->location,v->location)==0);
					
					struct Face * n = v->face;
					struct Vertex * dst = n->vertex[CCW(v->index)];
					if(compare_points(dst->location,p2->location)==0)
					{
						int ni = CW(v->index);
						assert(f->neighbor[i] == UNKNOWN_FACE);
						if(n->neighbor[ni] == UNKNOWN_FACE)
						{		
							#if WANT_CREASE
							if(is_crease(f->normal,n->normal))
							{
								f->neighbor[i] = NULL;
								n->neighbor[CW(v->index)] = NULL;
								//printf("WARNING: crease angle?!?\n");
							}
							else
							#endif
							{
								// v->dst matches p1->p2.  We have neighbors.
								// Store both - avoid half the work when we get to our neighbor.
								f->neighbor[i] = n;
								n->neighbor[ni] = f;
							}
							
							// Bail out, avoid needless searching of incident vertices...
							break;
						}
					}				
				}			
			}
			if(f->neighbor[i] == UNKNOWN_FACE)
			{
				f->neighbor[i] = NULL;
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
	for(i = 0; i < 3; ++i)
	{
		// For each vertex, we are going to circulate around attached faces, averaging up our normals.
	
		struct Vertex * v = mesh->faces[f].vertex[i];
		
		// First, go clock-wise around, starting at ourselves, until we loop back on ourselves (a closed smooth
		// circuite - the center vert on a stud top is like this) or we run out of vertices.
		
		struct Vertex * c = v;
		float N[3] = { 0 };
		int ctr = 0;
		do {
			++ctr;
			//printf("\tAdd: %f,%f,%f\n",c->normal[0],c->normal[1],c->normal[2]);
			N[0] += c->face->normal[0];
			N[1] += c->face->normal[1];
			N[2] += c->face->normal[2];
		
			c = circulate_cw(c);

		} while(c != NULL && c != v);
		
		// Now if we did NOT make it back to ourselves it means we are a disconnected circulation.  For example
		// a semi-circle fan's center will do this if we start from a middle tri.
		// Circulate in the OTHER direction, skipping ourselves, until we run out.
		
		if(c != v)
		{
			c = circulate_ccw(v);
			while(c)
			{
				++ctr;
				//printf("\tAdd: %f,%f,%f\n",c->normal[0],c->normal[1],c->normal[2]);
				N[0] += c->face->normal[0];
				N[1] += c->face->normal[1];
				N[2] += c->face->normal[2];
		
				c = circulate_ccw(c);		
				
				// Invariant: if we did NOT close-loop up top, we should NOT close-loop down here - that would imply
				// a triangulation where our neighbor info was assymetric, which would be "bad".
				assert(c != v);		
			}
		}
		
		normalize_normal(N);
		//printf("Final: %f %f %f\t%f %f %f (%d)\n",v->location[0],v->location[1], v->location[2], N[0],N[1],N[2], ctr);
		v->normal[0] = N[0];
		v->normal[1] = N[1];
		v->normal[2] = N[2];
		
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

	struct Vertex * first_of_equals = mesh->vertices;

	// Resort according ot our xyz + normal + color
	sort_vertices_10(mesh->vertices,mesh->vertex_count);
	
	// Re-set the tri ptrs again, but...for each IDENTICAL source vertex, use the FIRST of them as the ptr
	for(v = 0; v < mesh->vertex_count; ++v)
	{
		if(compare_vertices(first_of_equals, mesh->vertices+v) != 0)
			first_of_equals = mesh->vertices+v;
		mesh->vertices[v].face->vertex[mesh->vertices[v].index] = first_of_equals;
	}

	#if DEBUG
	validate_vertex_sort_10(mesh);
	#endif
}

void				destroy_mesh(struct Mesh * mesh)
{
	free(mesh->vertices);
	free(mesh->faces);
	free(mesh);
}
