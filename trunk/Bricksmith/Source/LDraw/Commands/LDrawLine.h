//==============================================================================
//
// File:		LDrawLine.m
//
// Purpose:		Line primitive command.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDirective.h"

#import "LDrawDrawableElement.h"


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawLine
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawLine : LDrawDrawableElement
{
	Point3		vertex1;
	Point3		vertex2;

	NSArray		*dragHandles;
}

//Directives
- (NSString *) write;

//Accessors
- (Point3) vertex1;
- (Point3) vertex2;
- (void) setVertex1:(Point3)newVertex;
- (void) setVertex2:(Point3)newVertex;

@end
