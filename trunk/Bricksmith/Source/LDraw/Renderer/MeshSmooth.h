/*
 *  MeshSmooth.h
 *  Bricksmith
 *
 *  Created by bsupnik on 3/10/13.
 *  Copyright 2013. All rights reserved.
 *
 */

#ifndef MeshSmooth_H
#define MeshSmooth_H

//==============================================================================
//
// File: MeshSmooth
//
// MeshSmooth is a set of C functions that merge triangle meshes and calculate
// smoothed normals in a way that happens to be usefor for LDraw models.  
// MeshSmooth takes care of the following processing:
//
// - "Welding" very-close vertices that do not have the exact same location due
//   to rounding errors in sub-part matrix transforms.
//
// - Optionally locating T junctions and subdividing the faces.
//
// - Determining smooth and creased edges basde on the presence of lines and 
//   crease angles.
//
// - Resolving BFC errors.  (The normals are generated correctly for two-sided
//   lighting, but no attempt to determine a front is made; the output must 
//   still support two-sided lighting and have culling disabled.)
//
// - Calculating smooth normals for shared vertices.
//
// - Merging vertices that are completely equal and calculating mesh indices.
//
// Usage:
//
// A client creates a mesh structure with a pre-declared count of tris, quads
// and lines, then adds them.
//
// Once all data is added, a series of processing functions are called to
// transform the data.
//
// Finally, for output, the final mesh counts are queried and written to storage
// provided by the client.  This API is suitable for writing directly to memory-
// mapped VBOs.
//
// Textures:
//
// Faces can be tagged with an integer "texture ID" TID; the API will track face
// TID and output the mesh in TID order.  This allows a single mesh to be drawn
// as a series of sub-draw-calls with texture changes in between them.
//
// Texture IDs should be sequential and zero based.
//
//==============================================================================


struct Mesh;

//==============================================================================
// Data input API
//==============================================================================

// Create a new mesh that will be smoothed.  Counts of tris, quads and lines 
// must be pre-declared exactly.
struct Mesh *		create_mesh(
							int					tri_count, 
							int					quad_count, 
							int					line_count);

// Add one face.  Pass NULL for p4 for tris, pass NULL for p3 and p4 for lines.
// Normals are not needed - the mesh alg calculates them for you.
// Always submit geometry quads and tris first (in any order), then all lines.
void				add_face(
							struct Mesh *		mesh, 
							const float			p1[3], 
							const float			p2[3], 
							const float			p3[3], 
							const float			p4[3], 
							const float			color[4], 
							int					tid);

//==============================================================================
// Data processing API
//==============================================================================

// Call these routines in order to smooth the mesh.
// Skip find_and_remove_t_junctions if you don't want to remove T junctions.
void				finish_faces_and_sort(struct Mesh * mesh);
void				find_and_remove_t_junctions(struct Mesh * mesh);
void				add_creases(struct Mesh * mesh);
void				finish_creases_and_join(struct Mesh * mesh);
void				smooth_vertices(struct Mesh * mesh);
void				merge_vertices(struct Mesh * mesh);

//==============================================================================
// Data output API
//==============================================================================

// get_final_mesh_counts returns the total number of vertices and indices that 
// will be output.
void				get_final_mesh_counts(
							struct Mesh *			m, 
							int *					total_vertices,
							int *					total_indices);

// writes the mesh data to buffers.  The vertex table must be 10 floats per
// vertex (xyz, normal, color).  Index base is the index number of the first
// vertex to be written - if the mesh has its own VBO, this should be 0.
// 
// For each texture IDs, a slot in the starts and counts array is used.  In
// other words, if your mesh has 3 TIDs (0,1,2) then out_line_starts should
// be an array of 3 ints.  Thus the start and offset of all primitives for
// all texture IDs are output in TID order.
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
							int						out_quad_counts[]);
							
// This releases all internal storage for the mesh when smoothing is complete.
void				destroy_mesh(struct Mesh * mesh);

#endif /* MeshSmooth_H */
