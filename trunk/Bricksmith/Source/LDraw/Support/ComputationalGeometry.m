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

#import "ComputationalGeometry.h"
#import "LDrawDirective.h"
#import "LDrawPart.h"
#import "LSynthConfiguration.h"
#import "MatrixMath.h"

//@interface TangentPoint
//{
//    int x;
//    int y;
//    LDrawDirective *directive;
//}
//@end
//
//@implementation TangentPoint
//@end

//==============================================================================
//
// A convenience container for a circle - probably unnecessary.
//
//==============================================================================

@interface Circle : NSObject
{
    int x;
    int y;
    int r;
    LDrawDirective *directive;
}
-(void)setX:(int)x;
-(void)setY:(int)y;
-(void)setR:(int)r;
-(Circle *)initWithX:(int)x Y:(int)y R:(int)r;
@end

@implementation Circle

#pragma mark -
#pragma mark INITIALISATION
#pragma mark -

-(id)initWithX:(int)X Y:(int)Y R:(int)R
{
	self = [super init];
    if (self)
	{
        self.x = X;
        self.y = Y;
        self.r = R;
    }
    return self;
}

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

-(int) x
{
    return self->x;
}
-(void)setX:(int)X
{
    self->x = X;
}
-(int) y {
    return self->y;
}
-(void)setY:(int)Y
{
    self->y = Y;
}
-(int) r {
    return self->r;
}
-(void)setR:(int)R
{
    self->r = R;
}
-(LDrawDirective *) directive {
    return self->directive;
}


@end

@implementation ComputationalGeometry

#pragma mark -
#pragma mark CIRCLE TANGENTS
#pragma mark -

// Methods to calculate the outer tangent points between a number of constraints
// This is basically the Two Circles' Tangents problem.  We need to calculate the
// outermost convex hull so that we can honour constraints' radii (i.e. gear size)
// and perform INSIDE/OUTSIDE determination correctly.  The naive convex hull method
// uses constraint centers with no regard for their size which results in e.g. chains
// looping around a gear.  Size Matters.

//========== tangentsBetweenDirective:andDirective: ============================
//
// Purpose:		Calculate the end points of the outer tangents between two
//              circles.  These can represent e.g. band constraints such as gears
//
// Algorithm based on Java implementation found at:
//     http://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Tangents_between_two_circles
//
// Notes from that implementation:
//
// Returns an empty, or 2x4, or 4x4 array of doubles representing
//  the two exterior and two interior tangent segments (in that order).
//  If some tangents don't exist, they aren't present in the output.
//  Each segment is represent by a 4-tuple x1,y1,x2,y2.
//
//  Exterior tangents exist iff one of the circles doesn't contain
//  the other. Interior tangents exist iff circles don't intersect.
//
//  In the limiting case when circles touch from outside/inside, there are
//  no interior/exterior tangents, respectively, but just one common
//  tangent line (which isn't returned at all, or returned as two very
//  close or equal points by this code, depending on roundoff -- sorry!)
//
//==============================================================================
/**
 *  Finds tangent segments between two given circles.
 *
  */
