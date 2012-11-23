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
#import "FormCategory.h"


@implementation NSForm (FormCategory)

//========== setCoordinateValue: ===============================================
//
// Purpose:		Returns the x,y,z coordinate represented in the first three 
//				fields of the form.
//
//==============================================================================
- (Point3) coordinateValue
{
	Point3 representedPoint	= ZeroPoint3;
	
	representedPoint.x = [[self cellAtIndex:0] floatValue];
	representedPoint.y = [[self cellAtIndex:1] floatValue];
	representedPoint.z = [[self cellAtIndex:2] floatValue];
	
	return representedPoint;
	
}//end coordinateValue


//========== setCoordinateValue: ===============================================
//
// Purpose:		Sets the first three cells of this form to the x,y,z coordinate 
//				newPoint.
//
//==============================================================================
- (void) setCoordinateValue:(Point3)newPoint
{
	[[self cellAtIndex:0] setFloatValue:newPoint.x];
	[[self cellAtIndex:1] setFloatValue:newPoint.y];
	[[self cellAtIndex:2] setFloatValue:newPoint.z];
	
}//end setCoordinateValue:


@end
