//==============================================================================
//
// File:		LDrawLSynth.m
//
// Purpose:		Support for synthesizing bendable parts and LSynth generated parts.
//
//==============================================================================

#import "LDrawLSynth.h"

@implementation LDrawLSynth

#pragma mark Accessors

//========== setLsynthClass: ====================================================
//
//  Purpose:		Sets the class of the Synthesized part, Pneumatic tube, or Technic
//                  chain etc.
//
//==============================================================================
- (void) setLsynthClass:(int)class
{
    self->lsynthClass = class;
}//end setLsynthClass:

//========== lsynthClass: ====================================================
//
//  Purpose:		Return the class of the Synthesized part.
//
//==============================================================================

- (int) lsynthClass
{
    return self->lsynthClass;
}//end lsynthClass:

//========== setLsynthType: ====================================================
//
//  Purpose:		Sets the type of the Synthesized part, band, chain or part
//
//==============================================================================
- (void) setLsynthType:(NSString *)type
{
    self->lsynthType = type;
}//end setLsynthType:

//========== lsynthClass: ====================================================
//
//  Purpose:		Return the type of the Synthesized part.
//
//============================================================================
- (NSString *) lsynthType
{
    return self->lsynthType;
}//end

//========== transformComponents ===============================================
//
// Purpose:		Returns the individual components of the transformation matrix
//			    applied to this part.
//
//==============================================================================
- (TransformComponents) transformComponents
{
    Matrix4				transformation	= [self transformationMatrix];
    TransformComponents	components		= IdentityComponents;

    //This is a pretty darn neat little function. I wish I could say I wrote it.
    // It will extract all the user-friendly components out of this nasty matrix.
    Matrix4DecomposeTransformation( transformation, &components );

    return components;

}//end transformComponents

#pragma mark <LDrawColorable> protocol methods

//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the color of the synthesized tube.  This may be temporarily
//              overridden for certain operations but WILL be the one saved out.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *)newColor
{
    // Store the color
    [newColor retain];
    [self->color release];
    self->color = newColor;

    //[self colorSynthesizedPartsTranslucent:[self isSelected]];
}//end setLDrawColor:

//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code of the receiver.
//
//==============================================================================
-(LDrawColor *) LDrawColor
{
    return color;
}//end LDrawColor

#pragma mark Utility Functions

//========== synthesizeWithGroup: ==============================================
//
// Purpose:	Synthesizes the part using LSynth
//
//==============================================================================
-(void)synthesize
{
    NSLog(@"Would have synthesized");
}

//========== colorSynthesizedPartsTranslucent: =================================
//
// Purpose:		Make synthesized parts transparent so that we can better see
//              constraints.
//
//==============================================================================
- (void)colorSynthesizedPartsTranslucent:(BOOL)yesNo
{
//    LDrawColor *theColor;
//    if (yesNo == YES) {
//        theColor = [color fullCopyWithZone:nil];
//        GLfloat rgba[4];
//        [theColor getColorRGBA:rgba];
//        rgba[3] = 0.2; // Adjust the alpha.  TODO: make this globally configurable
//        [theColor setColorRGBA:rgba];
//    }
//    else {
//        theColor = color;
//    }
//
//    for (LDrawPart *part in self->synthesizedParts) {
//        [part setLDrawColor:theColor];
//    }
}  //end colorSynthesizedPartsTranslucent:

//========== transformationMatrix ==============================================
//
// Purpose:		Returns a two-dimensional (row matrix) representation of the
//				part's transformation matrix.
//
//																+-       -+
//				+-                           -+        +-     -+| a d g 0 |
//				|a d g 0 b e h c f i 0 x y z 1|  -->   |x y z 1|| b e h 0 |
//				+-                           -+        +-     -+| c f i 0 |
//																| x y z 1 |
//																+-       -+
//					  OpenGL Matrix Format                 LDraw Matrix
//				(flat column-major of transpose)              Format
//
//==============================================================================
- (Matrix4) transformationMatrix
{
    return Matrix4CreateFromGLMatrix4(glTransformation);

}//end transformationMatrix

@end
