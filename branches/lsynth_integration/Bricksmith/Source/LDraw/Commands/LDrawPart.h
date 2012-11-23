//==============================================================================
//
// File:		LDrawPart.h
//
// Purpose:		Part command.
//				Inserts a part defined in another LDraw file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>
#import OPEN_GL_HEADER

#import "ColorLibrary.h"
#import "LDrawDirective.h"
#import "LDrawDrawableElement.h"
#import "MatrixMath.h"

@class LDrawFile;
@class LDrawModel;
@class LDrawStep;
@class PartReport;

typedef enum PartType {
	PartTypeUnresolved = 0,	// We have not yet tried to figure out what we have.
	PartTypeNotFound,		// We went looking and the part is missing.  This keeps us from retrying on every query until someone tells us to try again.
	PartTypeLibrary,		// Part is in the library.
	PartTypeSubmodel,		// Part is an MPD submodel from our parent LDrawFile
	PartTypePeerFile		// Part is the first model in another file in the same directory as us.
} PartTypeT;


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawPart
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawPart : LDrawDrawableElement <NSCoding, LDrawObserver>
{
@private
	NSString		*displayName;
	NSString		*referenceName; //lower-case version of display name
	
	GLfloat			glTransformation[16];

	LDrawDirective	*cacheDrawable;			// The drawable is the model we link to OR a VBO that represents it from the part library -- a drawable proxy.
	LDrawModel		*cacheModel;			// The model is the real model we link to.
	PartTypeT		cacheType;
	NSLock			*drawLock;
	
	Box3			cacheBounds;			// Cached bonuding box of resolved parts, in part's coordinate (that is, _not_ in the coordinates of the underlying model.
}

//Directives
- (void) drawBoundsWithColor:(LDrawColor *)drawingColor;
- (NSString *) write;

//Accessors
- (NSString *) displayName;
- (Point3) position;
- (NSString *) referenceName;
- (LDrawModel *) referencedMPDSubmodel;
- (TransformComponents) transformComponents;
- (Matrix4) transformationMatrix;
- (void) setDisplayName:(NSString *)newPartName;
- (void) setDisplayName:(NSString *)newPartName parse:(BOOL)shouldParse inGroup:(dispatch_group_t)parentGroup;
- (void) setTransformComponents:(TransformComponents)newComponents;
- (void) setTransformationMatrix:(Matrix4 *)newMatrix;

//Actions
- (void) collectPartReport:(PartReport *)report;
- (TransformComponents) componentsSnappedToGrid:(float) gridSpacing minimumAngle:(float)degrees;
- (TransformComponents) components:(TransformComponents)components snappedToGrid:(float)gridSpacing minimumAngle:(float)degrees;
- (void) rotateByDegrees:(Tuple3)degreesToRotate;
- (void) rotateByDegrees:(Tuple3)degreesToRotate centerPoint:(Point3)center;

//Utilities
- (BOOL) partIsMissing;

- (void) resolvePart;
- (void) unresolvePart;
- (void) unresolvePartIfPartLibrary;

- (void) optimizeOpenGL;
//- (void) removeDisplayList;

@end
