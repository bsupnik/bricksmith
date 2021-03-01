//==============================================================================
//
// File:		InspectionTriangle.h
//
// Purpose:		Inspector Controller for an LDrawTriangle.
//
//  Created by Allen Smith on 3/9/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"

//------------------------------------------------------------------------------
///
/// @class		InspectionTriangle
///
/// @abstract	Inspector Controller for an LDrawTriangle.
///
//------------------------------------------------------------------------------
@interface InspectionTriangle : ObjectInspectionController

@end


/// Simple class that draws a triangle shape.
/// Used as a graphic in the inspector.
@interface TriangleView : NSView
@end
