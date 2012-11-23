//==============================================================================
//
// File:		LDrawQuadrilateral.h
//
// Purpose:		Quadrilateral primitive command.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDirective.h"

#import "LDrawDrawableElement.h"

////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawQuadrilateral
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawQuadrilateral : LDrawDrawableElement <NSCoding>
{
	Point3		vertex1;
	Point3		vertex2;
	Point3		vertex3;
	Point3		vertex4;
	
	Vector3		normal;

	NSArray		*dragHandles;
}

// Directives
- (NSString *) write;

//Accessors
- (Point3) vertex1;
- (Point3) vertex2;
- (Point3) vertex3;
- (Point3) vertex4;
-(void) setVertex1:(Point3)newVertex;
-(void) setVertex2:(Point3)newVertex;
-(void) setVertex3:(Point3)newVertex;
-(void) setVertex4:(Point3)newVertex;

//Utilities
- (void) fixBowtie;
- (void) recomputeNormal;

@end
