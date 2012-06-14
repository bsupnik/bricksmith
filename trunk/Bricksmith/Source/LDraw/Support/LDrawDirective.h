//==============================================================================
//
// File:		LDrawDirective.h
//
// Purpose:		This is an abstract base class for all elements of an LDraw 
//				document.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "MatrixMath.h"

@class LDrawColor;
@class LDrawContainer;
@class LDrawFile;
@class LDrawModel;
@class LDrawStep;


//A directive was modified, either explicitly by the user or by undo/redo.
// Object is the LDrawDirective that changed. No userInfo.
#define LDrawDirectiveDidChangeNotification				@"LDrawDirectiveDidChangeNotification"


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Drawing Mask bits and Constants
//
////////////////////////////////////////////////////////////////////////////////
#define DRAW_NO_OPTIONS							0
#define DRAW_WIREFRAME							1 << 1
#define DRAW_BOUNDS_ONLY						1 << 3


////////////////////////////////////////////////////////////////////////////////
//
// LDrawDirective
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawDirective : NSObject <NSCoding, NSCopying>
{

	LDrawContainer *enclosingDirective; //LDraw files are a hierarchy.
	BOOL			isSelected;
	
}

// Initialization
- (id) initWithLines:(NSArray *)lines inRange:(NSRange)range;
- (id) initWithLines:(NSArray *)lines inRange:(NSRange)range parentGroup:(dispatch_group_t)parentGroup;
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index inLines:(NSArray *)lines maxIndex:(NSUInteger)maxIndex;

// Directives
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor
;
- (void) hitTest:(Ray3)pickRay transform:(Matrix4)transform viewScale:(float)scaleFactor boundsOnly:(BOOL)boundsOnly creditObject:(id)creditObject hits:(NSMutableDictionary *)hits;
- (void) boxTest:(Box2)bounds transform:(Matrix4)transform viewScale:(float)scaleFactor boundsOnly:(BOOL)boundsOnly creditObject:(id)creditObject hits:(NSMutableSet *)hits;
- (NSString *) write;

// Display
- (NSString *) browsingDescription;
- (NSString *) iconName;
- (NSString *) inspectorClassName;

// Accessors
- (NSArray *)ancestors;
- (LDrawContainer *) enclosingDirective;
- (LDrawFile *) enclosingFile;
- (LDrawModel *) enclosingModel;
- (LDrawStep *) enclosingStep;
- (BOOL) isSelected;

- (void) setEnclosingDirective:(LDrawContainer *)newParent;
- (void) setSelected:(BOOL)flag;

// protocol Inspectable
- (void) lockForEditing;
- (void) unlockEditor;

// Utilities
- (BOOL) containsReferenceTo:(NSString *)name;
- (void) flattenIntoLines:(NSMutableArray *)lines
				triangles:(NSMutableArray *)triangles
		   quadrilaterals:(NSMutableArray *)quadrilaterals
					other:(NSMutableArray *)everythingElse
			 currentColor:(LDrawColor *)parentColor
		 currentTransform:(Matrix4)transform
		  normalTransform:(Matrix3)normalTransform
				recursive:(BOOL)recursive;
- (BOOL) isAncestorInList:(NSArray *)containers;
- (void) noteNeedsDisplay;
- (void) optimizeOpenGL;
- (void) optimizeVertexes;
- (void) registerUndoActions:(NSUndoManager *)undoManager;

@end
