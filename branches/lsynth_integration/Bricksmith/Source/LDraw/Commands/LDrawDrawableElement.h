//==============================================================================
//
// File:		LDrawDrawableElement.h
//
// Purpose:		Abstract superclass for all LDraw elements that can actually be 
//				drawn (polygons and parts).
//
//  Created by Allen Smith on 4/20/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "ColorLibrary.h"
#import "LDrawDirective.h"
#import "MatrixMath.h"

typedef struct
{
	GLfloat position[3];
	GLfloat normal[3];
	GLfloat color[4];
	
} VBOVertexData;


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawDrawableElement
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawDrawableElement : LDrawDirective <LDrawColorable, NSCoding>
{
	LDrawColor  *color;
	BOOL        hidden;		//YES if we don't draw this.
}

// Directives
- (VBOVertexData *) writeToVertexBuffer:(VBOVertexData *)vertexBuffer parentColor:(LDrawColor *)parentColor wireframe:(BOOL)wireframe;
- (void) drawElement:(NSUInteger)optionsMask viewScale:(float)scaleFactor withColor:(LDrawColor *)drawingColor;
- (VBOVertexData *) writeElementToVertexBuffer:(VBOVertexData *)vertexBuffer withColor:(LDrawColor *)drawingColor wireframe:(BOOL)wireframe;


// Accessors
- (Box3) projectedBoundingBoxWithModelView:(Matrix4)modelView
								projection:(Matrix4)projection
									  view:(Box2)viewport;
- (BOOL) isHidden;
- (Point3) position;

- (void) setHidden:(BOOL)flag;

// Actions
- (Vector3) displacementForNudge:(Vector3)nudgeVector;
- (void) moveBy:(Vector3)moveVector;
- (Point3) position:(Point3)position snappedToGrid:(float)gridSpacing;

@end
