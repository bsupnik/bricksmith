//==============================================================================
//
// File:		MatrixMath.h
//
// Purpose:		Mathematical library for computer graphics
//
//				Stolen heavily from GraphicsGems.h  
//				Version 1.0 - Andrew Glassner
//				from "Graphics Gems", Academic Press, 1990
//
//==============================================================================
#include "MatrixMath.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const Size2 ZeroSize2   = {0.0, 0.0};
const Box2  ZeroBox2    = {	{0.0, 0.0},
							{0.0, 0.0} };

//Box which represents no bounds. It is defined in such a way that it can 
// be used transparently in size comparisons -- its minimum is inifinity,
// so any valid point will be smaller than that!
const Box3 InvalidBox = {	{ INFINITY,  INFINITY,  INFINITY},
							{-INFINITY, -INFINITY, -INFINITY}   };
							
const TransformComponents IdentityComponents = {
							{1, 1, 1},	//scale;
							0,			//shear_XY;
							0,			//shear_XZ;
							0,			//shear_YZ;
							{0, 0, 0},	//rotate;		//in radians
							{0, 0, 0},	//translate;
							{0, 0, 0, 0}//perspective;
						};

const Matrix3 IdentityMatrix3 = {{	{1, 0, 0},
									{0, 1, 0},
									{0, 0, 1} }};

const Matrix4 IdentityMatrix4 = {{	{1, 0, 0, 0},
									{0, 1, 0, 0},
									{0, 0, 1, 0},
									{0, 0, 0, 1} }};

const Point2 ZeroPoint2 = {0.0, 0.0};
const Point3 ZeroPoint3 = {0.0, 0.0, 0.0};
const Point4 ZeroPoint4 = {0.0, 0.0, 0.0, 0.0};


//========== FloatsApproximatelyEqual ==========================================
//
// Purpose:		Testing floating-point numbers for equality is horribly 
//				difficult, owing to tiny little rounding errors. This method 
//				attempts to determine approximate equality. 
//
//				It is insufficient to test with some tolerance value (such as 
//				SMALL_NUMBER), because the minimum difference between two 
//				floating-point values changes depending on how big the integer 
//				component is. 
//
//				The trick is described here:
//				http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
//
//				Basically, the bits of floating-point values are guaranteed to 
//				be ordered, so if we compare them as SIGN-MAGNITUDE integers, 
//				the integer difference represents the true relative difference. 
//				There are 0xFFFFFFFF possible floating-point values; a 
//				difference of, say, 2 doesn't amount to much! 
//
//				The main issue now is converting from 2's compliment into 
//				sign-magnitude ints. 
//
//==============================================================================
bool FloatsApproximatelyEqual(float float1, float float2)
{
	// Use a union; it's less scary than *(int*)&point1.z;
	union intFloat
	{
		int32_t	intValue;
		float	floatValue;
	};
	
	union intFloat	value1;
	union intFloat	value2;
	bool			closeEnough	= false;
	
	// First translate the floats into integers via the union.
	value1.floatValue = float1;
	value2.floatValue = float2;
	
	// Make value1.intValue lexicographically ordered as a twos-complement int
	// (Floating-point -0 == 0x80000000; the next number less than -0 is 
	// 0x80000001, etc.) So we do: value1.intValue = 0x80000000 - value1.intValue;
    if (value1.intValue < 0)
        value1.intValue = (1 << (sizeof(float) * 8 - 1)) - value1.intValue;
	
    // ...and do the same for value2
    if (value2.intValue < 0)
        value2.intValue = (1 << (sizeof(float) * 8 - 1)) - value2.intValue;
	
	// Less than 5 integer positions different will be considered equal. This 
	// number was pulled out of my hat. Each integer difference equals a 
	// different number depending on the magnitute of the float value. 
	if(abs(value1.intValue - value2.intValue) < 5)
	{
		closeEnough = true;
	}
	// The int method doesn't seem to work very well for numbers very close to 
	// zero, where float values can have extremely precise representations. So 
	// if we are trying to compare a float to 0, we fall back on the old 
	// precision threshold. 
	else if(	float1 > -1 && float1 < 1
			&&	float1 > -1 && float1 < 1 )
	{
		if( fabs(float1 - float2) < SMALL_NUMBER)
		{
			closeEnough = true;
		}
	}
		
	return closeEnough;

}//end FloatsApproximatelyEqual


#pragma mark -
#pragma mark 2-D LIBRARY
#pragma mark -

//========== V2Make ============================================================
//
// Purpose:		Make a 2D point.
//
//==============================================================================
Point2 V2Make(float x, float y)
{
	Point2 point;
	
	point.x = x;
	point.y = y;
	
	return point;
}


#pragma mark -

//========== V2MakeBox =========================================================
//
// Purpose:		Makes a box from width and height.
//
//==============================================================================
Box2 V2MakeBox(float x, float y, float width, float height)
{
	Box2 box;
	
	box.origin.x    = x;
	box.origin.y    = y;
	
	box.size.width  = width;
	box.size.height = height;
	
	return box;
}


//========== V2MakeBoxFromPoints ===============================================
//
// Purpose:		Infer the width/height from two points
//
//==============================================================================
Box2 V2MakeBoxFromPoints(Point2 origin, Point2 maximum)
{
	float width = maximum.x - origin.x;
	float height = maximum.y - origin.y;
	return V2MakeBox(origin.x, origin.y, width, height);
}


//========== V2MakeSize ========================================================
//==============================================================================
Size2 V2MakeSize(float width, float height)
{
	Size2 size;
	
	size.width  = width;
	size.height = height;
	
	return size;
}


//========== V2EqualBoxes ======================================================
//==============================================================================
bool V2EqualBoxes(Box2 box1, Box2 box2)
{
	return (	box1.origin.x == box2.origin.y
			&&	box1.origin.y == box2.origin.y
			&&	box1.size.height == box2.size.height
			&&	box1.size.width == box2.size.width );
}


//========== V2EqualSizes ======================================================
//==============================================================================
bool V2EqualSizes(Size2 size1, Size2 size2)
{
	return (	size1.width == size2.width
			&&	size1.height == size2.height );
}


//========== V2BoxHeight =======================================================
//==============================================================================
float V2BoxHeight(Box2 box)
{
	return (box.size.height);
}


//========== V2BoxWidth ========================================================
//==============================================================================
float V2BoxWidth(Box2 box)
{
	return (box.size.width);
}


//========== V2BoxMaxX =========================================================
//==============================================================================
float V2BoxMaxX(Box2 box)
{
	return (box.origin.x + box.size.width);
}


//========== V2BoxMaxY =========================================================
//==============================================================================
float V2BoxMaxY(Box2 box)
{
	return (box.origin.y + box.size.height);
}


//========== V2BoxMidX =========================================================
//==============================================================================
float V2BoxMidX(Box2 box)
{
	return (box.origin.x + V2BoxWidth(box) * 0.5f);
}


//========== V2BoxMidY =========================================================
//==============================================================================
float V2BoxMidY(Box2 box)
{
	return (box.origin.y + V2BoxHeight(box) * 0.5f);
}


//========== V2BoxMinX =========================================================
//==============================================================================
float V2BoxMinX(Box2 box)
{
	return box.origin.x;
}


//========== V2BoxMinY =========================================================
//==============================================================================
float V2BoxMinY(Box2 box)
{
	return box.origin.y;
}


//========== V2BoxInset ========================================================
//
// Purpose:		Returns a new box, altered by moving the two sides that are 
//				parallel to the y axis inward by dX, and the two sides parallel 
//				to the x axis inwards by dY. 
//
//==============================================================================
Box2 V2BoxInset(Box2 box, float dX, float dY)
{
	Box2 insetBox = box;
	
	insetBox.origin.x    += dX;
	insetBox.origin.y    += dY;
	insetBox.size.width  -= dX * 2;
	insetBox.size.height -= dY * 2;
	
	return insetBox;
}


//========== HELPER FUNCTIONS: horizontal/vertical line testing ================
//
//	Purpose:		these two helper functions can be used to find the intercept
//					of a line (going through p1/p2) with a horizontal or vertical
//					line.  We use this to do our seg-seg intersection with the AABB.
//
//==============================================================================


static float seg_y_at_x(Point2 p1, Point2 p2, float x)
{ 	
	if (p1.x == p2.x) 	return p1.y;
	if (x == p1.x) 		return p1.y;
	if (x == p2.x) 		return p2.y;
	return p1.y + (p2.y - p1.y) * (x - p1.x) / (p2.x - p1.x); 
}

static float seg_x_at_y(Point2 p1, Point2 p2, float y)
{
	if (p1.y == p2.y) 	return p1.x;
	if (y == p1.y) 		return p1.x;
	if (y == p2.y) 		return p2.x;
	return p1.x + (p2.x - p1.x) * (y - p1.y) / (p2.y - p1.y); 
}


//========== V2BoxContains =====================================================
//
// Purpose:		simple containment test for points and boxes - on the line is in.
//
//==============================================================================
bool		V2BoxContains(Box2 box, Point2 pin)
{
	return pin.x >= V2BoxMinX(box) &&
		   pin.x <= V2BoxMaxX(box) &&
		   pin.y >= V2BoxMinY(box) &&
		   pin.y <= V2BoxMaxY(box);
}


