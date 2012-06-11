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


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawPart
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawPart : LDrawDrawableElement <NSCoding>
{
	NSString		*displayName;
	NSString		*referenceName; //lower-case version of display name
	
	GLfloat			glTransformation[16];

	LDrawDirective	*optimizedDrawable;
	NSLock			*drawLock;
}

//Directives
- (void) drawBoundsWithColor:(LDrawColor *)drawingColor;
- (NSString *) write;

//Accessors
- (NSString *) displayName;
- (LDrawFile *) enclosingFile;
- (LDrawStep *) enclosingStep;
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
- (void) optimizeOpenGL;
- (void) removeDisplayList;

@end
