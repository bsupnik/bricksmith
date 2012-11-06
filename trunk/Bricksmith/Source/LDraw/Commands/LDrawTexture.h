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
	NSString		*imageDisplayName;
	NSString		*imageReferenceName;
	NSString		*glossmapName;
	
	Point3			planePoint1;
	Point3			planePoint2;
	Point3			planePoint3;
	
	LDrawVertexes	*vertexes;
	NSArray			*dragHandles;
	Box3			cachedBounds;		// cached bounds of the enclosed directives
	
	GLuint			textureTag;
}

// Accessors
- (NSString *) glossmapName;
- (NSString *) imageDisplayName;
- (NSString *) imageReferenceName;

- (void) setGlossmapName:(NSString *)newName;
- (void) setImageDisplayName:(NSString *)newName;
- (void) setImageDisplayName:(NSString *)newName parse:(BOOL)shouldParse inGroup:(dispatch_group_t)parentGroup;

// Utilities
+ (BOOL) lineIsTextureBeginning:(NSString*)line;
+ (BOOL) lineIsTextureFallback:(NSString*)line;
+ (BOOL) lineIsTextureTerminator:(NSString*)line;
- (BOOL) parsePlanarTextureFromLine:(NSString *)line parentGroup:(dispatch_group_t)parentGroup;

@end