//========== V2BoxIntersectsLine ===============================================
//
// Purpose:		tests whether a given line segment intersects any of the four 
//				edge sof an axis-aligned bounding box. 
//
//==============================================================================
bool V2BoxIntersectsLine(Box2 box, Point2 pin1, Point2 pin2)
{
	float x1 = V2BoxMinX(box);
	float x2 = V2BoxMaxX(box);
	float y1 = V2BoxMinY(box);
	float y2 = V2BoxMaxY(box);
	
	if (!(pin1.x < x1 && pin2.x < x1) &&
		!(pin1.x > x1 && pin2.x > x1))
	{
		float yp = seg_y_at_x(pin1,pin2,x1);
		
		if(yp >= y1 && yp <= y2)
			return true;		
	}

	if (!(pin1.x < x2 && pin2.x < x2) &&
		!(pin1.x > x2 && pin2.x > x2))
	{
		float yp = seg_y_at_x(pin1,pin2,x2);
		
		if(yp >= y1 && yp <= y2)
			return true;		
	}
	
	if (!(pin1.y < y1 && pin2.y < y1) &&
		!(pin1.y > y1 && pin2.y > y1))
	{
		float xp = seg_x_at_y(pin1,pin2,y1);
		
		if(xp >= x1 && xp <= x2)
			return true;		
	}

	if (!(pin1.y < y2 && pin2.y < y2) &&
		!(pin1.y > y2 && pin2.y > y2))
	{
		float xp = seg_x_at_y(pin1,pin2,y2);
		
		if(xp >= x1 && xp <= x2)
			return true;		
	}

	return false;
}


//========== V2PolygonContains =================================================
//
// Purpose:		test whether a point is within a polygon, as define by an array
//				of points.  "On the line" points are in if they are on a left
//				or bottom (but not right or top) edge.
//
//==============================================================================
bool		V2PolygonContains(const Point2 * begin, int num_pts, Point2 pin)
{
	const Point2 * end = begin + num_pts;
	int cross_counter = 0;
	Point2		first_p = *begin;
	Point2		s_p1;
	Point2		s_p2;
	
	s_p1 = *begin;
	++begin;

	while (begin != end)
	{
		s_p2 = *begin;
		if ((s_p1.x < pin.x && pin.x <= s_p2.x) ||
			(s_p2.x < pin.x && pin.x <= s_p1.x))
		if (pin.y > seg_y_at_x(s_p1,s_p2,pin.x))
			++cross_counter;

		s_p1 = s_p2;
		++begin;
	}
	s_p2 = first_p;
	if ((s_p1.x < pin.x && pin.x <= s_p2.x) ||
		(s_p2.x < pin.x && pin.x <= s_p1.x))
	if (pin.y > seg_y_at_x(s_p1, s_p2, pin.x))
		++cross_counter;
	return (cross_counter % 2) == 1;

}


//========== V2BoxIntersectsPolygon ============================================
//
//	Purpose:		tests whether any point on or in the polygon (as defined by
//					a point array) intersects the given axis-aligned bounding 
//					box.
//
//==============================================================================
bool		V2BoxIntersectsPolygon(Box2 bounds, const Point2 * poly, int num_pts)
{
	int i, j;
	
	// Easy case: selection box contains a polygon point.  Do this first - it's fastest.
	for(i = 0; i < num_pts; ++i)
	if(V2BoxContains(bounds,poly[i]))
		return true;
	
	// Next case: if any edge fo the polygon hits the box edge, that's a hit.
	for(i = 0; i < num_pts; ++i)
	{
		j = (i + 1) % num_pts;
		if(V2BoxIntersectsLine(bounds,poly[i],poly[j]))
			return true;
	}
	
	// Finally: for polygons (tri, quad, etc.) our selection box might be entirely INSIDE the 
	// poylgon.  Test its centroid.
	if(num_pts < 3) 
		return false;
	else
		// Final case: for non-degenerate case, marquee could be FULLY inside - test one point to be sure.
		return V2PolygonContains(poly,num_pts,V2Make(V2BoxMidX(bounds),V2BoxMidY(bounds)));
}


#pragma mark -

//========== Matrix2x2Determinant ==============================================
//
// Purpose:		Calculate the determinant of a 2x2 matrix.
//
//==============================================================================
float Matrix2x2Determinant( float a, float b, float c, float d)
{
    float ans;
    ans = a * d - b * c;
    return ans;
	
}//end Matrix2x2Determinant


#pragma mark -
#pragma mark 3-D LIBRARY
#pragma mark -

//========== V3Make ============================================================
//
// Purpose:		create, initialize, and return a new vector
//
//==============================================================================
Vector3 V3Make(float x, float y, float z)
{
	Vector3 v;
	v.x = x;  v.y = y;  v.z = z;
	return(v);
	
}//end V3Make


//========== V3Duplicate =======================================================
//
// Purpose:		create, initialize, and return a duplicate vector
//
//==============================================================================
Vector3 *V3Duplicate(Vector3 *a)
{
	Vector3 *v = NEWTYPE(Vector3);
	v->x = a->x;  v->y = a->y;  v->z = a->z;
	return(v);
	
}//end V3Duplicate


//========== V3FromV4 ==========================================================
//
// Purpose:		Create a new 3D vector whose components match the given 4D 
//				vector. Using this function is really only sensible when the 4D 
//				vector is really a 3D one being used for convenience in 4D math.
//
//==============================================================================
Vector3 V3FromV4(Vector4 originalVector)
{
	Vector3 newVector;
	
	//This is very bad.
	if(originalVector.w != 1 && originalVector.w != 0)
		printf("lossy 4D vector conversion: <%f, %f, %f, %f>\n", originalVector.x, originalVector.y, originalVector.z, originalVector.w);
	
	newVector.x = originalVector.x;
	newVector.y = originalVector.y;
	newVector.z = originalVector.z;
	
	return newVector;
	
}//end V3FromV4


#pragma mark -

//========== V3EqualPoints() ===================================================
//
// Purpose:		Returns YES if point1 and point2 have the same coordinates..
//
//==============================================================================
bool V3EqualPoints(Point3 point1, Point3 point2)
{
	if(		point1.x == point2.x
	   &&	point1.y == point2.y
	   &&	point1.z == point2.z )
		return true;
	else
		return false;
		
}//end V3EqualPoints


//========== V3PointsWithinTolerance() =========================================
//
// Purpose:		Returns YES if point1 and point2 are sufficiently close to equal 
//				that we can call them equal. 
//
// Notes:		Floating-point numbers often suffer weird rounding errors which 
//				make them ill-suited for == comparison. 
//
//==============================================================================
bool V3PointsWithinTolerance(Point3 point1, Point3 point2)
{
	bool xEqual = false;
	bool yEqual = false;
	bool zEqual = false;
	
	xEqual = FloatsApproximatelyEqual(point1.x, point2.x);
	yEqual = FloatsApproximatelyEqual(point1.y, point2.y);
	zEqual = FloatsApproximatelyEqual(point1.z, point2.z);
	
	if( xEqual && yEqual && zEqual )
		return true;
	else
		return false;
	
}//end V3PointsWithinTolerance


//========== V3SquaredLength ===================================================
//
// Purpose:		returns squared length of input vector
//
//				Same as V3Dot(a,a)
//
//==============================================================================
float V3SquaredLength(Vector3 a) 
{
	return (	(a.x * a.x)
			+	(a.y * a.y)
			+	(a.z * a.z) );
	
}//end V3SquaredLength


//========== V3Length ==========================================================
//
// Purpose:		returns length of input vector
//
//==============================================================================
float V3Length(Vector3 a) 
{
	return sqrt(V3SquaredLength(a));
	
}//end V3Length


//========== V3Negate ==========================================================
//
// Purpose:		negates the input vector and returns it
//
//==============================================================================
Vector3 V3Negate(Vector3 v) 
{
	v.x = - v.x;
	v.y = - v.y;
	v.z = - v.z;
	
	return(v);
	
}//end V3Negate


//========== V3Normalize =======================================================
//
// Purpose:		normalizes the input vector and returns it
//
//==============================================================================
Vector3 V3Normalize(Vector3 v) 
{
	float len = V3Length(v);
	
	if (len != 0.0)
	{
		v.x /= len;
		v.y /= len;
		v.z /= len;
	}
	
	return(v);
	
}//end V3Normalize


//========== V3Scale ===========================================================
//
// Purpose:		scales the input vector to the new length and returns it
//
//==============================================================================
Vector3 V3Scale(Vector3 v, float newlen) 
{
	float len = V3Length(v);
	
	if (len != 0.0)
	{
		v.x *= newlen / len;
		v.y *= newlen / len;
		v.z *= newlen / len;
	}
	
	return(v);
	
}//end V3Scale


//========== V3Add =============================================================
//
// Purpose:		return vector sum c = a + b
//
//==============================================================================
Vector3 V3Add(Vector3 a, Vector3 b)
{
	Vector3 result;

	result.x = a.x + b.x;
	result.y = a.y + b.y;
	result.z = a.z + b.z;
	
	return result;
	
}//end V3Add