+(NSArray *)tangentBetweenCircle:(NSMutableDictionary *)circle1 andCircle:(NSMutableDictionary *)circle2
{
    // Recast the supplied dictionaries as Circles for clarity in the main algorithm
    Circle *c1 = [[[Circle alloc] initWithX:[[circle1 valueForKey:@"x"] integerValue]
                                         Y:[[circle1 valueForKey:@"y"] integerValue]
                                         R:[[circle1 valueForKey:@"r"] integerValue]] autorelease];
    Circle *c2 = [[[Circle alloc] initWithX:[[circle2 valueForKey:@"x"] integerValue]
                                         Y:[[circle2 valueForKey:@"y"] integerValue]
                                         R:[[circle2 valueForKey:@"r"] integerValue]] autorelease];

    double d_sq = pow([c1 x] - [c2 x], 2) + pow([c1 y] - [c2 y], 2);
    if (d_sq <= pow([c1 r] - [c2 r], 2)) {
        return nil; // empty array
    }

    double d = sqrt(d_sq);
    double vx = ([c2 x] - [c1 x]) / d;
    double vy = ([c2 y] - [c1 y]) / d;

    NSMutableArray *results = [NSMutableArray arrayWithCapacity:4];
    int i = 0;

    // Let A, B be the centers, and C, D be points at which the tangent
    // touches first and second circle, and n be the normal vector to it.
    //
    // We have the system:
    //   n * n = 1          (n is a unit vector)
    //   C = A + r1 * n
    //   D = B +/- r2 * n
    //   n * CD = 0         (common orthogonality)
    //
    // n * CD = n * (AB +/- r2*n - r1*n) = AB*n - (r1 -/+ r2) = 0,  <=>
    // AB * n = (r1 -/+ r2), <=>
    // v * n = (r1 -/+ r2) / d,  where v = AB/|AB| = AB/d
    // This is a linear equation in unknown vector n.

    int sign1;
    for (sign1 = 1; sign1 >= -1; sign1 -= 2) {
        double c = ([c1 r] - (sign1 * [c2 r])) / d;

        if (pow(c, 2) > 1.0) {
            continue;
        }

        double h = sqrt(0.0 > 1.0 - pow(c, 2) ? 0.0 : 1.0 - pow(c, 2)); // max of 0 and 1-c^2

        int sign2;
        for (sign2 = 1; sign2 >= -1; sign2 -= 2) {
            double nx = (vx * c) - sign2 * h * vy;
            double ny = (vy * c) - sign2 * h * vx;
            NSMutableArray *a = [NSMutableArray arrayWithCapacity:4];
            [a insertObject:[NSNumber numberWithDouble:([c1 x] + ([c1 r] * nx))] atIndex:0];
            [a insertObject:[NSNumber numberWithDouble:([c1 y] + ([c1 r] * ny))] atIndex:1];
            [a insertObject:[NSNumber numberWithDouble:([c2 x] + (sign1 * [c2 r] * nx))] atIndex:2];
            [a insertObject:[NSNumber numberWithDouble:([c2 y] + (sign1 * [c2 r] * ny))] atIndex:3];
            [results insertObject:a atIndex:i];
            i++;
        }
    }

    // Return 0, 2 or 4 results.
    return [results subarrayWithRange:NSMakeRange(0, i)];
}


#pragma mark -
#pragma mark CONVEX HULL
#pragma mark -

//========== doJarvisMarch: ====================================================
//
// Purpose:		Implement the Jarvis' March algorithm.
//
// This Jarvis' March algorithm is an adaptation of Python code found here:
//     http://tixxit.net/2009/12/jarvis-march/
// There are days when you miss Python's maleability...
// It's been adapted to work with a fixed list of points, modifying hull membership
// for each point.  This allows us to apply the hull (as OUTSIDE/INSIDE LSynth
// directives) to an existing LSynth's constraints.
//
//==============================================================================
+(void)doJarvisMarch:(NSMutableArray *)preparedData
{
    int leftmost;

    // Assign hull membership to the leftmost constraint as the seed point
    if ([preparedData count] > 2){
        //NSLog(@"PreparedData in doJarvisMarch: %@", preparedData);
        leftmost = [ComputationalGeometry leftmost:preparedData];
        //NSLog(@"LEFTMOST: %i %@", leftmost, [preparedData objectAtIndex:leftmost]);
        [[preparedData objectAtIndex:leftmost] setValue:[NSNumber numberWithBool:(BOOL)true] forKey:@"inHull"];


        // main loop - keep finding the next point until it's the starting one
        bool stopIterating = NO;
        int pIndex = leftmost;
        while (!stopIterating) {
            int qIndex = [ComputationalGeometry nextHullPointWithPoints:preparedData andPointIndex:pIndex];
            if (qIndex != leftmost){
                [[preparedData objectAtIndex:qIndex] setValue:[NSNumber numberWithBool:(BOOL)true] forKey:@"inHull"];
                pIndex = qIndex;
            }
            else{
                stopIterating = YES;
            }
        }
    }
}

