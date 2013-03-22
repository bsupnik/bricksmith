/*
 *  MeshSmooth.h
 *  Bricksmith
 *
 *  Created by bsupnik on 3/10/13.
 *  Copyright 2013 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef MeshSmooth_H
#define MeshSmooth_H

struct	Tri;
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


struct Face {
	int					degree	   ;
	struct Vertex *		vertex  [4];		// Vertices - 0,1,2 is CCW traversal
	struct Face *		neighbor[4];		// Neighbors - numbered by SOURCE vertex
	int					index	[4];		// Index of our neighbor edge's source in neighbor.
	int					flip	[4];		// Indicates that our neighbor is winding-flipped from us!

	float				normal[3];			// Whole-face properties
	float				color[4];
};

struct Vertex {
	float			location[3];			
	float			normal[3];
	float			color[4];
	int				index;
	struct Face *	face;
	struct Vertex *	next;
	struct Vertex * prev;
};

#define LEAF_DIM 8

struct RTree_node {
	float min_bounds[3];
	float max_bounds[3];
	struct RTree_node *	left;
	struct RTree_node * right;
};

struct RTree_leaf {
	float min_bounds[3];
	float max_bounds[3];
	int count;
	struct Vertex * vertices[LEAF_DIM];
};

#define IS_LEAF(n) (((intptr_t) (n) & 1) != 0)
#define GET_LEAF(n) ((struct RTree_leaf*) (((intptr_t) (n)) & ~1))
#define GET_CLEAN(n) ((struct RTree_node*) (((intptr_t) (n)) & ~1))

struct Mesh {
	int					vertex_count;
	int					vertex_capacity;
	int					unique_vertex_count;
	struct Vertex *		vertices;
	
	int					face_count;
	int					tri_count;
	int					quad_count;
	int					poly_count;
	int					line_count;
	int					face_capacity;
	struct Face *		faces;	
	
	struct RTree_node *	index;
};


struct Mesh *		create_mesh(int tri_count, int quad_count, int line_count);

void				add_face(struct Mesh * mesh, const float p1[3], const float p2[3], const float p3[3], const float p4[3], const float color[4]);
void				finish_faces_and_sort(struct Mesh * mesh);

//void				add_crease(struct Mesh * mesh, const float p1[3], const float p2[3]);
void				finish_creases_and_join(struct Mesh * mesh);

void				smooth_vertices(struct Mesh * mesh);

int					merge_vertices(struct Mesh * mesh);	// Returns the number of unique vertices after merging.

void				write_indexed_mesh(
							struct Mesh *			mesh,
							int						vertex_table_size,
							volatile float *		io_vertex_table,							
							int						index_table_size,
							volatile unsigned int *	io_index_table,
							int						index_base,
							int						out_prim_starts[5],
							int						out_prim_counts[5]);

void				destroy_mesh(struct Mesh * mesh);

#endif /* MeshSmooth_H */