//========== V3Sub =============================================================
//
// Purpose:		return vector difference c = a-b
//
//==============================================================================
Vector3 V3Sub(Vector3 a, Vector3 b)
{
	Vector3 result;

	result.x = a.x - b.x;
	result.y = a.y - b.y;
	result.z = a.z - b.z;
	
	return result;
	
}//end V3Sub


//========== V3Dot =============================================================
//
// Purpose:		return the dot product of vectors a and b
//
//==============================================================================
float V3Dot(Vector3 a, Vector3 b) 
{
	return (	(a.x * b.x)
			+	(a.y * b.y)
			+	(a.z * b.z) );
	
}//end V3Dot


//========== V3Lerp ============================================================
//
// Purpose:		linearly interpolate between vectors by an amount alpha and 
//				return the resulting vector. 
//
//				When alpha=0, result=lo.  When alpha=1, result=hi.
//
//==============================================================================
Vector3 V3Lerp(Vector3 lo, Vector3 hi, float alpha) 
{
	Vector3 result;

	result.x = LERP(alpha, lo.x, hi.x);
	result.y = LERP(alpha, lo.y, hi.y);
	result.z = LERP(alpha, lo.z, hi.z);
	
	return(result);
	
}//end V3Lerp


//========== V3Combine =========================================================
//
// Purpose:		make a linear combination of two vectors and return the result.
//
//				result = (a * ascl) + (b * bscl)
//
//==============================================================================
Vector3 V3Combine (Vector3 a, Vector3 b, float ascl, float bscl) 
{
	Vector3 result;
	
	result.x = (ascl * a.x) + (bscl * b.x);
	result.y = (ascl * a.y) + (bscl * b.y);
	result.z = (ascl * a.z) + (bscl * b.z);
	
	return(result);
	
}//end V3Combine


//========== V3Mul =============================================================
//
// Purpose:		Multiply two vectors together component-wise and return the 
//				result.
//
//==============================================================================
Vector3 V3Mul(Vector3 a, Vector3 b) 
{
	Vector3 result;
	
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	result.z = a.z * b.z;
	
	return(result);
	
}//end V3Mul


//========== V3MulScalar =======================================================
//
// Purpose:		Returns (a * scalar).
//
//==============================================================================
Vector3 V3MulScalar(Vector3 a, float scalar) 
{
	Vector3 result;
	
	result.x = a.x * scalar;
	result.y = a.y * scalar;
	result.z = a.z * scalar;
	
	return(result);
	
}//end V3Mul


//========== V3DistanceBetween2Points ==========================================
//
// Purpose:		return the distance between two points
//
//==============================================================================
float V3DistanceBetween2Points(Point3 a, Point3 b)
{
	float dx = a.x - b.x;
	float dy = a.y - b.y;
	float dz = a.z - b.z;
	
	float distance	= sqrt( (dx*dx) + (dy*dy) + (dz*dz) );
	
	return distance;
	
}//end V3DistanceBetween2Points


//========== V3Cross ===========================================================
//
// Purpose:		return the cross product c = a x b
//
//==============================================================================
Vector3 V3Cross(Vector3 a, Vector3 b)
{
	Vector3 c;

	c.x = (a.y * b.z) - (a.z * b.y);
	c.y = (a.z * b.x) - (a.x * b.z);
	c.z = (a.x * b.y) - (a.y * b.x);
	
	return(c);
	
}//end V3Cross


//========== V3Midpoint ========================================================
//
// Purpose:		Returns the midpoint of the line segment between point1 and 
//				point2.
//
//==============================================================================
Point3 V3Midpoint(Point3 point1, Point3 point2)
{
	Point3 midpoint;
	
	midpoint.x = (point1.x + point2.x) / 2;
	midpoint.y = (point1.y + point2.y) / 2;
	midpoint.z = (point1.z + point2.z) / 2;
	
	return midpoint;
	
}//end V3Midpoint


//========== V3IsolateGreatestComponent ========================================
//
// Purpose:		Leaves unchanged the component of vector which has the greatest 
//				absolute value, but zeroes the other components. 
//				Example: <4, -7, 1> -> <0, -7, 0>.
//				This is useful for figuring out the direction of input.
//
//==============================================================================
Vector3 V3IsolateGreatestComponent(Vector3 vector)
{
	if(fabs(vector.x) > fabs(vector.y) )
	{
		vector.y = 0;
		
		if(fabs(vector.x) > fabs(vector.z) )
			vector.z = 0;
		else
			vector.x = 0;
	}
	else
	{
		vector.x = 0;
		
		if(fabs(vector.y) > fabs(vector.z) )
			vector.z = 0;
		else
			vector.y = 0;
	}
	
	return vector;
	
}//end V3IsolateGreatestComponent


//========== V3Print ===========================================================
//
// Purpose:		Prints the given 3D point.
//
//==============================================================================
void V3Print(Point3 point)
{
	printf("(%12.6f, %12.6f, %12.6f)\n", point.x, point.y, point.z);
	
}//end V3Print


//========== V3RayIntersectsTriangle ===========================================
//
// Purpose:		Returns whether the given (normalized) ray intersects the 
//				triangle. 
//				http://www.graphics.cornell.edu/pubs/1997/MT97.html
//
// Parameters:	ray - selection ray
//				vert[0-2] - vertexes of triangle (in same coordinates as ray)
//				intersectDepth - on return, distance from ray origin to triangle 
//						intersection 
//				intersectPoint - on return, barycentric coordinates within 
//						triangle of intersection point (can be NULL). 
//
//==============================================================================
bool V3RayIntersectsTriangle(Ray3 ray,
							 Point3 vert0, Point3 vert1, Point3 vert2,
							 float *intersectDepth, Point2 *intersectPointOut)
{
	Vector3 edge1;
	Vector3 edge2;
	Vector3 tvec;
	Vector3 pvec;
	Vector3 qvec;
	double  det         = 0;
	double  inv_det     = 0;
	float   distance    = 0;
	float   u           = 0;
	float   v           = 0;
	
	// find vectors for two edges sharing vert0
	edge1 = V3Sub(vert1, vert0);
	edge2 = V3Sub(vert2, vert0);
	
	// begin calculating determinant - also used to calculate U parameter
	pvec = V3Cross(ray.direction, edge2);
	
	// if determinant is near zero, ray lies in plane of triangle
	det = V3Dot(edge1, pvec);
	
	if (det > -SMALL_NUMBER && det < SMALL_NUMBER)
		return false;
	inv_det = 1.0 / det;
	
	// calculate distance from vert0 to ray origin
	tvec = V3Sub(ray.origin, vert0);
	
	// calculate U parameter and test bounds
	u = V3Dot(tvec, pvec) * inv_det;
	if (u < 0.0 || u > 1.0)
		return false;
	
	// prepare to test V parameter
	qvec = V3Cross(tvec, edge1);
	
	// calculate V parameter and test bounds
	v = V3Dot(ray.direction, qvec) * inv_det;
	if (v < 0.0 || u + v > 1.0)
		return false;
	
	// calculate t, ray intersects triangle
	distance = V3Dot(edge2, qvec) * inv_det;
	
	// Intersects; return info
	if(intersectDepth)      *intersectDepth     = distance;
	if(intersectPointOut)   *intersectPointOut  = V2Make(u, v);
	
	return true;
}


