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
	GLuint          anyVBOTag;
	GLuint          anyVAOTag;

	GLint			lineOffset;
	GLint			triangleOffset;
	GLint			quadOffset;

	GLsizei			lineCount;
	GLsizei			triangleCount;
	GLsizei			quadCount;	
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
	BOOL					acceptsNonPrimitives;
	
	NSMutableDictionary		*colorOptimizations; // key is @"%f %f %f %f", value is OptimizationTags in NSValue
	NSMutableDictionary		*colorWireframeOptimizations; // key is @"%f %f %f %f", value is OptimizationTags in NSValue
	BOOL					needsRebuilding;
}

// Accessors
- (BOOL) isOptimizedForColor:(LDrawColor *)parentColor;
- (void) setLines:(NSArray *)linesIn
		triangles:(NSArray *)trianglesIn
   quadrilaterals:(NSArray *)quadrilateralsIn
			other:(NSArray *)everythingElseIn;
- (void) setAcceptsNonPrimitives:(BOOL)flag;
- (void) setVertexesNeedRebuilding;
			
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
