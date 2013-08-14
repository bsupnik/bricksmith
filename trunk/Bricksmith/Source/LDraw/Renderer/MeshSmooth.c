/*
 *  MeshSmooth.c
 *  Bricksmith
 *
 *  Created by bsupnik on 3/10/13.
 *  Copyright 2013 . All rights reserved.
 *
 */

#include "MeshSmooth.h"

#pragma mark -
//==============================================================================
//	BASIC DATASTRUCTURES
//==============================================================================
//	
//	MeshSmooth uses a linked face-and-vertex mesh structure:
//
//	- A face has pointers to its vertices.  (A line triangle and quad are all
//    "faces" of differing degree.)
//	- A face has pointers to its adjacent neighbors that share common edges.
//	- Each vertex points to the face that owns it and knows its index in
//	  the face.
//	- Co-located vertices are _not_ represented by single pointers until the
//    end of processing!
//
//	The mesh contains an array of all faces and an array of all vertices.   The
//	vertices are sorted in lexicographical position order, and thus all 
//	colocated vertices have an equal range and are adjacent in the array.  The
//	sort also makes vertex location by XYZ log(N).
//
//	We number the adjacent side index by the index of the "source" vertex for
//	a side in a CCW circulation.  In other words, going from vertex 1 to 
//	vertex 2, the directed edge 1->2 has its triangle on its left and neighbor
//	index "1" on the right side.
//
//	Neighbors will _not_ have the same index numbering as the adjacent triangle.

struct	Vertex;

//       2
//      / \			Edge and vertex numbering scheme: 
//     e2  e1		Vertices are numbered in counter-clockwise order.
//    /     \		Edges are numbered by their source vertex - that is,
//   /       \		the directed edge from 1 to 2 has index 1.
//	0---e0----1

//      2/2--------1
//      / \	  B	  /		Adjacent triangles A and B.  A's neighbor 1 is B.
//     / e1\e2   /		B's neigbhor 2 is A.
//    /     \	/		The index of A's neighbor 1 is 2, and the index of
//   /   A   \ /		B's neighbor 2 is 1.  Thus A can recover e2's position
//	0--------1/0		in B without having to test 2/2 and 1/0 for equality.


// Vertex insert request.  When we need to subdivide a face because its edges
// are parts of T junctions, we add one of these structures.
struct VertexInsert {
	struct VertexInsert *	next;		// Next insert request in the list.
	float					dist;		// Distance along the edge of this insert.
	struct Vertex *			vert;		// Pointer to vertex from another triangle that is a T with our edge.
};

// A single face in our mesh.
struct Face {
	int					degree	   ;		// Number of vertices - this defines whether we are a line, tri or quad.  
											// Set to 0 after export to null out the face.
	struct Vertex *		vertex  [4];		// Vertices - 0,1,2 is CCW traversal
	struct Face *		neighbor[4];		// Neighbors - numbered by SOURCE vertex, or NULL if no smooth neighbor or -1L if not yet determined.
	int					index	[4];		// Index of our neighbor edge's source in neighbor, if we have one.
	int					flip	[4];		// Indicates that our neighbor is winding-flipped from us.

	struct VertexInsert*t_list	[4];		// For T junctions, a list of vertices that form Ts with the edge starting with vertex N.

	float				normal[3];			// Whole-face properties: calculated normal
	float				color[4];			// RGBA color passed in,
	int					tid;				// texture ID index.
};

// A single vertex for a single face.
struct Vertex {
											// These properties are intentionally ordered so that we get near-vertices to sort near each other even before normal smoothing.
	float			location[3];			// Actual vertex location
	float			normal[3];				// Smooth normal at this vertex - starts as face normal but can be changed by smoothing.
	float			color[4];				// Color for my face.
	
	int				index;					// Index of us within our owning face.
	struct Face *	face;					// Our owning face.
	
	struct Vertex *	next;					// For snapping: when we are snapping vertices, we build them into a doubly-linked list.  These point to the other vertices
	struct Vertex * prev;					// in our snap list (or is null if we are not snapped with anyone.)
};


// Our mesh master-container.
struct Mesh {
	int					vertex_count;		// Number of vertices so far.
	int					vertex_capacity;	// Number of vertices we have storage for in our vertex array.
	int					unique_vertex_count;// Number of actual unique vertices after merging for export.
	struct Vertex *		vertices;			// malloc'd array of vertices.
	
	int					face_count;			// Number of total faces so far.
	int					tri_count;			// Number of triangle faces≥
	int					quad_count;			// Number of quad faces.
	int					poly_count;			// Number of quad + triangle faces.
	int					line_count;			// Number of line faces.  Lines must be AFTER quads and tris.
	int					face_capacity;		// Face capacity reserved in array.
	struct Face *		faces;				// Malloc'd face memory.
	
	struct RTree_node *	index;				// Root node of r-tree that indexes vertices.
	#if DEBUG
	int					flags;				// For debugging, we can flag various conditions that aren't errors but are strange (due to LDraw precision issues).
	#endif
	int					highest_tid;		// Highest TID - we have this + 1 total textures in this mesh.
};


#pragma mark -
//==============================================================================
//	R-TREE DATASTRUCTURES
//==============================================================================

// http://en.wikipedia.org/wiki/R-tree
//
// Our R-tree stores vertices by their 3-d AABBs; for internal nodes, we store a
// pair of child nodes; for leaf nodes we store up to 8 individual vertices.
// Because the R-tree has diminishing returns as we get to a small scale, it makes 
// sense to store more than one triangle per leaf - it cuts down nodes and gets us
// better memory access patterns.
//
// We set the LSB of our pointers to 1 for leaf nodes as a way to indicate the
// type of the node in its parent.

#define LEAF_DIM 8

struct RTree_node {
	float	min_bounds[3];
	float	max_bounds[3];
	struct	RTree_node *	left;
	struct	RTree_node * right;
};

struct RTree_leaf {
	float 	min_bounds[3];
	float	max_bounds[3];
	int		count;				// Number of actual vertices, might be less than
	struct Vertex *				// leaf DIM.
			vertices[LEAF_DIM];
};

// Macros to determine if a ptr is a leaf, cast it and clean the LSB.
#define IS_LEAF(n) (((intptr_t) (n) & 1) != 0)
#define GET_LEAF(n) ((struct RTree_leaf*) (((intptr_t) (n)) & ~1))
#define GET_CLEAN(n) ((struct RTree_node*) (((intptr_t) (n)) & ~1))


#pragma mark -
//==============================================================================
//	CONSTANTS AND CONTROLS
//==============================================================================

// 1/100th of an LDU causes the 6x6 webbed dishes to become flat shaded around their rim at the 'joins' between the sections.
// Since an LDU is about 0.4 mm we're talking about 1/50th of a mm.  I CAN'T SEE THAT KIND OF DETAIL!  MY EYES ARE OLD.  MY BACK
// HURTS! WHEN I WAS A KID WE WALKED TO SCHOOL IN THE SNOW UP HILL BOTH WAYS and binary only had 0, the 1 hadn't been invented,
// and all of our programs seg faulted...and we liked it, because it's all there was!
#define EPSI 0.05
#define EPSI2 (EPSI*EPSI)

// Turn this on to do a whole bunch of expensive validation of the algorithm.  Good for one-time tests but almost unusable even
// for a debug test session.
#define SLOW_CHECKING 0

#if SLOW_CHECKING

