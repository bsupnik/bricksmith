//==============================================================================
//
// Category: FormCategory.m
//
//		Provides one-stop method for for setting a three-celled form to display 
//		a three-dimensional coordinate.
//
//  Created by Allen Smith on 2/26/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawDirective.h"
#import "MatrixMath.h"

@interface NSForm (FormCategory)

- (Point3) coordinateValue;
- (void) setCoordinateValue:(Point3)newPoint;

@end
