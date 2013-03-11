#import "MatrixMath.h"

////////////////////////////////////////////////////////////////////////////////
//
// Protocol:	LDrawMovableDirective
//
// Notes:		This protocol is adopted by classes that are movable.  This allows
//              both simple parts and containers such as LDrawLSynth to be targeted
//              by move operations.
//
////////////////////////////////////////////////////////////////////////////////
@protocol LDrawMovableDirective
- (Vector3) displacementForNudge:(Vector3)nudgeVector;
- (void) moveBy:(Vector3)moveVector;
@end