//========== V3RayIntersectsSegment ============================================
//
// Purpose:		Determines if the shortest distance between the ray and segment 
//				is within the tolerance. 
//
// Notes:		The tolerance is necessary because two lines in 3D graphics will 
//				almost never actually intersect. But they may be within 1 pixel 
//				of each other! 
//
//				Adapted from
//				http://softsurfer.com/Archive/algorithm_0106/algorithm_0106.htm
//				The body contains commented-out code for determining the closest 
//				points between two line segments, rather than an infinite ray 
//				and a finite segment. 
//
// Parameters:	ray - selection ray
//				segment2 - line segment to test (in same coordinates as ray)
//				tolerance - max distance to consider intersection
//				intersectDepth - on return, distance from ray origin to segment 
//						intersection 
//
//==============================================================================
bool V3RayIntersectsSegment(Ray3 segment1, Segment3 segment2,
							float tolerance,
							float *intersectDepth)
{
	Vector3 u           = segment1.direction; //V3Sub(segment1.point1, segment1.point0);
	Vector3 v           = V3Sub(segment2.point1, segment2.point0);
	Vector3 w           = V3Sub(segment1.origin, segment2.point0);
	float   a           = V3Dot(u,u);        // always >= 0
	float   b           = V3Dot(u,v);
	float   c           = V3Dot(v,v);        // always >= 0
	float   d           = V3Dot(u,w);
	float   e           = V3Dot(v,w);
	float   D           = a*c - b*b;       // always >= 0
	float   sc          = 0; // sc = sN / sD, default sD = D >= 0
	float   sN          = 0;
	float   sD          = 0;
	float   tc          = 0; // tc = tN / tD, default tD = D >= 0
	float   tN          = 0;
	float   tD          = 0;
	bool    intersects  = false;

	// compute the line parameters of the two closest points
	if (D < SMALL_NUMBER)
	{	// the lines are almost parallel
		sN = 0.0;        // force using point0 on segment S1
		sD = 1.0;        // to prevent possible division by 0.0 later
		
		tN = e;
		tD = c;
	}
	else
	{
		// get the closest points on the infinite lines
		
		sN = (b*e - c*d);
		sD = D;
		
		tN = (a*e - b*d);
		tD = D;
		
		if (sN < 0.0)		// sc < 0 => the s=0 edge is visible
		{
			sN = 0.0;
			tN = e;
			tD = c;
		}
//		else if (sN > sD)	// sc > 1 => the s=1 edge is visible
//		{
// I think this is the part needed if the ray had been a segment instead of a ray
// As it is, we only care that sN >= 0
//			sN = sD;
//			tN = e + b;
//			tD = c;
//		}
	}

	if (tN < 0.0)			// tc < 0 => the t=0 edge is visible
	{
		tN = 0.0;
		// recompute sc for this edge
		if (-d < 0.0)
		{
			sN = 0.0;
		}
//		else if (-d > a)
//		{
// I think this is the part needed if the ray had been a segment instead of a ray
// As it is, we only care that sN >= 0
//			sN = sD;
//		}
		else
		{
			sN = -d;
			sD = a;
		}
	}
	else if (tN > tD)		// tc > 1 => the t=1 edge is visible
	{
		tN = tD;
		// recompute sc for this edge
		if ((-d + b) < 0.0)
		{
			sN = 0;
		}
//		else if ((-d + b) > a)
//		{
// I think this is the part needed if the ray had been a segment instead of a ray
// As it is, we only care that sN >= 0
//			sN = sD;
//		}
		else
		{
			sN = (-d + b);
			sD = a;
		}
	}
	// finally do the division to get sc and tc
	sc = (fabs(sN) < SMALL_NUMBER ? 0.0 : sN / sD);
	tc = (fabs(tN) < SMALL_NUMBER ? 0.0 : tN / tD);

	// get the difference of the two closest points
	// distance = S1(sc) - S2(tc)
	//
//	Point3  s1  = V3Add(segment1.point0, V3MulScalar(u, sc));
//	Point3  s2  = V3Add(segment2.point0, V3MulScalar(v, tc));
//	Vector3 dP  = V3Sub(s1, s2);
	// a more compact form: dP  =   w + (sc * u) - (tc * v)   =   S1(sc) - S2(tc)
	Vector3 dP              = V3Add(w, V3Sub( V3MulScalar(u, sc), V3MulScalar(v, tc)) );
	float   minCloseness    = V3Length(dP);   // return the closest distance
	
//	printf("closeness = %f\n", minCloseness);
	
	if(minCloseness <= tolerance)
	{
		if(intersectDepth)	*intersectDepth = sc;
		intersects = true;
	}

	return intersects;
}


//========== V3RayIntersectsSphere =============================================
//
// Purpose:		Returns whether the given (normalized) ray intersects the 
//				sphere. 
//
// Notes:		Derived from solving:
//				R(t) = O + td								// ray starting at (xO, yO, zO) extending in direction (dx, dy, dz)
//				r^2 = (x - xc)^2 + (y - yc)^2 + (z - zc)^2  // sphere radius r centered at (xc, yc, zc)
//
//				http://www.siggraph.org/education/materials/HyperGraph/raytrace/rtinter1.htm
//
//==============================================================================
bool V3RayIntersectsSphere(Ray3 ray, Point3 sphereCenter, float radius,
						   float *intersectDepth)
{
	float   b               = 0;
	float   c               = 0;
	float   discriminant;
	float   distance        = 0;
	bool    intersects      = false;
	
	// b and c stand for terms in the quadratic equation which solves for the 
	// depth of an intersection along the ray. (a is always 1 when the ray is 
	// normalized). 
	
	b = 2 * (  ray.direction.x * (ray.origin.x - sphereCenter.x)
			 + ray.direction.y * (ray.origin.y - sphereCenter.y)
			 + ray.direction.z * (ray.origin.z - sphereCenter.z) );

	c =		   pow(ray.origin.x - sphereCenter.x, 2)
			 + pow(ray.origin.y - sphereCenter.y, 2)
			 + pow(ray.origin.z - sphereCenter.z, 2)
			 - (radius * radius);
			 
	// Find the discriminant (the part under the square root) of the quadratic 
	// formula to determine if there are solutions (intersections). 
	discriminant = b*b - 4*c;
	
	if(discriminant >= 0.0)
	{
		distance = (-b - sqrt(discriminant))/2;
		
		if(distance <= 0)
		{
			distance = (-b + sqrt(discriminant))/2;
		}
		intersects = true;
		
		if(intersectDepth) *intersectDepth = distance;
	}
	
	return intersects;
}


#pragma mark -

//========== V3BoundsFromPoints ================================================
//
// Purpose:		Sorts the points into their minimum and maximum.
//
//==============================================================================
Box3 V3BoundsFromPoints(Point3 point1, Point3 point2)
{
	Box3 bounds;

	bounds.min.x = MIN(point1.x, point2.x);
	bounds.min.y = MIN(point1.y, point2.y);
	bounds.min.z = MIN(point1.z, point2.z);
	
	bounds.max.x = MAX(point1.x, point2.x);
	bounds.max.y = MAX(point1.y, point2.y);
	bounds.max.z = MAX(point1.z, point2.z);
	
	return bounds;
	
}//end V3BoundsFromPoints


//========== V3CenterOfBox =====================================================
//
// Purpose:		Returns the center of the box.
//
//==============================================================================
Point3 V3CenterOfBox(Box3 box)
{
	Point3 center = V3Midpoint(box.min, box.max);
	
	return center;
	
}//end V3CenterOfBox


//========== V3EqualBoxes ======================================================
//
// Purpose:		Returns 1 (YES) if the two boxes are equal; 0 otherwise.
//
//==============================================================================
int V3EqualBoxes(Box3 box1, Box3 box2)
{
	return (	box1.min.x == box2.min.x
			&&	box1.min.y == box2.min.y
			&&	box1.min.z == box2.min.z
				
			&&	box1.max.x == box2.max.x
			&&	box1.max.y == box2.max.y
			&&	box1.max.z == box2.max.z  );
			
}//end V3EqualBoxes


//========== V3UnionBox ========================================================
//
// Purpose:		Returns the smallest box that completely encloses both aBox and 
//				bBox. 
//
// Notes:		If you pass something stupid in as the parameter, you will get 
//				an appropriately stupid answer. 
//
//==============================================================================
Box3 V3UnionBox(Box3 aBox, Box3 bBox)
{
	Box3	bounds				= InvalidBox;
	
	bounds.min.x = MIN(aBox.min.x, bBox.min.x);
	bounds.min.y = MIN(aBox.min.y, bBox.min.y);
	bounds.min.z = MIN(aBox.min.z, bBox.min.z);
	
	bounds.max.x = MAX(aBox.max.x, bBox.max.x);
	bounds.max.y = MAX(aBox.max.y, bBox.max.y);
	bounds.max.z = MAX(aBox.max.z, bBox.max.z);
	
	return bounds;

}//end V3UnionBox



//========== V3UnionBoxAndPoint ================================================
//
// Purpose:		Returns the smallest box that completely encloses both box and 
//				point. 
//
//==============================================================================
Box3 V3UnionBoxAndPoint(Box3 box, Point3 point)
{
	Box3	bounds				= InvalidBox;
	
	bounds.min.x = MIN(box.min.x, point.x);
	bounds.min.y = MIN(box.min.y, point.y);
	bounds.min.z = MIN(box.min.z, point.z);
	
	bounds.max.x = MAX(box.max.x, point.x);
	bounds.max.y = MAX(box.max.y, point.y);
	bounds.max.z = MAX(box.max.z, point.z);
	
	return bounds;

}//end V3UnionBoxAndPoint


#pragma mark -

//========== V3MulPointByMatrix ================================================
//
// Purpose:		multiply a point by a matrix and return the transformed point
//
//==============================================================================
Point3 V3MulPointByMatrix(Point3 pin, Matrix3 m)
{
	Point3 pout = ZeroPoint3;
	
	pout.x =	(pin.x * m.element[0][0])
			 +	(pin.y * m.element[1][0])
			 +	(pin.z * m.element[2][0]);
			 
	pout.y =	(pin.x * m.element[0][1])
			 +	(pin.y * m.element[1][1])
			 +	(pin.z * m.element[2][1]);
			 
	pout.z =	(pin.x * m.element[0][2])
			 +	(pin.y * m.element[1][2])
			 +	(pin.z * m.element[2][2]);
		
	return pout;
	
}//end V3MulPointByMatrix


//========== V3MulPointByProjMatrix ============================================
//
// Purpose:		multiply a point by a projective matrix and return the 
//				transformed point 
//
//==============================================================================
Point3 V3MulPointByProjMatrix(Point3 pin, Matrix4 m)
{
	Point3  pout    = ZeroPoint3;
	float   w       = 0.0;
	
	pout.x =	(pin.x * m.element[0][0])
			 +	(pin.y * m.element[1][0])
			 + 	(pin.z * m.element[2][0])
			 +	m.element[3][0];
			 
	pout.y =	(pin.x * m.element[0][1])
			 +	(pin.y * m.element[1][1])
			 + 	(pin.z * m.element[2][1])
			 +	m.element[3][1];
			 
	pout.z =	(pin.x * m.element[0][2])
			 +	(pin.y * m.element[1][2])
			 + 	(pin.z * m.element[2][2])
			 +	m.element[3][2];
			 
	w =			(pin.x * m.element[0][3])
			 +	(pin.y * m.element[1][3])
			 +	(pin.z * m.element[2][3])
			 +	m.element[3][3];
			 
	if (w != 0.0)
	{
		pout.x /= w;
		pout.y /= w;
		pout.z /= w;
	}
	
	return(pout);
	
}//end V3MulPointByProjMatrix


