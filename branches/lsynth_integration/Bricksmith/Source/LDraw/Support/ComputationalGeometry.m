//==============================================================================
//
// File:        ComputationalGeometry.m
//
// Purpose:     Methods to perform Computational Geometry.
//              These are typically class methods.  It's not expected that there
//              will be multiple instances of this class.
//
//              Functionality includes:
//              - Convex Hull calculations (to assist automatic determination of
//                INSIDE/OUTSIDE LSynth directives).  Currently a simple
//                Jarvis' March implementation since the number of constraints
//                (i.e. points) is expected to be relatively small so O(nh) is
//                not a real issue.
//                See e.g. http://en.wikipedia.org/wiki/Gift_wrapping_algorithm
//
//==============================================================================

// Jarvis pseudocode
/*

jarvis(S)
   pointOnHull = leftmost point in S
   i = 0
   repeat
      P[i] = pointOnHull
      endpoint = S[0]         // initial endpoint for a candidate edge on the hull
      for j from 1 to |S|-1
         if (endpoint == pointOnHull) or (S[j] is on left of line from P[i] to endpoint)
            endpoint = S[j]   // found greater left turn, update endpoint
      i = i+1
      pointOnHull = endpoint
   until endpoint == P[0]      // wrapped around to first hull point

 */


// Jarvis in Python
//# Jarvis March O(nh) - Tom Switzer <thomas.switzer@gmail.com>
//
//TURN_LEFT, TURN_RIGHT, TURN_NONE = (1, -1, 0)
//
//def turn(p, q, r):
//"""Returns -1, 0, 1 if p,q,r forms a right, straight, or left turn."""
//return cmp((q[0] - p[0]) * (r[1] - p[1])   -   (r[0] - p[0]) * (q[1] - p[1])  , 0)
//
//def _dist(p, q):
//  """Returns the squared Euclidean distance between p and q."""
//  dx, dy = q[0] - p[0], q[1] - p[1]
//  return dx * dx + dy * dy
//
//def _next_hull_pt(points, p):
//  """Returns the next point on the convex hull in CCW from p."""
//  q = p
//  for r in points:
//    t = turn(p, q, r)
//    if t == TURN_RIGHT or t == TURN_NONE and _dist(p, r) > _dist(p, q):
//      q = r
//  return q
//
//def convex_hull(points):
//  """Returns the points on the convex hull of points in CCW order."""
//  hull = [min(points)]
//  for p in hull:
//    q = _next_hull_pt(points, p)
//    if q != hull[0]:
//      hull.append(q)
//  return hull

#import "ComputationalGeometry.h"
#import "LDrawDirective.h"
#import "LDrawPart.h"

@implementation ComputationalGeometry

#pragma mark -
#pragma mark CONVEX HULL
#pragma mark -

// This Jarvis' March algorithm is an adaptation of Python code found here:
//     http://tixxit.net/2009/12/jarvis-march/
// There are days when you miss Python's maleability...
// It's been adapted to work with a fixed list of points, modifying hull membership
// for each point.  This allows us to apply the hull (as OUTSIDE/INSIDE LSynth
// directives) to an existing LSynth's constraints.

//========== prepareHullData: ==================================================
//
// Purpose:		Prepare a set of directives for computing convex hull membership
//
//              We take an array of LDrawDirectives, calculate the transformation
//              of the first directive, apply the reverse transformation to all
//              points so that they effectively lie in the XY plane, and create
//              a new array with dictionaries for each directive.
//              The dictionary stores the directive, x & y, and hull membership.
//
//==============================================================================
+(NSMutableArray *)prepareHullData:(NSMutableArray *)directives
{
    // Get the first real part.  This determines the orientation of the synth part
    LDrawPart *firstPart;
    for (LDrawDirective *directive in directives) {
        if ([directive isKindOfClass:[LDrawPart class]]) {
            firstPart = directive;
            break;
        }
    }
    //NSLog(@"First directive is %@", firstPart);

    // Calculate the transformation required to place the first constraint on the XY
    // plane with correct orientation.
    Matrix4 transform = [firstPart transformationMatrix];
    Matrix4 inverseTransform = Matrix4Invert(transform);
    //printf("Transform:\n");
    //Matrix4Print(&transform);
    //printf("Inverse transform:\n");
    //Matrix4Print(&inverseTransform);

    // Apply this inverse transformation to the constraints and
    // create an augmented list of directives
    Matrix4 transformed;
    NSMutableArray *preparedData = [[NSMutableArray alloc] init];
    for (LDrawDirective *directive in directives) {
        if ([directive isKindOfClass:[LDrawPart class]]) {
            transformed = Matrix4Multiply([(LDrawPart *)directive transformationMatrix], inverseTransform);
            //NSLog(@"(X, Y) - (%f, %f)\n", transformed.element[3][0], transformed.element[3][1]);
            // Note the mutability of the literal: we will need to modify inHull later
            [preparedData addObject:[@{@"directive" : directive,
                                      @"x"         : [NSNumber numberWithLong:transformed.element[3][0]],
                                      @"y"         : [NSNumber numberWithLong:transformed.element[3][1]],
                                      @"inHull"    : @false} mutableCopy]];
        }
    }
    return preparedData;
}

