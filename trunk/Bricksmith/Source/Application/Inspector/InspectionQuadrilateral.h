//==============================================================================
//
// File:		InspectionQuadrilateral.h
//
// Purpose:		Inspector Controller for an LDrawQuadrilateral.
//
//  Created by Allen Smith on 3/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "ObjectInspectionController.h"

//------------------------------------------------------------------------------
///
/// @class		InspectionQuadrilateral
///
/// @abstract	Inspector Controller for an LDrawQuadrilateral.
///
//------------------------------------------------------------------------------
@interface InspectionQuadrilateral : ObjectInspectionController

@end


/// Simple class that draws a quadrilateral shape.
/// Used as a graphic in the inspector.
@interface QuadrilateralView : NSView
@end