//========== V3LookAt ==========================================================
//
// Purpose:		Creates a viewing matrix derived from an eye point, a reference 
//				point indicating the center of the scene, and an UP vector. 
//
// Notes:		Replacement for gluLookAt.
//
//==============================================================================
Matrix4 V3LookAt(Point3  eye,
				 Point3  center,
				 Vector3 up,
				 Matrix4 modelview)
{
	Vector3 F               = V3Sub(center, eye);
	Vector3 f               = V3Normalize(F);
	Vector3 upNormal        = V3Normalize(up);
	Vector3 s               = V3Cross(f, upNormal);
	Vector3 u               = V3Cross(s, f);
	Matrix4 M               = IdentityMatrix4;
	Matrix4 newModelview    = modelview;
	
	// Transpose of M used by gluLookAt, which uses column-major notation. 
	M.element[0][0] = s.x;
	M.element[1][0] = s.y;
	M.element[2][0] = s.z;
	M.element[3][0] = 0;

	M.element[0][1] = u.x;
	M.element[1][1] = u.y;
	M.element[2][1] = u.z;
	M.element[3][1] = 0;

	M.element[0][2] = -f.x;
	M.element[1][2] = -f.y;
	M.element[2][2] = -f.z;
	M.element[3][2] = 0;
	
	M.element[0][3] = 0;
	M.element[1][3] = 0;
	M.element[2][3] = 0;
	M.element[3][3] = 1;
	
	newModelview = Matrix4Translate(newModelview, V3MulScalar(eye, -1));
	newModelview = Matrix4Multiply(newModelview, M);
	
	return newModelview;
}


//========== V3Project =========================================================
//
// Purpose:		Projects the given object point into viewport coordinates. 
//
//				(Drop-in replacement for gluProject) 
//
//==============================================================================
Point3 V3Project(Point3 objPoint, Matrix4 modelview, Matrix4 projection, Box2 viewport)
{
	Point3  transformedPoint    = ZeroPoint3;
	Point3  windowPoint         = ZeroPoint3;
	
	transformedPoint = V3MulPointByProjMatrix(objPoint, Matrix4Multiply(modelview, projection));
	
	windowPoint.x = viewport.origin.x + (V2BoxWidth(viewport)  * (transformedPoint.x + 1)) / 2;
	windowPoint.y = viewport.origin.y + (V2BoxHeight(viewport) * (transformedPoint.y + 1)) / 2;
	windowPoint.z = (transformedPoint.z + 1) / 2;
	
	return windowPoint;
	
}//end V3Project


//========== V3Unproject =======================================================
//
// Purpose:		Given a point in viewport coordinates, returns the location in 
//				object coordinates. 
//
// Notes:		viewportPoint.z is the depth buffer location.
//
//				(Drop-in replacement for gluUnProject)
//
//==============================================================================
Point3 V3Unproject(Point3 viewportPoint, Matrix4 modelview, Matrix4 projection, Box2 viewport)
{
	Matrix4 inversePM   = IdentityMatrix4;
	Point3  normalized  = ZeroPoint3;
	Point3  modelPoint  = ZeroPoint3;
	
	normalized.x = 2 * (viewportPoint.x - viewport.origin.x) / V2BoxWidth(viewport) - 1;
	normalized.y = 2 * (viewportPoint.y - viewport.origin.y) / V2BoxHeight(viewport) - 1;
	normalized.z = 2 * (viewportPoint.z) - 1;
	
	inversePM   = Matrix4Invert( Matrix4Multiply(modelview, projection) );
	modelPoint  = V3MulPointByProjMatrix(normalized, inversePM);
	
	return modelPoint;
}


//========== Matrix3x3Determinant ==============================================
//
// Purpose:		Calculate the determinant of a 3x3 matrix in the form 
//
//				| a1,  b1,  c1 |
//				| a2,  b2,  c2 |
//				| a3,  b3,  c3 |
//
//==============================================================================
float Matrix3x3Determinant( float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3 )
{
    float ans;
	
    ans = a1 * Matrix2x2Determinant( b2, b3, c2, c3 )
        - b1 * Matrix2x2Determinant( a2, a3, c2, c3 )
        + c1 * Matrix2x2Determinant( a2, a3, b2, b3 );
    return ans;
	
}//end Matrix3x3Determinant


//========== Matrix3MakeNormalTransformFromProjMatrix ==========================
//
// Purpose:		Normal vectors (for lighting) cannot be transformed by the same 
//				matrix which transforms vertexes. This method returns the 
//				correct matrix to transform normals for the given vertex 
//				transform (modelview) matrix. 
//
// Notes:		See "Matrices" notes in Bricksmith/Information for derivation.
//
//				Also http://www.lighthouse3d.com/opengl/glsl/index.php?normalmatrix
//				and  http://www.songho.ca/opengl/gl_normaltransform.html
//
//				We only need a 3x3 matrix because the translation in the 4x4 
//				transform (row 4) is undesirable anyway (a 4D vector should be 
//				[x y z 0]), and column 4 isn't used. 
//
//==============================================================================
Matrix3 Matrix3MakeNormalTransformFromProjMatrix(Matrix4 transformationMatrix)
{
	Matrix4 normalTransform     = IdentityMatrix4;
	Matrix3 normalTransform3    = IdentityMatrix3;
	int     row                 = 0;
	int     column              = 0;
	
	// The normal transform is the inverse transpose of the vertex transform.
	
	normalTransform = Matrix4Invert(transformationMatrix);
	normalTransform = Matrix4Transpose(normalTransform);
	
	// Convert to a 3x3 matrix, because row 4 and column 4 are unnecessary.
	for(row = 0; row < 3; row++)
	{
		for(column = 0; column < 3; column++)
			normalTransform3.element[row][column] = normalTransform.element[row][column];
	}
	
	return normalTransform3;
	
}//end Matrix3MakeNormalTransformFromProjMatrix


#pragma mark -
#pragma mark 4-D LIBRARY
#pragma mark -

//========== V4Make ============================================================
//
// Purpose:		Makes a new 4-dimensional vector.
//
//==============================================================================
Vector4 V4Make(float x, float y, float z, float w)
{
	Vector4 v;
	
	v.x = x;
	v.y = y;
	v.z = z;
	v.w = w;
	
	return(v);
	
}//end V4Make


//========== V4FromPoint3 ======================================================
//
// Purpose:		Create a new 4D point whose components match the given 3D 
//				point, with a 1 in the 4th dimension.
//
// Notes:		This method is not suitable for creating 4D vectors, whose w 
//				value must be 0. (That will cause the translation part of a 4x4 
//				transformation matrix to have no effect, which is what you want 
//				for vectors.) 
//
//==============================================================================
Point4 V4FromPoint3(Vector3 originalPoint)
{
	Point4 newPoint;
	
	newPoint.x = originalPoint.x;
	newPoint.y = originalPoint.y;
	newPoint.z = originalPoint.z;
	newPoint.w = 1; // By setting this to 1, the returned value is a point. Vectors would be set to 0.
	
	return newPoint;
	
}//end V4FromPoint3


//========== V4MulPointByMatrix() ==============================================
//
// Purpose:		multiply a hom. point by a matrix and return the transformed 
//				point
//
// Source:		Graphic Gems II, Spencer W. Thomas
//
//==============================================================================
Vector4 V4MulPointByMatrix(Vector4 pin, Matrix4 m)
{
	Vector4 pout;

	pout.x	=	(pin.x * m.element[0][0])
			 +	(pin.y * m.element[1][0])
			 +	(pin.z * m.element[2][0])
			 +	(pin.w * m.element[3][0]);
			 
	pout.y	=	(pin.x * m.element[0][1])
			 +	(pin.y * m.element[1][1])
			 +	(pin.z * m.element[2][1])
			 +	(pin.w * m.element[3][1]);
	
	pout.z	=	(pin.x * m.element[0][2])
			 +	(pin.y * m.element[1][2])
			 +	(pin.z * m.element[2][2])
			 +	(pin.w * m.element[3][2]);
		
	pout.w	=	(pin.x * m.element[0][3])
			 +	(pin.y * m.element[1][3])
			 +	(pin.z * m.element[2][3])
			 +	(pin.w * m.element[3][3]);
		
	return (pout);
	
}//end V4MulPointByMatrix

#pragma mark -

//========== Matrix4CreateFromGLMatrix4() ======================================
//
// Purpose:		Returns a two-dimensional (row matrix) representation of the 
//				given OpenGL transformation matrix.
//
//																  +-       -+
//				+-                             -+        +-     -+| a d g 0 |
//				|a d g 0 b e h 0 c f i 0 x y z 1|  -->   |x y z 1|| b e h 0 |
//				+-                             -+        +-     -+| c f i 0 |
//													              | x y z 1 |
//																  +-       -+
//					  OpenGL Matrix Format                Matrix4 Format
//				(flat column-major of transpose)   (shown multiplied by a point)  
//
//==============================================================================
Matrix4 Matrix4CreateFromGLMatrix4(const GLfloat *glMatrix)
{
	int		row, column;
	Matrix4	newMatrix;
	
	for(row = 0; row < 4; row++)
		for(column = 0; column < 4; column++)
			newMatrix.element[row][column] = glMatrix[row * 4 + column];
	
	return newMatrix;
	
}//end Matrix4CreateFromGLMatrix4