//========== doJarvisMarch: ====================================================
//
// Purpose:		Implement the Jarvis' March algorithm.
//
//def convex_hull(points):
//  """Returns the points on the convex hull of points in CCW order."""
//  hull = [min(points)]
//  for p in hull:
//    q = _next_hull_pt(points, p)
//    if q != hull[0]:
//      hull.append(q)
//  return hull
//==============================================================================
+(void)doJarvisMarch:(NSMutableArray *)preparedData
{
    NSMutableDictionary *hullPoint;
    int leftmost;

    // Assign hull membership to the leftmost constraint as the seed point
    if ([preparedData count] > 2){
        //NSLog(@"PreparedData in doJarvisMarch: %@", preparedData);
        leftmost = [ComputationalGeometry leftmost:preparedData];
        //NSLog(@"LEFTMOST: %i %@", leftmost, [preparedData objectAtIndex:leftmost]);
        [[preparedData objectAtIndex:leftmost] setValue:@true forKey:@"inHull"];
    }

    // main loop - keep finding the next point until it's the starting one
    bool stopIterating = NO;
    int pIndex = leftmost;
    while (!stopIterating) {
        int qIndex = [ComputationalGeometry nextHullPointWithPoints:preparedData andPointIndex:pIndex];
        if (qIndex != leftmost){
            [[preparedData objectAtIndex:qIndex] setValue:@true forKey:@"inHull"];
            pIndex = qIndex;
        }
        else{
            stopIterating = YES;
        }
    }
}

//========== nextHullPointWithPoints:andPointIndex: ============================
//
// Purpose:		Find the next point on the convex hull
//
//def _next_hull_pt(points, p):
//  """Returns the next point on the convex hull in CCW from p."""
//  q = p
//  for r in points:
//    t = turn(p, q, r)
//    if t == TURN_RIGHT or t == TURN_NONE and _dist(p, r) > _dist(p, q):
//      q = r
//  return q
//==============================================================================
+(int)nextHullPointWithPoints:(NSMutableDictionary *)points andPointIndex:(int)pIndex
{
    int qIndex = pIndex;
    for (int rIndex=0; rIndex < [points count]; rIndex++) {
        //TURN_LEFT, TURN_RIGHT, TURN_NONE = (1, -1, 0)
        int t = [ComputationalGeometry turnWithPoints:points P:pIndex Q:qIndex R:rIndex];

        NSLog(@"next hull point turn: %i", t);

        if (t == -1 || (t == 0 &&
            [ComputationalGeometry distanceBetweenPoints:points P:pIndex Q:rIndex] >
            [ComputationalGeometry distanceBetweenPoints:points P:pIndex Q:qIndex])) {
            qIndex = rIndex;
        }
    }

    NSLog(@"Next hull point: %i", qIndex);

    return qIndex;
}

//========== turnWithPoints:P:Q:R: =============================================
//
// Purpose:		Given three points, P, Q, R, determine whether QR turns left,
//              right or is straight w.r.t. PQ
//
//                              [R]  (Left)
//                             ^
//                            /
//                           /
//                          /
//              [P]----->[Q]--->[R]  (Straight)
//                          \
//                           \
//                            \
//                            V
//                            [R]    (Right)
//
//==============================================================================
+(int)turnWithPoints:(NSMutableArray *)points P:(int)pIndex Q:(int)qIndex R:(int)rIndex
{
    NSLog(@"PQR: %i, %i, %i", pIndex, qIndex, rIndex);

    int px = [[[points objectAtIndex:pIndex] objectForKey:@"x"] integerValue];
    int qx = [[[points objectAtIndex:qIndex] objectForKey:@"x"] integerValue];
    int rx = [[[points objectAtIndex:rIndex] objectForKey:@"x"] integerValue];
    int py = [[[points objectAtIndex:pIndex] objectForKey:@"y"] integerValue];
    int qy = [[[points objectAtIndex:qIndex] objectForKey:@"y"] integerValue];
    int ry = [[[points objectAtIndex:rIndex] objectForKey:@"y"] integerValue];

    // ((q[0] - p[0]) * (r[1] - p[1])   -   (r[0] - p[0]) * (q[1] - p[1])
    int turn = ((qx - px) * (ry - py)) - ((rx - px) * (qy - py));

     NSLog(@"turnWithPoints: %i", turn);

    // TURN_LEFT, TURN_RIGHT, TURN_NONE = (1, -1, 0)
    return turn < 0 ?
                 -1 :
           turn > 0 ?
                  1 :
           0;
}

//========== distanceBetweenPoints:P:Q: ========================================
//
// Purpose:		Calculate the squared Euclidean distance between two points in
//              an array.
//
//==============================================================================
+(int)distanceBetweenPoints:(NSMutableArray *)points P:(int)pIndex Q:(int)qIndex
{
    int dx = [[[points objectAtIndex:qIndex] objectForKey:@"x"] integerValue] - [[[points objectAtIndex:pIndex] objectForKey:@"x"] integerValue];
    int dy = [[[points objectAtIndex:qIndex] objectForKey:@"y"] integerValue] - [[[points objectAtIndex:pIndex] objectForKey:@"y"] integerValue];

    NSLog(@"distance: %i", dx * dx + dy * dy);

    return dx * dx + dy * dy;
}

//========== leftmost: =========================================================
//
// Purpose:		Determine the index of the left-most point in a set of points
//
//==============================================================================
+(int)leftmost:(NSMutableArray *)points
{
    int *leftmost = nil;
    for (int i=0; i < [points count]; i++) {
        NSLog(@"Leftmost: %i, %i, %@, %@", i, leftmost, [[points objectAtIndex:i] objectForKey:@"x"], [[points objectAtIndex:leftmost] objectForKey:@"x"]);
        if (leftmost == nil || [[[points objectAtIndex:i] objectForKey:@"x"] integerValue] < [[[points objectAtIndex:leftmost] objectForKey:@"x"] integerValue]) {
            leftmost = i;
        }
    }
    return leftmost;
}

@end