//========== nextHullPointWithPoints:andPointIndex: ============================
//
// Purpose:		Find the next point on the convex hull
//
//==============================================================================
+(int)nextHullPointWithPoints:(NSArray *)points andPointIndex:(int)pIndex
{
    int qIndex = pIndex;
    int rIndex;
    for (rIndex=0; rIndex < [points count]; rIndex++) {
        //TURN_LEFT, TURN_RIGHT, TURN_NONE = (1, -1, 0)
        int t = [ComputationalGeometry turnWithPoints:points P:pIndex Q:qIndex R:rIndex];

        //NSLog(@"next hull point turn: %i", t);

        if (t == -1 || (t == 0 &&
            [ComputationalGeometry distanceBetweenPoints:points P:pIndex Q:rIndex] >
            [ComputationalGeometry distanceBetweenPoints:points P:pIndex Q:qIndex])) {
            qIndex = rIndex;
        }
    }

    //NSLog(@"Next hull point: %i", qIndex);

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
//                          \												| 
//                           \												|
//                            \												|
//                            V
//                            [R]    (Right)
//
//==============================================================================
+(int)turnWithPoints:(NSArray *)points P:(int)pIndex Q:(int)qIndex R:(int)rIndex
{
    //NSLog(@"PQR: %i, %i, %i", pIndex, qIndex, rIndex);

    int px = [[[points objectAtIndex:pIndex] objectForKey:@"x"] integerValue];
    int qx = [[[points objectAtIndex:qIndex] objectForKey:@"x"] integerValue];
    int rx = [[[points objectAtIndex:rIndex] objectForKey:@"x"] integerValue];
    int py = [[[points objectAtIndex:pIndex] objectForKey:@"y"] integerValue];
    int qy = [[[points objectAtIndex:qIndex] objectForKey:@"y"] integerValue];
    int ry = [[[points objectAtIndex:rIndex] objectForKey:@"y"] integerValue];

    // ((q[0] - p[0]) * (r[1] - p[1])   -   (r[0] - p[0]) * (q[1] - p[1])
    int turn = ((qx - px) * (ry - py)) - ((rx - px) * (qy - py));

     //NSLog(@"turnWithPoints: %i", turn);

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
+(int)distanceBetweenPoints:(NSArray *)points P:(int)pIndex Q:(int)qIndex
{
    int dx = [[[points objectAtIndex:qIndex] objectForKey:@"x"] integerValue] - [[[points objectAtIndex:pIndex] objectForKey:@"x"] integerValue];
    int dy = [[[points objectAtIndex:qIndex] objectForKey:@"y"] integerValue] - [[[points objectAtIndex:pIndex] objectForKey:@"y"] integerValue];

    //NSLog(@"distance: %i", dx * dx + dy * dy);

    return dx * dx + dy * dy;
}

//========== leftmost: =========================================================
//
// Purpose:		Determine the index of the left-most point in a set of points
//
//==============================================================================
+(int)leftmost:(NSMutableArray *)points
{
    int leftmost = 0;
    int i;
    for (i=0; i < [points count]; i++) {
        //NSLog(@"Leftmost: %i, %i, %@, %@", i, leftmost, [[points objectAtIndex:i] objectForKey:@"x"], [[points objectAtIndex:leftmost] objectForKey:@"x"]);
        if ([[[points objectAtIndex:i] objectForKey:@"x"] integerValue] < [[[points objectAtIndex:leftmost] objectForKey:@"x"] integerValue])
		{
            leftmost = i;
        }
    }
    return leftmost;
}

@end