#define TINY_INITIAL_TRIANGLE 1
#define TINY_RESULTING_GEOM 2

#define CHECK_EPSI 0.045
#define CHECK_EPSI2 (CHECK_EPSI*CHECK_EPSI)
#endif

#if !defined(MIN)
    #define MIN(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#endif

#if !defined(MAX)
    #define MAX(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })
#endif

// Ptr for a neighbor that isn't 
#define UNKNOWN_FACE ((struct Face *) -1)

// 
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

	put a TID texture ID on each face so we can do ONE big smooth of ALL textures
	and then extract in texture order.

 	- switch to "binary seek" (e.g. +8 -4 + 2 -1 to get to a vertex)

*/

#pragma mark -
//==============================================================================
//	SORTING AND COMPARISONS
//==============================================================================

// The std c lib rule is that we are fundamentally returning p1-p2.
// So when p1 < p2, we return a negative number, etc.

// Compare two unique 3-d points in space for location-sameness.
static int compare_points(const float * __restrict p1, const float * __restrict p2)
{
	if(p1[0] < p2[0])	return -1;
	if(p1[0] > p2[0])	return  1;

	if(p1[1] < p2[1])	return -1;
	if(p1[1] > p2[1])	return  1;

	if(p1[2] < p2[2])	return -1;
	if(p1[2] > p2[2])	return  1;
	
	return 0;
}

// Compare two vertices for complete match-up of all vertices - vertex, normal, color.
// If these all match, we could merge the vertices on the graphics card.
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

// Compare only the "Nth" location field, e.g. only x, y, or z.  
// Used to organize points along a single axis.
static int compare_nth(const struct Vertex * __restrict v1, const struct Vertex * __restrict v2, int n)
{
	if(v1->location[n] < v2->location[n]) return -1;
	if(v1->location[n] > v2->location[n]) return  1;
	return 0;
}

// Utility to swap blocks of 4-byte words.
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

// 10-coordinate bubble sort - in other words, the array of vertices is sorted
// lexicographically based on all 10 coords (position, normal, and color).
// WHY a bubble sort??!  Well, it turns out that when we run this, we are already
// sorted by location, and thus the 'disturbance' of orders are very localized 
// and small.  So it is faster to run bubble sort - while its worst case time is
// really quite bad, it gets fast when we are nearly sorted.
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

// sort APIs are wrapped in functions that don't have an algo, e.g. "just sort by 
// 10 coords" so we can easily try different algos and see which is fastest.
static void sort_vertices_10(struct Vertex * base, int count)
{
	bubble_sort_10(base,count);
}

// 3-coordinate quick-sort.  The range of arr from [left to right] (inclusive!!)
// is sorted using quick-sort.  For totally unsorted data, this is a good sort 
// choice.  Only location is used to sort.
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

// Quick-sort, but based only on the "nth" coordinate - lets us rapidly
// sort by x, y, or z.  We want quicksort because changing the sort axis
// is likely to radically change the order, and thus we are not near-sorted
// to begin with.
static void quickSort_n(struct Vertex ** arr, int left, int right, int n) 
{
	int i = left, j = right;

	struct Vertex ** pivot_ptr = arr + (left + right) / 2;
	struct Vertex * pivot = *pivot_ptr;
	
	/* partition */

	while (i <= j) 
	{

		while(compare_nth(arr[i],pivot,n) < 0)
			++i;

		while(compare_nth(arr[j],pivot,n) > 0)
			--j;

		if (i <= j) 
		{
			if(i != j)
			{
				struct Vertex * t = arr[i];
				arr[i] = arr[j];
				arr[j] = t;
			}
			++i;
			--j;
		}
	}

	if (left < j)
		quickSort_n(arr, left, j,n);

	if (i < right)
		quickSort_n(arr, i, right,n);

}

// General sort by location API, see sort_vertices_10 for
// logic.
static void sort_vertices_3(struct Vertex * base, int count)
{
	quickSort_3(base,0,count-1);
}

// Search primitive.  Given a sorted (by location) array of vertices and a target point (p3) this routine finds the range
// [begin, end) that has points of equal location to p.  begin == end if there are on points matching p; in this case,
// begin and end will _not_ be "near" p in any way.
//
// The beginning of the range is found via binary search; the end is found by linearly walking forward to find the end.
// Since we have relatively small numbers of equal points, this linear walk is fine.
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

// Given a vertex q already in our array of sorted vertices [base, stop) we find the range [begin, end) that is entirely colocated
// with q.  Q will be in the range [begin, end).  We do this with a linear walk - we know all these vertices are near each other,
// so we just go find them without jumping.
static void range_for_vertex(struct Vertex * base, struct Vertex * stop, struct Vertex ** begin, struct Vertex ** end, struct Vertex * q)
{
	struct Vertex *b = q, *e = q;
	while(b >= base && compare_points(b->location,q->location) == 0)
		--b;
	++b;
	while(e < stop && compare_points(e->location,q->location) == 0)
		++e;
	assert(b < e);
	assert(b <= q);
	assert(e > q);
	*begin = b;
	*end = e;	

}

#pragma mark -
//==============================================================================
//	R-TREE ROUTINES
//==============================================================================


// This routine builds an R-tree node containing ptrs to all vertices within begin/end.  Begin/end
// will be sorted multiple times as needed to accomplish this.  "depth" is the level on the tree -
// we use this to resort the vertices.  When called with a depth of 0 (first call) it is expected
// that the vertices are sorted by X coordinate already.
// We return a node ptr with the lsb set or cleared depending on whether we made an internal or
// leaf node.
struct RTree_node * index_vertices_recursive(struct Vertex ** begin, struct Vertex ** end, int depth)
{
	int i;
	int count = end - begin;
	if(count <= LEAF_DIM)
	{
		// Leaf node case: we have so few nodes, we can fit them into a single leaf.
		/// Build the leaf node, compute the bounding box, and return the node with
		// its LSB set.
		struct RTree_leaf * l = (struct RTree_leaf *) malloc(sizeof(struct RTree_leaf));
		l->min_bounds[0] = l->max_bounds[0] = (*begin)->location[0];
		l->min_bounds[1] = l->max_bounds[1] = (*begin)->location[1];
		l->min_bounds[2] = l->max_bounds[2] = (*begin)->location[2];

		l->count = count;
		for(i = 0; i < count; ++i, ++begin)
		{
			l->min_bounds[0] = MIN(l->min_bounds[0],(*begin)->location[0]);
			l->max_bounds[0] = MAX(l->max_bounds[0],(*begin)->location[0]);
			l->min_bounds[1] = MIN(l->min_bounds[1],(*begin)->location[1]);
			l->max_bounds[1] = MAX(l->max_bounds[1],(*begin)->location[1]);
			l->min_bounds[2] = MIN(l->min_bounds[2],(*begin)->location[2]);
			l->max_bounds[2] = MAX(l->max_bounds[2],(*begin)->location[2]);
		
			l->vertices[i] = *begin;
		}
		return (struct RTree_node *) ((intptr_t) l| 1);
	}
	else
	{
		// Intermediate node case.  We will sort the nodes by X, Y, or Z depending
		// on the axis - by changing the axis we naturally isolate vertices in N dimensions.
		
		// Optimization: avoid one full sort of all vertices since we know our source 
		// input is passed in in X-sorted order!
		if(depth > 0)
			quickSort_n(begin,0,end-begin-1,depth%3);
		int split = count / 2;
		
		// Now recurse on each half of the vertices to get our two child nodes.
		struct RTree_node * left = index_vertices_recursive(begin,begin+split,depth+1);
		struct RTree_node * right = index_vertices_recursive(begin+split,end,depth+1);
				
		// Build our node around our two child nodes; our bounds are the union of our
		// child bounds.  (We don't want to re-check the bounds of all of our vertices.)
		struct RTree_node * n = (struct RTree_node *) malloc(sizeof(struct RTree_node));
		n->left = left;
		n->right = right;
		left = GET_CLEAN(left);
		right = GET_CLEAN(right);
		for(i = 0; i < 3; ++i)
		{
			n->min_bounds[i] = MIN(left->min_bounds[i],right->min_bounds[i]);
			n->max_bounds[i] = MAX(left->max_bounds[i],right->max_bounds[i]);
		}
		return n;
	}		
}

