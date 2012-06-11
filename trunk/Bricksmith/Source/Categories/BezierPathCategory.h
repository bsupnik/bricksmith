//==============================================================================
//
// File:		BezierPathCategory.h
//
// Purpose:		Handy Bezier path methods Apple forgot.
//
//  Created by Allen Smith on 6/11/07.
//  Copyright 2007. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface NSBezierPath (BezierPathCategory)

+ (NSBezierPath *) bezierPathWithRect:(NSRect)rect radiusPercentage:(CGFloat)radiusPercentage;

@end
