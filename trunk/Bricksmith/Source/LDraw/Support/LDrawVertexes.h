//==============================================================================
//
// File:		LDrawVertexes.h
//
// Purpose:		Receives primitives and transfers their vertexes into an 
//				OpenGL-optimized object. Drawing instances of this object will 
//				draw all the contained vertexes. 
//
// Modified:	11/16/2010 Allen Smith. Creation Date.
//
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"

@class LDrawLine;
@class LDrawTriangle;
@class LDrawQuadrilateral;

////////////////////////////////////////////////////////////////////////////////
struct OptimizationTags
{
	GLuint          linesVBOTag;
	GLuint          trianglesVBOTag;
	GLuint          quadsVBOTag;
	
	GLuint          linesVAOTag;
	GLuint          trianglesVAOTag;
	GLuint          quadsVAOTag;
	
	GLsizei			lineCount;
	GLsizei			triangleCount;
	GLsizei			quadCount;
	
	GLuint          displayListTag;
};


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawVertexes
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawVertexes : LDrawDirective
{
	NSMutableArray          *triangles;
	NSMutableArray          *quadrilaterals;
	NSMutableArray          *lines;
	
	NSMutableArray          *everythingElse;
	
	NSMutableDictionary		*colorOptimizations; // key is @"%f %f %f %f", value is OptimizationTags in NSValue
	NSMutableDictionary		*colorWireframeOptimizations; // key is @"%f %f %f %f", value is OptimizationTags in NSValue
}

// Accessors
- (BOOL) isOptimizedForColor:(LDrawColor *)parentColor;
- (void) setLines:(NSArray *)linesIn
		triangles:(NSArray *)trianglesIn
   quadrilaterals:(NSArray *)quadrilateralsIn
			other:(NSArray *)everythingElseIn;
			
- (void) addDirective:(LDrawDirective *)directive;
- (void) addLine:(LDrawLine *)line;
- (void) addTriangle:(LDrawTriangle *)triangle;
- (void) addQuadrilateral:(LDrawQuadrilateral *)quadrilateral;
- (void) addOther:(LDrawDirective *)other;

- (void) removeDirective:(LDrawDirective *)directive;
- (void) removeLine:(LDrawLine *)line;
- (void) removeTriangle:(LDrawTriangle *)triangle;
- (void) removeQuadrilateral:(LDrawQuadrilateral *)quadrilateral;
- (void) removeOther:(LDrawDirective *)other;

// Optimize
- (void) optimizeOpenGLWithParentColor:(LDrawColor *)parentColor;
- (void) optimizeSolidWithParentColor:(LDrawColor *)color;
- (void) optimizeWireframeWithParentColor:(LDrawColor *)color;
- (void) rebuildAllOptimizations;
- (void) removeAllOptimizations;

@end