// Top-level call to index nodes.  Returns the root node of our r-tree.  See note
// below about not indexing co-colocated nodes!!
struct RTree_node * index_vertices(struct Vertex * base, int count)
{
	struct Vertex ** arr = (struct Vertex **) malloc(count * sizeof(struct Vertex *));
	int i;
	struct RTree_node * return_node;
	
	struct Vertex ** p = arr;
	
	// We only R-tree the FIRST of a RANGE of points that are mathematically equal.
	// Code doing the query can re-construct the rest of the range by walking forward.
	// This cuts our R-tree down a LOT - in the case of the 48x48 baseplate as a whole,
	// this cuts vertex count by 80% (!).  Since the R-tree build is O(NlogNlogN) - that
	// is, THE most time-complexity-expensive operation in the algo, this is sort of a
	// big deal.
	for(i = 0; i < count; ++i)
	if(i == 0 || compare_points(base[i-1].location,base[i].location) != 0)
	{
		*p++ = base+i;
	}
	
	return_node = index_vertices_recursive(arr,p,0);

	free(arr);
	
	return return_node;
}

// R-tree clean-up: a recursive freeing of the tree.
// Possible future optimization: if the R-tree used a block allocator
// for nodes we might get better spatial efficiency, etc.
void destroy_rtree(struct RTree_node * n)
{
	if(IS_LEAF(n))
	{
		free(GET_LEAF(n));
	}
	else
	{
		destroy_rtree(n->left);
		destroy_rtree(n->right);
		free(n);		
	}
}

// Utility: Returns true if two 3-d AABBs (stored as min XYZ and max XYZ) overlap, including
// overlaps of their edges.
inline int overlap(float b1_min[3], float b1_max[3], float b2_min[3], float b2_max[3])
{
	if(b1_min[0] > b2_max[0])			return 0;
	if(b2_min[0] > b1_max[0])			return 0;
	if(b1_min[1] > b2_max[1])			return 0;
	if(b2_min[1] > b1_max[1])			return 0;
	if(b1_min[2] > b2_max[2])			return 0;
	if(b2_min[2] > b1_max[2])			return 0;

	return 1;
}

// Returns true if a point is inside an AABB, or on its edges.
inline int inside(float b1_min[3], float b1_max[3], float p[3])
{
	if(p[0] >= b1_min[0] && p[0] <= b1_max[0])
	if(p[1] >= b1_min[1] && p[1] <= b1_max[1])
	if(p[2] >= b1_min[2] && p[2] <= b1_max[2])
		return 1;
	return 0;
}

// R-tree scanning routine.  A functor "visitor" is called (with "ref" passed each time) for every vertex in the Rtree "N" whose bounds
// are within (inclusive of edges) min_bounds -> max_bounds.
void scan_rtree(struct RTree_node * n, float min_bounds[3], float max_bounds[3], void (* visitor)(struct Vertex *v, void * ref), void * ref)
{
	if(IS_LEAF(n))
	{
		struct RTree_leaf * l = (GET_LEAF(n));
		if(overlap(l->min_bounds,l->max_bounds,min_bounds,max_bounds))
		{
			int i;
			for(i = 0; i < l->count; ++i)
			if(inside(min_bounds,max_bounds,l->vertices[i]->location))
			{
				visitor(l->vertices[i], ref);
			}
		}
	}
	else
	{
		if(overlap(n->min_bounds,n->max_bounds,min_bounds,max_bounds))
		{
			scan_rtree(n->left, min_bounds,max_bounds, visitor, ref);
			scan_rtree(n->right, min_bounds,max_bounds, visitor, ref);
		}
	}
}

#pragma mark -
//==============================================================================
//	3-D MATH UTILS
//==============================================================================

// vec3 and vec4 APIs refer to "vector" numbers, e.g. small arrays of float.
// So vec3 -> float[3], and vec4 -> float[4].

// Normalize vector N in place if not zero-length.
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

// copy vec3: d = s.
inline void vec3f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
}

// copy vec4: d = s
inline void vec4f_copy(float * __restrict d, const float * __restrict s)
{
	d[0] = s[0];
	d[1] = s[1];
	d[2] = s[2];
	d[3] = s[3];
}

// return dot product of vec3's d1 and d2.
inline float vec3f_dot(const float * __restrict v1, const float * __restrict v2)
{
	return v1[0]*v2[0]+v1[1]*v2[1]+v1[2]*v2[2];
}

// vec3: dst = b - a.  (or: vector dst points from A to B).
inline void vec3f_diff(float * __restrict dst, const float * __restrict a, const float * __restrict b)
{
	dst[0] = b[0] - a[0];
	dst[1] = b[1] - a[1];
	dst[2] = b[2] - a[2];
}

// Return the square of the length of the distance between two vec3 points p1, p2.
inline float vec3f_length2(const float * __restrict p1, const float * __restrict p2)
{
	float d[3];
	vec3f_diff(d, p1,p2);
	return vec3f_dot(d,d);
}

// 3-d comparison of p1 and p2 (simple true/false, not a comparator).
inline int vec3f_eq(const float * __restrict p1, const float * __restrict p2)
{
	return p1[0] == p2[0] && p1[1] == p2[1] && p1[2] == p2[2];
}

// vec3 cross product, e.g. dst = v1 x v2.
inline void vec3_cross(float * __restrict dst, const float * __restrict v1, const float * __restrict v2)
{
	dst[0] = (v1[1] * v2[2]) - (v1[2] * v2[1]);
	dst[1] = (v1[2] * v2[0]) - (v1[0] * v2[2]);
	dst[2] = (v1[0] * v2[1]) - (v1[1] * v2[0]);	
}

// Returns true if the projection of B onto the line AC is in between (but not on) A and C.
inline int in_between_line(const float * __restrict a, const float * __restrict b, const float * __restrict c)
{
	float ab[3], ac[3], cb[3];
	vec3f_diff(ab,a,b);
	vec3f_diff(ac,a,c);
	vec3f_diff(cb,c,b);
	return vec3f_dot(ab,ac) > 0.0f && vec3f_dot(cb, ac) < 0.0f;
}

// project p onto the line along v through o, return it in proj.
inline void proj_onto_line(float * __restrict proj, const float * __restrict o, const float * __restrict v, const float * __restrict p)
{
	float op[3];
	vec3f_diff(op,o,p);
	float scalar = vec3f_dot(op,v) / vec3f_dot(v,v);
	
	proj[0] = o[0] + scalar * v[0];
	proj[1] = o[1] + scalar * v[1];
	proj[2] = o[2] + scalar * v[2];	
}