//========== Matrix4CreateTransformation() =====================================
//
// Purpose:		Given the scale, shear, rotation, translation, and perspective 
//				paramaters, create a 4x4 transformation.element matrix used to 
//				modify row-matrix points.
//
//				To reverse the procedure, pass the returned matrix to Matrix4DecomposeTransformation().
//
// Notes:		This ignores perspective, which is not supported.
//
// Source:		Allen Smith, after too much handwork.
//
//==============================================================================
Matrix4 Matrix4CreateTransformation(TransformComponents *components)
{
	Matrix4	transformation = IdentityMatrix4; //zero out the whole thing.
	float	rotation[3][3];
	
	//Create the rotation matrix.
	double sinX = sin(components->rotate.x);
	double cosX = cos(components->rotate.x);
	
	double sinY = sin(components->rotate.y);
	double cosY = cos(components->rotate.y);
	
	double sinZ = sin(components->rotate.z);
	double cosZ = cos(components->rotate.z);
	
	rotation[0][0] = cosY * cosZ;
	rotation[0][1] = cosY * sinZ;
	rotation[0][2] = -sinY;
	
	rotation[1][0] = sinX*sinY*cosZ - cosX*sinZ;
	rotation[1][1] = sinX*sinY*sinZ + cosX*cosZ;
	rotation[1][2] = sinX*cosY;
	
	rotation[2][0] = cosX*sinY*cosZ + sinX*sinZ;
	rotation[2][1] = cosX*sinY*sinZ - sinX*cosZ;
	rotation[2][2] = cosX*cosY;
	
	//Build the transformation.element matrix.
	// Seeing the transformation.element matrix in these terms helps to make sense of Matrix4DecomposeTransformation().
	transformation.element[0][0] = components->scale.x * rotation[0][0];
	transformation.element[0][1] = components->scale.x * rotation[0][1];
	transformation.element[0][2] = components->scale.x * rotation[0][2];

	transformation.element[1][0] = components->scale.y * (components->shear_XY * rotation[0][0] + rotation[1][0]);
	transformation.element[1][1] = components->scale.y * (components->shear_XY * rotation[0][1] + rotation[1][1]);
	transformation.element[1][2] = components->scale.y * (components->shear_XY * rotation[0][2] + rotation[1][2]);

	transformation.element[2][0] = components->scale.z * (components->shear_XZ * rotation[0][0] + components->shear_YZ * rotation[1][0] + rotation[2][0]);
	transformation.element[2][1] = components->scale.z * (components->shear_XZ * rotation[0][1] + components->shear_YZ * rotation[1][1] + rotation[2][1]);
	transformation.element[2][2] = components->scale.z * (components->shear_XZ * rotation[0][2] + components->shear_YZ * rotation[1][2] + rotation[2][2]);
	
	//translation is so nice and easy.
	transformation.element[3][0] = components->translate.x;
	transformation.element[3][1] = components->translate.y;
	transformation.element[3][2] = components->translate.z;
	
	//And lastly the corner.
	transformation.element[3][3] = 1;
	
	return transformation;
	
}//end Matrix4CreateTransformation


//========== Matrix4DecomposeTransformation() ==================================
//
// Purpose:		Decompose a non-degenerate 4x4 transformation.element matrix 
//				into the sequence of transformations that produced it.
//
//		[Sx][Sy][Sz][Shearx/y][Sx/z][Sz/y][Rx][Ry][Rz][Tx][Ty][Tz][P(x,y,z,w)]
//
//				The coefficient of each transformation.element is returned in 
//				the corresponding element of the vector tran.
//
// Returns:		1 upon success, 0 if the matrix is singular.
//
// Source:		Graphic Gems II, Spencer W. Thomas
//
//==============================================================================
int Matrix4DecomposeTransformation( Matrix4 originalMatrix,
									TransformComponents *decomposed )
{
	int			counter		= 0;
	int			j			= 0;
	Matrix4		localMatrix	= originalMatrix;
	Matrix4		pmat, invpmat, tinvpmat;
	Vector4		prhs, psol;
	Tuple3		row[3];
	
 	// Normalize the matrix.
 	if ( localMatrix.element[3][3] == 0 )
 		return 0;
	
 	for ( counter=0; counter<4;counter++ )
 		for ( j=0; j<4; j++ )
 			localMatrix.element[counter][j] /= localMatrix.element[3][3];
	
	
  	//---------- Perspective ---------------------------------------------------
	// Perspective is not used by Bricksmith.
	
 	// pmat is used to solve for perspective, but it also provides an easy way 
 	// to test for singularity of the upper 3x3 component. 
 	pmat = localMatrix;
 	for ( counter = 0; counter < 3; counter++ )
 		pmat.element[counter][3] = 0;
 	pmat.element[3][3] = 1;
	
 	if ( Matrix4x4Determinant(&pmat) == 0.0 )
 		return 0;
	
 	// First, isolate perspective.  This is the messiest.
 	if ( localMatrix.element[0][3] != 0 || localMatrix.element[1][3] != 0 ||
		 localMatrix.element[2][3] != 0 ) {
 		// prhs is the right hand side of the equation.
 		prhs.x = localMatrix.element[0][3];
 		prhs.y = localMatrix.element[1][3];
 		prhs.z = localMatrix.element[2][3];
 		prhs.w = localMatrix.element[3][3];
		
 		// Solve the equation by inverting pmat and multiplying prhs by the 
 		// inverse.  (This is the easiest way, not necessarily the best.) 
		// inverse function (and Matrix4x4Determinant, above) from the Matrix
		// Inversion gem in the first volume.
 		invpmat		= Matrix4Invert(pmat);
		tinvpmat	= Matrix4Transpose(invpmat);
 		psol		= V4MulPointByMatrix(prhs, tinvpmat);
		
 		// Stuff the answer away.
 		decomposed->perspective.x = psol.x;
 		decomposed->perspective.y = psol.y;
 		decomposed->perspective.z = psol.z;
 		decomposed->perspective.w = psol.w;
 		// Clear the perspective partition.
 		localMatrix.element[0][3] = 0;
		localMatrix.element[1][3] = 0;
		localMatrix.element[2][3] = 0;
 		localMatrix.element[3][3] = 1;
 	}
	//No perspective
	else{
 		decomposed->perspective.x = 0;
		decomposed->perspective.y = 0;
		decomposed->perspective.z = 0;
		decomposed->perspective.w = 0;
	}
	
	
  	//---------- Translation ---------------------------------------------------

	// This is really easy.
	decomposed->translate.x = localMatrix.element[3][0];
	decomposed->translate.y = localMatrix.element[3][1];
	decomposed->translate.z = localMatrix.element[3][2];
	
	//Zero out the translation as we continue to decompose.
	for ( counter = 0; counter < 3; counter++ ) {
		localMatrix.element[3][counter] = 0;
 	}
	
	
 	//---------- Now get scale and shear. --------------------------------------
	
	// First translate to vector format, because all our linear combination 
	// functions expect vector datatypes. 
 	for ( counter=0; counter<3; counter++ ) {
 		row[counter].x = localMatrix.element[counter][0];
 		row[counter].y = localMatrix.element[counter][1];
 		row[counter].z = localMatrix.element[counter][2];
 	}
	
 	// Compute X scale factor and normalize first row.
 	decomposed->scale.x = V3Length(row[0]);
 	row[0] = V3Scale(row[0], 1.0);
	
 	// Compute XY shear factor and make 2nd row orthogonal to 1st.
 	decomposed->shear_XY = V3Dot(row[0], row[1]);
 	row[1] = V3Combine(row[1], row[0], 1.0, -decomposed->shear_XY);
	
 	// Now, compute Y scale and normalize 2nd row.
 	decomposed->scale.y = V3Length(row[1]);
 	row[1] = V3Scale(row[1], 1.0);
 	decomposed->shear_XY /= decomposed->scale.y;
	
 	// Compute XZ and YZ shears, orthogonalize 3rd row.
 	decomposed->shear_XZ = V3Dot(row[0], row[2]);
 	row[2] = V3Combine(row[2], row[0], 1.0, -decomposed->shear_XZ);
 	decomposed->shear_YZ = V3Dot(row[1], row[2]);
 	row[2] = V3Combine(row[2], row[1], 1.0, -decomposed->shear_YZ);
	
 	// Next, get Z scale and normalize 3rd row.
 	decomposed->scale.z = V3Length(row[2]);
 	row[2] = V3Scale(row[2], 1.0);
 	decomposed->shear_XZ /= decomposed->scale.z;
 	decomposed->shear_YZ /= decomposed->scale.z;
	
 	// At this point, the matrix (in rows[]) is orthonormal.
 	// Check for a coordinate system flip.  If the determinant is -1, then 
 	// negate the matrix and the scaling factors. 
 	if ( V3Dot( row[0], V3Cross(row[1], row[2]) ) < 0 )
	{
		decomposed->scale.x *= -1;
		decomposed->scale.y *= -1;
		decomposed->scale.z *= -1;
		
 		for ( counter = 0; counter < 3; counter++ )
		{
 			row[counter].x *= -1;
 			row[counter].y *= -1;
 			row[counter].z *= -1;
 		}
		
	}
	
	
 	//---------- Extract Rotation Angles ---------------------------------------
	
	// Convert back to the matrix datatype, because that is what the 
	// decomposition function expects. 
	localMatrix = IdentityMatrix4;
 	for ( counter = 0; counter < 3; counter++ )
	{
 		localMatrix.element[counter][0] = row[counter].x;
 		localMatrix.element[counter][1] = row[counter].y;
 		localMatrix.element[counter][2] = row[counter].z;
 	}
	
	// extract rotation
	decomposed->rotate = Matrix4DecomposeXYZRotation(localMatrix);
	
	
 	// All done!
 	return 1;
	
}//end Matrix4DecomposeTransformation


