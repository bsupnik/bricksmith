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


struct Face {
	struct Vertex *		vertex  [3];		// Vertices - 0,1,2 is CCW traversal
	struct Face *		neighbor[3];		// Neighbors - numbered _opposite_ vertices!

	float				normal[3];			// Whole-face properties
	float				color[4];
};

struct Vertex {
	float			location[3];			
	float			normal[3];
	float			color[4];
	int				index;
	struct Face *	face;
};

struct Mesh {
	int					vertex_count;
	int					vertex_capacity;
	struct Vertex *		vertices;
	
	int					face_count;
	int					face_capacity;
	struct Face *		faces;	
};


struct Mesh *		create_mesh(int face_count);

void				add_face(struct Mesh * mesh, const float p1[3], const float p2[3], const float p3[3], const float normal[3], const float color[4]);
void				finish_faces_and_sort(struct Mesh * mesh);

void				add_crease(struct Mesh * mesh, const float p1[3], const float p2[3]);
void				finish_creases_and_join(struct Mesh * mesh);

void				smooth_vertices(struct Mesh * mesh);

void				merge_vertices(struct Mesh * mesh);

void				destroy_mesh(struct Mesh * mesh);

#endif /* MeshSmooth_H */