#pragma mark -
//==============================================================================
//	TRIANGLE MESH UTILS
//==============================================================================

// Utilities to return the next vertex index of a face from i, in either the clock-wise 
// or counter-clockwise direction.
int CCW(const struct Face * f, int i) { assert(i >= 0 && i < f->degree); return (i          +1)%f->degree; }
int CW (const struct Face * f, int i) { assert(i >= 0 && i < f->degree); return (i+f->degree-1)%f->degree; }

// Predicate: do the two face normals n1 and n2 form a crease?  Flip should be true if the winding order
// of the two tris is flipped.
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

#define mirror(f,n) ((f)->index[(n)])

// Given a vertex, this routine returns a colocated vertex from the neighboring triangle
// if the mesh is circulated around V counter-clockwise. 
//
// NULL is returned if there is no adjacent triangle to V's triangle in the CCW direction.
// Note that when a line 'creases' the mesh, the triangles are _not_ connected, so we
// get back NULL.
//
// the int pointed to by did_reverse is set to 0 if v's and the return vertex's triangle 
// have the same winding direction; it is set to 1 if the winding direction of the two
// tris is opposite.
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
	int M = v->face->index[cw];
	
	*did_reverse = face_1->flip[cw];
	struct Vertex * ret = (face_1->flip[cw]) ? face_2->vertex[CCW(face_2,M)] : face_2->vertex[M];	
	assert(compare_points(v->location,ret->location)==0);
	assert(ret != v);
	return ret;
}

// Same as above, but the circulation is done in the clockwise direction.
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
	int M = v->face->index[v->index];
	*did_reverse = face_1->flip[v->index];
	struct Vertex * ret = (face_1->flip[v->index]) ? face_2->vertex[M] : face_2->vertex[CCW(face_2,M)];	
	assert(compare_points(v->location,ret->location)==0);
	assert(ret != v);
	return ret;
}

// This routine circulates V in the CCW direction if *dir is 1, and CW
// if *dir is 0.  Return semantics match the circulators above. 
// If the next triangle reverses winding, *dir is negated so that an 
// additional call with *dir's new value will have the same _effective_
// direction.
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

#pragma mark -
//==============================================================================
//	VALIDATION UTILITIES
//==============================================================================
//
// These routines validate that the invariances of the internal mesh structure
// haven't been stomped on. They are meant only for debug builds, slow the algo
// down, and call a fatal assert() when things go bad.

#if DEBUG

// Validates that the meshes are sorted in ascending order according to all
// ten params (vertex, normal and color.
void validate_vertex_sort_10(struct Mesh * mesh)
{
	int i;
	for(i = 1; i < mesh->vertex_count; ++i)
	{
		assert(compare_vertices(mesh->vertices+i-1,mesh->vertices+i) <= 0);
	}
}

// Validates that the meshes are sorted in ascending order according to 
// position, ignoring normal and color.
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

// This verifies that all vertices and faces link to each other symetrically.
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

// This validates that all neighboring triangles share the same 
// located vertices on their shared edge, the shared edge index
// number is sane, and that the "reversed" flag is set only when
// the winding order really is reversed.
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

#pragma mark -
//==============================================================================
//	MAIN API IMPLEMENTATION
//==============================================================================

// Create a new mesh to smooth.  You must pass in the _exact_ number of tris,
// quads and lines that you will later pass in.
struct Mesh *		create_mesh(int tri_count, int quad_count, int line_count)
{
	struct Mesh * ret = (struct Mesh *) malloc(sizeof(struct Mesh));
	ret->vertex_count = 0;
	ret->vertex_capacity = tri_count*3+quad_count*4+line_count*2;
	ret->vertices = (struct Vertex *) malloc(sizeof(struct Vertex) * ret->vertex_capacity);
	
	ret->face_count = 0;
	ret->face_capacity = tri_count+quad_count+line_count;
	ret->poly_count = tri_count + quad_count;
	ret->line_count = line_count;
	ret->tri_count = tri_count;
	ret->quad_count = quad_count;
	
	ret->faces = (struct Face *) malloc(sizeof(struct Face) * ret->face_capacity);
	#if DEBUG
	ret->flags = 0;
	#endif
	ret->highest_tid = 0;
	return ret;
}