//========== Matrix4DecomposeXYZRotation =======================================
//
// Purpose:		Decomposes a rotation matrix into an X-Y-Z angle (in radians) 
//				which would yield it, such that the X angle is applied first and 
//				the Z angle last. 
//
//				The matrix must not have any affect other than rotation.
//
//==============================================================================
Tuple3 Matrix4DecomposeXYZRotation(Matrix4 matrix)
{
	Tuple3 rotationAngle	= ZeroPoint3;
	
	// Y is easy.
	rotationAngle.y = asin(-matrix.element[0][2]);
	
	//cos(Y) != 0.
	// We can just use some simple algebra on the simplest components 
	// of the rotation matrix.
 	
	if ( fabs(cos(rotationAngle.y)) > SMALL_NUMBER )//within a tolerance of zero.
	{
 		rotationAngle.x = atan2(matrix.element[1][2], matrix.element[2][2]);
 		rotationAngle.z = atan2(matrix.element[0][1], matrix.element[0][0]);
 	}
	//cos(Y) == 0; so Y = +/- PI/2
	// this is a "singularity" that zeroes out the information we would 
	// usually use to determine X and Y.
	
	else if( rotationAngle.y < 0) // -PI/2
	{
 		rotationAngle.x = atan2(-matrix.element[2][1], matrix.element[1][1]);
 		rotationAngle.z = 0;
 	}
	else if( rotationAngle.y > 0) // +PI/2
	{
 		rotationAngle.x = atan2(matrix.element[2][1], matrix.element[1][1]);
 		rotationAngle.z = 0;
 	}
	
	return rotationAngle;
	
}//end Matrix4DecomposeXYZRotation


//========== Matrix4DecomposeZYXRotation =======================================
//
// Purpose:		Decomposes a rotation matrix into a Z-Y-X angle (in radians) 
//				which would yield it, such that the Z angle is applied first and 
//				the X angle last. 
//
//				The matrix must not have any affect other than rotation.
//
// Notes:		Any given rotation (matrix) is unique, but the angles which can 
//				produce it are not. We must make assumptions when decomposing. 
//				One of those assumptions is the order in which we assume the 
//				constituent angles were applied to produce the rotation. This 
//				method assumes they were applied in ZYX order, which will yield 
//				completely different numbers than the XYZ order would give for 
//				the same matrix. 
//
//==============================================================================
Tuple3 Matrix4DecomposeZYXRotation(Matrix4 matrix)
{
	Tuple3 rotationAngle	= ZeroPoint3;
	
	// Y is easy.
	rotationAngle.y = asin(matrix.element[2][0]);
	
	//cos(Y) != 0.
	// We can just use some simple algebra on the simplest components 
	// of the rotation matrix.
 	
	if ( fabs(cos(rotationAngle.y)) > SMALL_NUMBER )//within a tolerance of zero.
	{
 		rotationAngle.x = atan2(-matrix.element[2][1], matrix.element[2][2]);
 		rotationAngle.z = atan2(-matrix.element[1][0], matrix.element[0][0]);
 	}
	//cos(Y) == 0; so Y = +/- PI/2
	// this is a "singularity" that zeroes out the information we would 
	// usually use to determine X and Y.
	
	else if( rotationAngle.y < 0) // -PI/2
	{
 		rotationAngle.x = atan2(matrix.element[1][2], matrix.element[0][2]);
 		rotationAngle.z = 0;
 	}
	else if( rotationAngle.y > 0) // +PI/2
	{
 		rotationAngle.x = atan2(matrix.element[0][1], matrix.element[1][1]);
 		rotationAngle.z = 0;
 	}
	
	return rotationAngle;
	
}//end Matrix4DecomposeZYXRotation


//========== Matrix4GetGLMatrix4 ===============================================
//
// Purpose:		Converts the row-major row-vector matrix into a flat column-
//				major column-vector matrix understood by OpenGL.
//
//
//			 +-       -+     +-       -++- -+
//	+-     -+| a d g 0 |     | a b c x || x |
//	|x y z 1|| b e h 0 |     | d e f y || y |     +-                           -+
//	+-     -+| c f i 0 | --> | g h i z || z | --> |a d g 0 b e h c f i 0 x y z 1|
//			 | x y z 1 |     | 0 0 0 1 || 1 |     +-                           -+
//			 +-       -+     +-       -++- -+
//		LDraw Matrix            Transpose               OpenGL Matrix Format
//		   Format                                 (flat column-major of transpose)
//  (also Matrix4 format)
//
//==============================================================================
void Matrix4GetGLMatrix4(Matrix4 matrix, GLfloat *glTransformation)
{
	unsigned int row, column;
	
	for(row = 0; row < 4; row++)
	{
		for(column = 0; column < 4; column++)
		{
			glTransformation[row * 4 + column] = matrix.element[row][column];
		}
	}
	
}//end Matrix4GetGLMatrix4


//========== Matrix4Multiply ==========================================================
//
// Purpose:		multiply together matrices c = ab
//
// Notes:		c must not point to either of the input matrices
//
//==============================================================================
Matrix4 Matrix4Multiply(Matrix4 a, Matrix4 b)
{
	Matrix4 c       = IdentityMatrix4;
	int     row;
	int     column;
	int     k;
	
	for (row = 0; row < 4; row++)
	{
		for (column = 0; column < 4; column++)
		{
			c.element[row][column] = 0;
			
			for (k=0; k<4; k++)
				c.element[row][column] += a.element[row][k] * b.element[k][column];
		}
	}
	return(c);
	
}//end Matrix4Multiply


//========== Matrix4MultiplyGLMatrices =========================================
//
// Purpose:		multiply together matrices c = ab
//
// Notes:		c must not point to either of the input matrices
//
//==============================================================================
void Matrix4MultiplyGLMatrices(GLfloat *a, GLfloat *b, GLfloat *result)
{
	int row;
	int column;
	int k;
	
	// Zero the result
	memset(result, 0, sizeof(GLfloat[16]));
	
	// Multiply
	for (row = 0; row < 4; row++)
	{
		for (column = 0; column < 4; column++)
		{
			for (k=0; k<4; k++)
				result[row * 4 + column] += a[row * 4 + k] * b[k * 4 + column];
		}
	}
	
}//end Matrix4Multiply


//========== Matrix4Rotate() ===================================================
//
// Purpose:		Rotates the given matrix by the given number of degrees around 
//				each axis, placing the rotated matrix into the Matrix specified 
//				by the result parameter. Also returns result.
//
//				Rotation order is first X, then Y, and lastly Z.
//
//==============================================================================
Matrix4 Matrix4Rotate(Matrix4 original, Tuple3 degreesToRotate)
{
	TransformComponents rotateComponents    = IdentityComponents;
	Matrix4             addedRotation       = IdentityMatrix4;
	Matrix4             result              = IdentityMatrix4;

	//Create a new matrix that causes the rotation we want.
	//  (start with identity matrix)
	rotateComponents.rotate.x = radians(degreesToRotate.x);
	rotateComponents.rotate.y = radians(degreesToRotate.y);
	rotateComponents.rotate.z = radians(degreesToRotate.z);
	addedRotation = Matrix4CreateTransformation(&rotateComponents);
	
	result = Matrix4Multiply(original, addedRotation); //rotate at rotationCenter
	
	return result;

}//end Matrix4Rotate


//========== Matrix4RotateModelview() ==========================================
//
// Purpose:		Applies a rotation to a modelview matrix. Modelviews have 
//				translations to incorporate the camera location; this method 
//				maintains the camera location while rotating around the origin. 
//
//				Rotation order is first X, then Y, and lastly Z.
//
//==============================================================================
Matrix4 Matrix4RotateModelview(Matrix4 original, Tuple3 degreesToRotate)
{
	TransformComponents rotateComponents    = IdentityComponents;
	Matrix4             addedRotation       = IdentityMatrix4;
	Matrix4             result              = IdentityMatrix4;
	Vector3				camera				= ZeroPoint3;
	
	// Camera translation is in the bottom row of the matrix. Capture and clear 
	// it so we can apply the rotation around the world origin. 
	camera = V3Make(original.element[3][0], original.element[3][1], original.element[3][2]);
	original.element[3][0] = 0;
	original.element[3][1] = 0;
	original.element[3][2] = 0;
	
	//Create a new matrix that causes the rotation we want.
	//  (start with identity matrix)
	rotateComponents.rotate.x = radians(degreesToRotate.x);
	rotateComponents.rotate.y = radians(degreesToRotate.y);
	rotateComponents.rotate.z = radians(degreesToRotate.z);
	addedRotation = Matrix4CreateTransformation(&rotateComponents);
	
	result = Matrix4Multiply(original, addedRotation);
	result = Matrix4Translate(result, camera);
	
	return result;
	
}//end Matrix4RotateModelview


