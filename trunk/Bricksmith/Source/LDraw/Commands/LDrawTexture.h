//==============================================================================
//
// File:		LDrawTexture.h
//
// Purpose:		Support for projecting images onto LDraw geometry.
//
// Modified:	04/10/2012 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawContainer.h"

@class LDrawVertexes;

@interface LDrawTexture : LDrawContainer
{
	NSArray 		*fallback;
	NSString		*imageName;
	NSString		*glossmapName;
	
	Point3			planePoint1;
	Point3			planePoint2;
	Point3			planePoint3;
	
	LDrawVertexes	*vertexes;
}

// Accessors
- (void) setImageName:(NSString *)newName;

// Utilities
+ (BOOL) lineIsTextureBeginning:(NSString*)line;
+ (BOOL) lineIsTextureFallback:(NSString*)line;
+ (BOOL) lineIsTextureTerminator:(NSString*)line;
- (BOOL) parsePlanarTextureFromLine:(NSString *)line;

@end