// Add one face to the mesh.  Quads and tris can be added in any order but all 
// quads and tris (polygons) must be added before all lines.
// When passing a face, simply pass NULL for any 'extra' vertices - that is,
// to create a line, pass NULL for p3 and p4; to create a triangle, pass NULL for
// p3.  The color is the color of the entire face in RGBA; the face normal is
// computed for you.
//
// tid is the 'texture ID', a 0-based counted number identifying which texture
// state this face gets.  Texture IDs must be consecutive, zero based and 
// positive, but do not need to be submitted in any particular order, and the 
// highest TID does not have to be pre-declared; the library simply watches
// the TIDs on input.
//
// Technically lines have TIDs as well - typically TID 0 is used to mean the
// 'untextured texture group' and is used for lines and untextured polygons.
//
// The TIDs are used to output sets of draw commands that share common texture state -
// that is, faces, quads and lines are ouput in TID order.
void				add_face(struct Mesh * mesh, const float p1[3], const float p2[3], const float p3[3], const float p4[3], const float color[4], int tid)
{
	#if SLOW_CHECKING
	if(vec3f_length2(p1,p2) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
	if(p3)
	{
		if(vec3f_length2(p1,p3) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
		if(vec3f_length2(p2,p3) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
	}
	if(p4)
	{
		if(vec3f_length2(p1,p4) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
		if(vec3f_length2(p2,p4) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
		if(vec3f_length2(p3,p4) <= EPSI2) mesh->flags |= TINY_INITIAL_TRIANGLE;
	}
	#endif
	int i;
	
	
	// grab a new face, grab verts for it
	struct Face * f = mesh->faces + mesh->face_count++;
	f->tid = tid;
	if(tid > mesh->highest_tid) 
		mesh->highest_tid = tid;
	if(p3)
	{
		float	v1[3] = { p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]};
		float	v2[3] = { p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]};
		vec3_cross(f->normal,v1,v2);
		vec3f_normalize(f->normal);
	}
	else
	{
		f->normal[0] = f->normal[2] = 0.0f;
		f->normal[1] = 1.0f;
	}
	
	f->degree = p4 ? 4 : (p3 ? 3 : 2);
	
	f->vertex[0] = mesh->vertices + mesh->vertex_count++;
	f->vertex[1] = mesh->vertices + mesh->vertex_count++;
	f->vertex[2] = p3 ? mesh->vertices + mesh->vertex_count++ : NULL;
	f->vertex[3] = p4 ? (mesh->vertices + mesh->vertex_count++) : NULL;

	f->neighbor[0] = f->neighbor[1] = f->neighbor[2] = f->neighbor[3] = UNKNOWN_FACE;		
	f->t_list[0] = f->t_list[1] = f->t_list[2] = f->t_list[3] = NULL;

	f->index[0] = f->index[1] = f->index[2] = f->index[3] = -1;
	f->flip[0] = f->flip[1] = f->flip[2] = f->flip[3] = -1;

	vec4f_copy(f->color, color);


	for(i = 0; i < f->degree; ++i)
	{
		vec3f_copy(f->vertex[i]->normal,f->normal);
		vec4f_copy(f->vertex[i]->color,color);
		f->vertex[i]->prev = f->vertex[i]->next = NULL;
	}	

	vec3f_copy(f->vertex[0]->location,p1);
	vec3f_copy(f->vertex[1]->location,p2);
	if(p3)
	vec3f_copy(f->vertex[2]->location,p3);
	if(p4)
	vec3f_copy(f->vertex[3]->location,p4);

	f->vertex[0]->index = 0;
	f->vertex[1]->index = 1;
	if(f->vertex[2])
	f->vertex[2]->index = 2;
	if(f->vertex[3])
	f->vertex[3]->index = 3;

	f->vertex[0]->face = 
	f->vertex[1]->face = f;
	if(f->vertex[2])
	f->vertex[2]->face = f;
	if(f->vertex[3])
	f->vertex[3]->face = f;
}

// Utility: this is the visior used to snap vertices to each other.
// Snapping is done by linking nearby vertices into a ring whose
// centroid is later found.
static void visit_vertex_to_snap(struct Vertex * v, void * ref)
{
	struct Vertex * o = (struct Vertex *) ref;
	struct Vertex * p, * n;
	if(o != v)
	{
		assert(!vec3f_eq(o->location,v->location));
		
		if(vec3f_length2(o->location, v->location) < EPSI2)
		{
			
			// Check if o is already in v's sybling list BEFORE v.  If so, bail.
			for(n = v->prev; n; n = n->prev)
			if(n == o)
				return;
			
			// Scan forward to find last node in v's list.  
			n = v;
			assert(n != o);
			while(n->next)
			{
				n = n->next;
				if(n == o)		// Already connected to o?  Eject!
					return;	
			}
			
			p = o;
			assert(p != v);
			while(p->prev)
			{
				p = p->prev;
				assert(p != v);	// this would imply our linkage is not doubly linked.
			}
			
			assert(n->next == NULL);
			assert(p->prev == NULL);
			n->next = p;
			p->prev = n;		
		}
	}
}

// This function does a bunch of post-geometry-adding processing:
// 1. It sorts the vertices in XYZ order for correct indexing.  This
// forces colocated vertices together in the list.
// 2. It indexes vertices into an R-tree.
// 3. It performs a two-step snapping process by 
// 3a. Locating rings of too-close vertices and
// 3b. Setting each member of the ring to the ring's centroid location.
// 4. Vertices are resorted AGAIN.
// 5. The links from faces to vertices must be rebuilt due to sorting.
// 6. Degenerate quads/tris are marked as 'creased' on all sides.
//
// Notes:
// 2 and 4 are BOTH necessary - the first sort is needed to pre-sorted
// the data for the R-tree interface.  
// The second sort is needed because the order of sort is ruined by 
// changing XYZ geometry locations.
//
// Re: 6, we don't want to delete degenerate quads (a degen quad
// might be a visible triangle) but passing degenerate geometry to the
// smoother causes problems - so instead we 'seal off' this geometry to
// avoid further problems.
void				finish_faces_and_sort(struct Mesh * mesh)
{
	int v, f;
	int total_before = 0, total_after = 0;

	// sort vertices by 10 params
	sort_vertices_3(mesh->vertices,mesh->vertex_count);

	mesh->index = index_vertices(mesh->vertices,mesh->vertex_count);
	
	#if DEBUG
	validate_vertex_sort_3(mesh);
	#endif
	
	
	for(v = 0; v < mesh->vertex_count; ++v)
	{
		if(v == 0 || compare_points(mesh->vertices[v-1].location,mesh->vertices[v].location) != 0)
		{
			++total_before;
			struct Vertex * vi = mesh->vertices + v;
			float mib[3] = { vi->location[0] - EPSI, vi->location[1] - EPSI, vi->location[2] - EPSI };
			float mab[3] = { vi->location[0] + EPSI, vi->location[1] + EPSI, vi->location[2] + EPSI };
			scan_rtree(mesh->index, mib, mab, visit_vertex_to_snap, vi);
		}
	}
	
	for(v = 0; v < mesh->vertex_count; ++v)
	if(v == 0 || compare_points(mesh->vertices[v-1].location,mesh->vertices[v].location) != 0)
	if(mesh->vertices[v].prev == NULL)
	{
		if(mesh->vertices[v].next != NULL)
		{
			struct Vertex * i;
			float count = 0.0f;
			float p[3] = { 0 };
			for(i=mesh->vertices+v;i;i=i->next)
			{
				count += 1.0f;
				p[0] += i->location[0];
				p[1] += i->location[1];
				p[2] += i->location[2];
			}
			
			assert(count > 0.0f);
			count = 1.0f / count;
			p[0] *= count;
			p[1] *= count;
			p[2] *= count;
			
			i = mesh->vertices+v;
			while(i)
			{
				int has_more = 0;
				struct Vertex * k = i;
				i = i->next;
				do
				{
					has_more = 
						(k+1) < mesh->vertices+mesh->vertex_count &&
							compare_points(k->location,(k+1)->location) == 0;
										
					k->location[0] = p[0];
					k->location[1] = p[1];
					k->location[2] = p[2];
					k->prev = NULL;
					k->next = NULL;			
					++k;
				} while(has_more);

			}
		}
		
		++total_after;
	}
	// printf("BEFORE: %d, AFTER: %d\n", total_before, total_after);

	sort_vertices_3(mesh->vertices,mesh->vertex_count);

	// then re-build ptr indices into faces since we moved vertices
	for(v = 0; v < mesh->vertex_count; ++v)
	{
		mesh->vertices[v].face->vertex[mesh->vertices[v].index] = mesh->vertices+v;
	}
	
	for(f = 0; f < mesh->face_count; ++f)
	{
		if(mesh->faces[f].degree == 3)
		{
			float * p1 = mesh->faces[f].vertex[0]->location;
			float * p2 = mesh->faces[f].vertex[1]->location;
			float * p3 = mesh->faces[f].vertex[2]->location;
			if (compare_points(p1,p2)==0 ||
				compare_points(p2,p3)==0 ||
				compare_points(p1,p3)==0)
			{
				mesh->faces[f].neighbor[0] = 
				mesh->faces[f].neighbor[1] = 
				mesh->faces[f].neighbor[2] = 
				mesh->faces[f].neighbor[3] = NULL;
			}

		}
		if(mesh->faces[f].degree == 4)
		{
			float * p1 = mesh->faces[f].vertex[0]->location;
			float * p2 = mesh->faces[f].vertex[1]->location;
			float * p3 = mesh->faces[f].vertex[2]->location;
			float * p4 = mesh->faces[f].vertex[3]->location;

			if (compare_points(p1,p2)==0 ||
				compare_points(p2,p3)==0 ||
				compare_points(p1,p3)==0 ||
				compare_points(p3,p4)==0 ||
				compare_points(p2,p4)==0 ||
				compare_points(p1,p4)==0)
			{
				mesh->faces[f].neighbor[0] = 
				mesh->faces[f].neighbor[1] = 
				mesh->faces[f].neighbor[2] = 
				mesh->faces[f].neighbor[3] = NULL;
			}
		}
	}

	#if DEBUG
	validate_vertex_sort_3(mesh);
	validate_vertex_links(mesh);
	
	#if SLOW_CHECKING
	{
		int i, j;
		for(i = 0; i < mesh->vertex_count; ++i)
		for(j = 0; j < i; ++j)
		{
			if(!vec3f_eq(mesh->vertices[i].location,mesh->vertices[j].location))
			{
				if(vec3f_length2(mesh->vertices[i].location,mesh->vertices[j].location) <= CHECK_EPSI2)
					mesh->flags |= TINY_RESULTING_GEOM;					
			}
		}
	}
	#endif
	
	#endif
	
}

// Utility function: this marks one edge as a crease - the edge is identified by its
// location.
static void				add_crease(struct Mesh * mesh, const float p1[3], const float p2[3])
{
	struct Vertex * begin, * end, *v;
	
	float pp1[3] = { p1[0], p1[1],p1[2] };
	float pp2[3] = { p2[0], p2[1],p2[2] };

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

// This marks every line added to the mesh as a crease.  This
// ensures we won't smooth across our type 2 lines.
void add_creases(struct Mesh * mesh)
{
	int fi;
	struct Face * f;
	
	for(fi = mesh->poly_count; fi < mesh->face_count; ++fi)
	{
		f = mesh->faces+fi;
		assert(f->degree == 2);
		add_crease(mesh, f->vertex[0]->location, f->vertex[1]->location);		
	}
}

// Once all creases have been marked, this routine locates all colocated mesh
// edges going in opposite directions (opposite direction colocated edges mean
// the faces go in the same direction) that are not already marked as neighbors
// or creases.  If the potential join between faces is too sharp, it is marked
// as a crease, otherwise the edges are recorded as neighbors of each other.
// When we are done every polygon edge is a crease or neighbor of someone.
void				finish_creases_and_join(struct Mesh * mesh)
{
	int fi;
	int i;
	struct Face * f;
	
	for(fi = 0; fi < mesh->poly_count; ++fi)
	{
		f = mesh->faces+fi;
		assert(f->degree >= 3);
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
//				range_for_point(mesh->vertices,mesh->vertex_count,&begin,&end,p1->location);
				range_for_vertex(mesh->vertices,mesh->vertices + mesh->vertex_count,&begin,&end,p1);
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
					if(dst->face->degree > 2)
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
					if(inv->face->degree > 2)
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

// Utility function: given a vertex (for a specific face) this 
// returns a relative weighting for smoothing based on the normal
// of this tri.  This is doen using trig - the angle that the triangle
// circulates around the vertex defines its contribution to smoothing.
// This ensures subdivision of triangles produces weights that sum to be
// equal to the original face, and thus subdivision doesn't change our
// normals (which is what we would hope for).
static float weight_for_vertex(struct Vertex * v)
{
	return 1.0f;
	struct Vertex * prev = v->face->vertex[CCW(v->face,v->index)];
	struct Vertex * next = v->face->vertex[CW (v->face,v->index)];
	float v1[3],v2[3], d;
	vec3f_diff(v1,v->location,prev->location);
	vec3f_diff(v2,v->location,next->location);
	vec3f_normalize(v1);
	vec3f_normalize(v2);
	
	d=vec3f_dot(v1,v2);
	if(d > 1.0f) d = 1.0f;
	if(d < -1.0f) d = -1.0f;
	return acos(d);
}

// Once all neighbors have been found, this routine calculates the
// actual per-vertex smooth normals.  This is done by circulating
// each vertex (via its neighbors) to find all contributing triangles,
// computing a weighted average (from for each triangle) and applying
// the new averaged normal to all participating vertices.
//
// A few key points:
// - Circulation around the vertex only goes by neigbhor.  So creases
// (lack of a neighbor) partition the triangles around our vertex into
// adjacent groups, each of which get their own smoothing.
// - This is what makes a 'creased' shape flat-shaded: the creases keep
// us from circulating more than one triangle.
// - We weight our average normal by the angle the triangle spans around
// the vertex, not just a straight average of all participating triangles.
// We do not want to bias our normal toward the direction of more small
// triangles.
void				smooth_vertices(struct Mesh * mesh)
{
	int f;
	int i;
	for(f = 0; f < mesh->poly_count; ++f)
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
		float w;
		do {
			++ctr;
			//printf("\tAdd: %f,%f,%f\n",c->normal[0],c->normal[1],c->normal[2]);
			
			w = weight_for_vertex(c);
			
			if(vec3f_dot(v->face->normal,c->face->normal) > 0.0)
			{
				N[0] += w*c->face->normal[0];
				N[1] += w*c->face->normal[1];
				N[2] += w*c->face->normal[2];
			}
			else
			{
				N[0] -= w*c->face->normal[0];
				N[1] -= w*c->face->normal[1];
				N[2] -= w*c->face->normal[2];
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
				w = weight_for_vertex(c);
				if(vec3f_dot(v->face->normal,c->face->normal) > 0.0)
				{
					N[0] += w*c->face->normal[0];
					N[1] += w*c->face->normal[1];
					N[2] += w*c->face->normal[2];
				}
				else
				{
					N[0] -= w*c->face->normal[0];
					N[1] -= w*c->face->normal[1];
					N[2] -= w*c->face->normal[2];
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

// This routine merges vertices that have the same complete (10-float)
// value to optimize down the size of geometry in VRAM.  We do this
// by resorting by all components and then recognizing adjacently equal
// vertices.  This routine rebuilds the ptrs from triangles so that all
// faces see the 'shared' vertex.  By convention the first of a group
// of equal vertices in the vertex array is the one we will keep/use.
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
		}
		mesh->vertices[v].face->vertex[mesh->vertices[v].index] = first_of_equals;
		if(mesh->vertices+v == first_of_equals)
		{
			mesh->vertices[v].index = -1;
			++unique;
		}
		else
			mesh->vertices[v].index = -2;
	}

	#if DEBUG
	validate_vertex_sort_10(mesh);
	#endif
	mesh->unique_vertex_count = unique;
	//printf("Before: %d vertices, after: %d\n", mesh->vertex_count, unique);
}

// This returns the final counts for vertices and indices in a mesh - after merging,
// subdivising, etc. our original counts may be changed, so clients need to know
// how much VBO space to allocate.
void 	get_final_mesh_counts(struct Mesh * m, int * total_vertices,int * total_indices)
{
	*total_vertices = m->unique_vertex_count;
	*total_indices = m->vertex_count;
}

// This cleans our mesh, deallocating all internal memory.
void				destroy_mesh(struct Mesh * mesh)
{
	int f,i;
	#if DEBUG
	#if SLOW_CHECKING
		if(mesh->flags & TINY_INITIAL_TRIANGLE)	
			printf("ERROR: TINY INITIAL TRIANGLE.\n");
		if(mesh->flags & TINY_RESULTING_GEOM)		
			printf("ERROR: TINY RESULTING GEOMETRY.\n");
	#endif
	#endif

	destroy_rtree(mesh->index);
	
	for(f = 0; f < mesh->face_count; ++f)
	{
		struct Face * fp = mesh->faces+f;
		for(i = 0; i < fp->degree; ++i)
		{
			struct VertexInsert * tj, *k;
			tj = fp->t_list[i];
			while(tj)
			{
				k = tj;
				tj = tj->next;
				free(k);
			}
		}
	}
	
	free(mesh->vertices);
	free(mesh->faces);
	free(mesh);
}

// This routine writes out the final smoothed mesh.  It takes:
// - Buffer space for the vertex table (10x floats per vertex)
// - Buffer space for the indices (1 uint per index)
// - Pointers to variable-sized arrays to take the start/count for
// each kind of primitive for each TID.  
// In other words, out_line_starts[0] contains the offset into our
// index buffer of the lines for TID 0.  out_quad_counts[2] contains
// the number of indices for all quads in TID 2.
// max(tids)+1 ints should be allocated for each output array.
//
// The indices are written in TID order, so that at most three draw calls
// (one each for tris, lines and quads) can be used to draw each TID's
// collection of geometry.  Primitives are also output in order.
//
// (In other words, the primary sort key is TID, second is primitive type.)
void				write_indexed_mesh(
							struct Mesh *			mesh,
							int						vertex_table_size,
							volatile float *		io_vertex_table,							
							int						index_table_size,
							volatile unsigned int *	io_index_table,
							int						index_base,
							int						out_line_starts[],
							int						out_line_counts[],
							int						out_tri_starts[],
							int						out_tri_counts[],
							int						out_quad_starts[],
							int						out_quad_counts[])
{
	int * starts[5] = { NULL, NULL, out_line_starts, out_tri_starts, out_quad_starts };
	int * counts[5] = { NULL, NULL, out_line_counts, out_tri_counts, out_quad_counts };

	volatile float * vert_ptr = io_vertex_table;
	#if DEBUG
	assert(vertex_table_size == mesh->unique_vertex_count);
	assert(index_table_size == mesh->vertex_count);
	volatile float * vert_stop = io_vertex_table + (vertex_table_size * 10);
	#endif
	volatile unsigned int * index_ptr = io_index_table;
	#if DEBUG	
	volatile unsigned int * index_stop = io_index_table + index_table_size;
	#endif
	
	int cur_idx = index_base;
	
	int d, i, vi, ti;
	struct Vertex * v, *vv;
	struct Face * f;

	// Outer loop: we are going to make one pass over the vertex array
	// for each depth of primitive - in other words, we are going to
	// 'fish out' all lines first, then all tris, then all quads.
	for(ti = 0; ti <= mesh->highest_tid; ++ti)
	for(d = 2; d <= 4; ++d)
	{
		starts[d][ti] = index_ptr - io_index_table;
		
		for(vi = 0; vi < mesh->vertex_count; ++vi)
		{
			v = mesh->vertices+vi;
			f = v->face;

			// For each vertex, we look at its face if it qualifies.
			// This way we write the faces in sorted vertex order.
			if(f->degree == d)
			if(f->tid == ti)
			{
				for(i = 0; i < d; ++i)
				{
					vv = f->vertex[i];
					assert(vv->index != -2);
					// To write out our vertices, we MAY need to
					// write out the vertex if it is first used.
					// Thus the vertices go down in approximate usage
					// order, which is good.
					if(vv->index == -1)
					{
						vv->index = cur_idx++;
						
						*vert_ptr++ = vv->location[0];
						*vert_ptr++ = vv->location[1];
						*vert_ptr++ = vv->location[2];

						*vert_ptr++ = vv->normal[0];
						*vert_ptr++ = vv->normal[1];
						*vert_ptr++ = vv->normal[2];

						*vert_ptr++ = vv->color[0];
						*vert_ptr++ = vv->color[1];
						*vert_ptr++ = vv->color[2];
						*vert_ptr++ = vv->color[3];						
					}
					
					assert(vv->index >= 0);
					
					*index_ptr++ = vv->index;
				}
				
				// when the face is done, we mark it via degree = 0 so we 
				// don't hit it again when we hit one of its vertices due to
				// sharing.
				f->degree = 0;

			} // end of face write-out for matched faces
			
		} // end of linear vertex walk

		counts[d][ti] = (index_ptr - io_index_table) - starts[d][ti];
	

	} // end of primitve sort
	
	assert(vert_ptr == vert_stop);
	assert(index_ptr == index_stop);
}





#pragma mark -
//==============================================================================
//	T JUNCTION REMOVAL
//==============================================================================

// This code attempts to remove "T" junctions from a mesh.  Since an ASCII 
// picture is worth 1000 words...
//
//    B            B
//   /|\          /|\
//  / | \        / | \
// A  C--E  ->  A--C--E
//  \ | /        \ | /
//   \|/          \|/
//    D            D
//
// Given 3 triangles ADB, BCE, and CDE, we have a T junction at "C" - the vertex C
// is colinear with hte edge DB (as part of ADB), and this is bad.  This is bad 
// because: (1) C's normal contributions won't include ADB (since C is not a vertex
// of ADB) and (2) we may get a cracking artifact at C from the graphics card.
//
// We try to fix this by subdividing DB at C to produce two triangles ADC and ACB.
//
// IMHO: T junction removal sucks.  It's hard to set up the heuristics to get good
// junction removal, huge numbers of tiny triangles can be added, and the models 
// that need it are usually problematic enough that it doesn't work, while slowing
// down smoothing and increasing vertex count.  I recommend that clients _not_ use
// this functionality - rather T junctions should probably be addressed by:
//
// 1. Fixing the source parts that cause T junctions and
// 2. Aggressively adopting textures for complex patterned parts.
//


// When we are looking for T junctions, we use this structure to 'remember' which
// edge we are working on from the R-tree visitor.

struct t_finder_info_t { 
	int split_quads;			// The number of quads that have been split.  Each quad with a 
								// subdivision must be triangulated, changing our face count, so 
								// we have to track this.
	int inserted_pts;			// Number of points inserted into edges - this increases triangle
								// count so we must track it.
	struct Vertex * v1;			// Start and end vertices of the edge we are testing.
	struct Vertex * v2;
	struct Face * f;			// The face that v1/v2 belong to.
	int i;						// The side index i of face f that we are tracking, e.g. f->vertices[i] == v1
	float line_dir[3];			// A normalized direction vector from v1 to v2, used to order the intrusions.
};


// This is the call back that gets called once for each vertex V that _might_ be near an edge (e.g. 
// via a bounding box test).  We project the point onto the line and see how far the intruding point
// is from the projection on the line.  If the point is close, it's a T junction and we record it
// on a linked list ƒor this side, in order of distanec along the line.
//
// Since (1) duplicate vertices are not processed and (2) near-duplicate vertices were removed long ago
// and (3) the bounding box ensures that our point is 'within' the line segment's span, any near-line
// point _is_ a T.
void visit_possible_t_junc(struct Vertex * v, void * ref)
{
	struct t_finder_info_t * info = (struct t_finder_info_t *) ref;
	assert(!vec3f_eq(info->v1->location,info->v2->location));
	if(!vec3f_eq(v->location,info->v1->location) && !vec3f_eq(v->location,info->v2->location))
	if(in_between_line(info->v1->location,v->location,info->v2->location))
	{
		float proj_p[3];
		proj_onto_line(proj_p, info->v1->location,info->line_dir, v->location);

		float dist2_lat = vec3f_length2(v->location, proj_p);
		float dist2_lon = vec3f_length2(v->location, info->v1->location);
					
		if (dist2_lat < EPSI2)
		{
			assert(info->f->degree == 4 || info->f->degree == 3);
			if(info->f->degree == 4)
			if(info->f->t_list[0] == NULL &&
				info->f->t_list[1] == NULL &&
				info->f->t_list[2] == NULL &&
				info->f->t_list[3] == NULL)
			++info->split_quads;
			++info->inserted_pts;
			struct VertexInsert ** prev = &info->f->t_list[info->i];
			
			while(*prev && (*prev)->dist < dist2_lon)
				prev = &(*prev)->next;
				
			struct VertexInsert * vi = (struct VertexInsert *) malloc(sizeof(struct VertexInsert));
			vi->dist = dist2_lon;
			vi->vert = v;
			vi->next = *prev;
			*prev = vi;
			
//			printf("possible T %f: %f,%f,%f (%f,%f,%f -> %f,%f,%f)\n",
//				sqrtf(dist2_lon),
//				v->location[0],v->location[1],v->location[2],
//				info->v1->location[0],info->v1->location[1],info->v1->location[2],
//				info->v2->location[0],info->v2->location[1],info->v2->location[2]);
		}
	}
}

// Given a convex polygon (specified by an interleaved XYZ array "poly" and pt_count points, this routine
// cuts down the degree of the polygon by cutting off an 'ear' (that is, a non-reflex vertex).  The ear is
// added as a triangle, and the polygon loses a vertex.  This is done by cutting off the sharpest corners 
// first.
//
// BEFORE:     AFTER
//
// A--B--C    A--B
// |     |    |   \
// |     |    |    \
// D     E    D     E
// |     |    |     |
// F--G--H    F--G--H
//
// (BEC is added as a new trinagle.)

void add_ear_and_remove(float * poly, int pt_count, struct Mesh * target_mesh, const float * color, int tid)
{
	int i, p, n, b = -1;
	float best_dot = -99.0;

	for(i = 0; i < pt_count; ++i)
	{
		float * p1, * p2, * p3;
		float v1[3], v2[3];
		float dot;
		
		p = (i + pt_count - 1) % pt_count;
		n = (i + 1) % pt_count;
		p1 = poly + 3 * p;
		p2 = poly + 3 * i;
		p3 = poly + 3 * n;
		
		vec3f_diff(v1,p2,p1);
		vec3f_diff(v2,p2,p3);
		vec3f_normalize(v1);
		vec3f_normalize(v2);
		
		dot = vec3f_dot(v1,v2);
		if(dot > best_dot || b == -1)
		{
			best_dot = dot;
			b = i;
		}
	}
	
	assert(b >= 0);
	assert(b < pt_count);
	
	p = (b + pt_count - 1) % pt_count;
	n = (b + 1) % pt_count;
	
	add_face(target_mesh,poly+3*p,poly+3*b,poly+3*n,NULL,color,tid);
	
	if(b != pt_count-1)
	{
		memmove(poly+3*b,poly+3*b+3,(pt_count-b-1)*3*sizeof(float));
	}
	
}


// This routine finds and removes all T junctions from the mesh.  It does this by...
// For each non-creased edge (we don't de-T creases for speed) we R-tree search for
// all T-forming vertices and put them in a sorted linked list by edge.
//
// Then we build a brand new copy of our mesh and peel off ears for each interference
// as new triangles.  When done, we're left with triangles that we also add.
// 
// Finall we redo a bunch of processing we already did, now that we have a new mesh.
void find_and_remove_t_junctions(struct Mesh * mesh)
{
	assert(mesh->vertex_count == mesh->vertex_capacity);
	assert(mesh->face_count == mesh->face_capacity);
	struct t_finder_info_t	info;
	int fi;
	info.inserted_pts = 0;
	info.split_quads = 0;

	
	for(fi = 0; fi < mesh->poly_count; ++fi)
	{
		info.f = mesh->faces+fi;
		if(info.f->degree > 2)
		for(info.i = 0; info.i < info.f->degree; ++info.i)
		{
			// Sad -- this is not a win - this info is not yet available. :-(
			if(info.f->neighbor[info.i] == NULL)
				continue;
				
			info.v1 = info.f->vertex[ info.i					 ];
			info.v2 = info.f->vertex[(info.i+1)%info.f->degree];
			
			if(vec3f_eq(info.v1->location,info.v2->location))
				continue;
			
			info.line_dir[0] = info.v2->location[0] - info.v1->location[0];
			info.line_dir[1] = info.v2->location[1] - info.v1->location[1];
			info.line_dir[2] = info.v2->location[2] - info.v1->location[2];
//			vec3f_normalize(info.line_dir);
			
			float mib[3] = { 
								MIN(info.v1->location[0],info.v2->location[0]) - EPSI,
								MIN(info.v1->location[1],info.v2->location[1]) - EPSI,
								MIN(info.v1->location[2],info.v2->location[2]) - EPSI };

			float mab[3] = { 
								MAX(info.v1->location[0],info.v2->location[0]) + EPSI,
								MAX(info.v1->location[1],info.v2->location[1]) + EPSI,
								MAX(info.v1->location[2],info.v2->location[2]) + EPSI };
								
			scan_rtree(mesh->index, mib, mab, visit_possible_t_junc, &info);
		}
	}


	//printf("Subdivided %d quads and added %d pts.\n", info.split_quads,info.inserted_pts);
	if(info.inserted_pts > 0)
	{
		int f;
		struct Mesh * new_mesh;
		assert(info.split_quads <= mesh->quad_count);
		new_mesh = create_mesh(
							mesh->tri_count + info.inserted_pts + 2 * info.split_quads,
							mesh->quad_count - info.split_quads,
							mesh->line_count);

		for(f = 0; f < mesh->face_count; ++f)
		{
			struct Face * fp = mesh->faces+f;
			if(fp->t_list[0] == NULL &&
				fp->t_list[1] == NULL &&
				fp->t_list[2] == NULL &&
				fp->t_list[3] == NULL)
			{
				switch(fp->degree) {
				case 2:
					add_face(new_mesh,fp->vertex[0]->location,fp->vertex[1]->location,NULL,NULL,fp->color,fp->tid);
					break;
				case 3:
					add_face(new_mesh,fp->vertex[0]->location,fp->vertex[1]->location,fp->vertex[2]->location,NULL,fp->color,fp->tid);
					break;
				case 4:
					add_face(new_mesh,fp->vertex[0]->location,fp->vertex[1]->location,fp->vertex[2]->location,fp->vertex[3]->location,fp->color,fp->tid);
					break;
				default:
					assert(!"bad degree.");
				}
			}
			else
			{
				int i;
				int total_pts = 0;
				struct VertexInsert * vp;
				float * poly, * write_ptr;
				for(i = 0; i < fp->degree; ++i)
				{
					++total_pts;
					for(vp = fp->t_list[i]; vp; vp = vp->next)
						++total_pts;
				}
				
				poly = (float *) malloc(sizeof(float) * 3 * total_pts);
				write_ptr = poly;

				for(i = 0; i < fp->degree; ++i)
				{
					memcpy(write_ptr, fp->vertex[i]->location,3*sizeof(float));
					write_ptr += 3;

					for(vp = fp->t_list[i]; vp; vp = vp->next)
					{
						memcpy(write_ptr, vp->vert->location,3*sizeof(float));
						write_ptr += 3;
					}
				}
				
				while(total_pts > 3)
				{
					add_ear_and_remove(poly,total_pts,new_mesh,fp->color, fp->tid);
					--total_pts;
				}
				
				add_face(new_mesh,poly,poly+3,poly+6,NULL,fp->color, fp->tid);
				free(poly);				
			}
		}

		assert(new_mesh->vertex_count == new_mesh->vertex_capacity);
		assert(new_mesh->face_count == new_mesh->face_capacity);

		finish_faces_and_sort(new_mesh);
		add_creases(new_mesh);
		
		struct Mesh temp;
		
		memcpy(&temp,mesh,sizeof(struct Mesh));
		memcpy(mesh,new_mesh,sizeof(struct Mesh));
		memcpy(new_mesh,&temp,sizeof(struct Mesh));
		
		destroy_mesh(new_mesh);
		
		
	}
}