//========== Matrix4Scale() ====================================================
//
// Purpose:		Scales the given matrix by the given factors along 
//				each axis. Returns result.
//
//==============================================================================
Matrix4 Matrix4Scale(Matrix4 original, Tuple3 scaleFactors)
{
	TransformComponents components      = IdentityComponents;
	Matrix4             scalingMatrix   = IdentityMatrix4;
	Matrix4             result          = IdentityMatrix4;

	//Create a new matrix that causes the rotation we want.
	//  (start with identity matrix)
	components.scale = scaleFactors;
	scalingMatrix = Matrix4CreateTransformation(&components);
	
	result = Matrix4Multiply(original, scalingMatrix);
	
	return result;

}//end Matrix4Scale


//========== Matrix4Translate() ================================================
//
// Purpose:		Translates the given matrix by the given displacement, placing 
//				the translated matrix into the Matrix specified by the result 
//				parameter. Also returns result.
//
//==============================================================================
Matrix4 Matrix4Translate(Matrix4 original, Vector3 displacement)
{
	Matrix4 result = IdentityMatrix4;
	
	//Copy original to result
	result = original;
	
	result.element[3][0] += displacement.x; //applied directly to 
	result.element[3][1] += displacement.y; //the matrix because 
	result.element[3][2] += displacement.z; //that's easier here.
	
	return result;
	
}//end Matrix4Translate


//========== Matrix4Transpose() ================================================
//
// Purpose:		transpose rotation portion of matrix a, return b
//
// Source:		Graphic Gems II, Spencer W. Thomas
//
//==============================================================================
Matrix4 Matrix4Transpose(Matrix4 a)
{
	Matrix4 transpose	= IdentityMatrix4;
	int		i, j;
	
	for (i=0; i<4; i++)
		for (j=0; j<4; j++)
			transpose.element[i][j] = a.element[j][i];
			
	return transpose;
	
}//end Matrix4Transpose


//========== Matrix4Invert() ===================================================
//
// Purpose:		calculate the inverse of a 4x4 matrix
//
//				 -1     
//				A  = ___1__ adjoint A
//					  det A
//
//==============================================================================
Matrix4 Matrix4Invert( Matrix4 in )
{
	Matrix4 out = IdentityMatrix4;
	int     i;
	int     j;
	float   det = 0.0;
	
    Matrix4Adjoint( &in, &out );
	
    // Calculate the 4x4 determinant
	// If the determinant is zero, then the inverse matrix is not unique.
    det = Matrix4x4Determinant( &in );
	
    if ( fabs( det ) < SMALL_NUMBER)
	{
		// The result of attempting to derive the inverse of a non-invertible 
		// matrix is undefined in OpenGL:
		// http://www.opengl.org/documentation/specs/version1.1/glspec1.1/node26.html
		// However, it is NOT permitted to cause program termination or 
		// corruption! 
//		printf("Non-singular matrix, no inverse!\n");
//		exit(1);
    }
	else
	{
		// scale the adjoint matrix to get the inverse
		
		for (i=0; i<4; i++)
			for(j=0; j<4; j++)
				out.element[i][j] = out.element[i][j] / det;
	}
	
	return out;
	
}//end Matrix4Invert


//========== Matrix4Adjoint() ==================================================
//
// Purpose:		calculate the adjoint of a 4x4 matrix
//
//				Let  a   denote the minor determinant of matrix A obtained by
//					  ij
//
//				deleting the ith row and jth column from A.
//
//								i+j
//				Let  b   = (-1)    a
//					  ij            ji
//
//				The matrix B = (b  ) is the adjoint of A
//								 ij
//
//==============================================================================
void Matrix4Adjoint( Matrix4 *in, Matrix4 *out )
{
    float a1, a2, a3, a4, b1, b2, b3, b4;
    float c1, c2, c3, c4, d1, d2, d3, d4;
	
    /* assign to individual variable names to aid  */
    /* selecting correct values  */
	
	a1 = in->element[0][0]; b1 = in->element[0][1]; 
	c1 = in->element[0][2]; d1 = in->element[0][3];
	
	a2 = in->element[1][0]; b2 = in->element[1][1]; 
	c2 = in->element[1][2]; d2 = in->element[1][3];
	
	a3 = in->element[2][0]; b3 = in->element[2][1];
	c3 = in->element[2][2]; d3 = in->element[2][3];
	
	a4 = in->element[3][0]; b4 = in->element[3][1]; 
	c4 = in->element[3][2]; d4 = in->element[3][3];
	
	
    /* row column labeling reversed since we transpose rows & columns */
	
    out->element[0][0]  =   Matrix3x3Determinant( b2, b3, b4, c2, c3, c4, d2, d3, d4);
    out->element[1][0]  = - Matrix3x3Determinant( a2, a3, a4, c2, c3, c4, d2, d3, d4);
    out->element[2][0]  =   Matrix3x3Determinant( a2, a3, a4, b2, b3, b4, d2, d3, d4);
    out->element[3][0]  = - Matrix3x3Determinant( a2, a3, a4, b2, b3, b4, c2, c3, c4);
	
    out->element[0][1]  = - Matrix3x3Determinant( b1, b3, b4, c1, c3, c4, d1, d3, d4);
    out->element[1][1]  =   Matrix3x3Determinant( a1, a3, a4, c1, c3, c4, d1, d3, d4);
    out->element[2][1]  = - Matrix3x3Determinant( a1, a3, a4, b1, b3, b4, d1, d3, d4);
    out->element[3][1]  =   Matrix3x3Determinant( a1, a3, a4, b1, b3, b4, c1, c3, c4);
	
    out->element[0][2]  =   Matrix3x3Determinant( b1, b2, b4, c1, c2, c4, d1, d2, d4);
    out->element[1][2]  = - Matrix3x3Determinant( a1, a2, a4, c1, c2, c4, d1, d2, d4);
    out->element[2][2]  =   Matrix3x3Determinant( a1, a2, a4, b1, b2, b4, d1, d2, d4);
    out->element[3][2]  = - Matrix3x3Determinant( a1, a2, a4, b1, b2, b4, c1, c2, c4);
	
    out->element[0][3]  = - Matrix3x3Determinant( b1, b2, b3, c1, c2, c3, d1, d2, d3);
    out->element[1][3]  =   Matrix3x3Determinant( a1, a2, a3, c1, c2, c3, d1, d2, d3);
    out->element[2][3]  = - Matrix3x3Determinant( a1, a2, a3, b1, b2, b3, d1, d2, d3);
    out->element[3][3]  =   Matrix3x3Determinant( a1, a2, a3, b1, b2, b3, c1, c2, c3);
	
}//end Matrix4Adjoint


//========== Matrix4x4Determinant() ============================================
//
// Purpose:		calculate the determinant of a 4x4 matrix.
//
// Source:		Graphic Gems II, Spencer W. Thomas
//
//==============================================================================
float Matrix4x4Determinant( Matrix4 *m )
{
    float ans;
    float a1, a2, a3, a4, b1, b2, b3, b4, c1, c2, c3, c4, d1, d2, d3, d4;
	
    /* assign to individual variable names to aid selecting */
	/*  correct elements */
	
	a1 = m->element[0][0]; b1 = m->element[0][1]; 
	c1 = m->element[0][2]; d1 = m->element[0][3];
	
	a2 = m->element[1][0]; b2 = m->element[1][1]; 
	c2 = m->element[1][2]; d2 = m->element[1][3];
	
	a3 = m->element[2][0]; b3 = m->element[2][1]; 
	c3 = m->element[2][2]; d3 = m->element[2][3];
	
	a4 = m->element[3][0]; b4 = m->element[3][1]; 
	c4 = m->element[3][2]; d4 = m->element[3][3];
	
    ans = a1 * Matrix3x3Determinant( b2, b3, b4, c2, c3, c4, d2, d3, d4)
        - b1 * Matrix3x3Determinant( a2, a3, a4, c2, c3, c4, d2, d3, d4)
        + c1 * Matrix3x3Determinant( a2, a3, a4, b2, b3, b4, d2, d3, d4)
        - d1 * Matrix3x3Determinant( a2, a3, a4, b2, b3, b4, c2, c3, c4);
		
    return ans;
	
}//end Matrix4x4Determinant


//========== Matrix4Print() ====================================================
//
// Purpose:		Prints the elements of matrix.
//
//==============================================================================
void Matrix4Print(Matrix4 *matrix)
{
	int counter;
	
	for(counter = 0; counter < 4; counter++)
	{
		printf("[%12.6f %12.6f %12.6f %12.6f]\n",	
								matrix->element[counter][0],
								matrix->element[counter][1],
								matrix->element[counter][2],
								matrix->element[counter][3] );
	}
	printf("\n");
	
}//end Matrix4Print
