//==============================================================================
//
// File:		LDrawPaths.h
//
// Purpose:		Looks up LDraw-related file locations.
//
// Modified:	05/03/2011 Allen Smith. Creation Date.
//
//==============================================================================
#import <Foundation/Foundation.h>

typedef enum
{
	LDrawOfficial	= 0,
	LDrawUnofficial	= 1
} LDrawDomain;


////////////////////////////////////////////////////////////////////////////////
@interface LDrawPaths : NSObject
{
	NSString	*preferredLDrawPath;
}

+ (LDrawPaths *) sharedPaths;

// Accessors
- (NSString *) preferredLDrawPath;
- (void) setPreferredLDrawPath:(NSString *)pathIn;

// Standard paths
- (NSString *) partsPathForDomain:(LDrawDomain)domain;
- (NSString *) primitivesPathForDomain:(LDrawDomain)domain;
- (NSString *) primitives48PathForDomain:(LDrawDomain)domain;
- (NSString *) ldconfigPath;
- (NSString *) MLCadIniPath;
- (NSString *) partCatalogPath;
- (NSString *) subpartsPathForDomain:(LDrawDomain)domain;

// Utilities
- (NSString *) findLDrawPath;
- (NSString *) pathForPartName:(NSString *)partName;
- (NSString *) pathForTextureName:(NSString *)imageName;
- (BOOL) validateLDrawFolder:(NSString *)folderPath;

@end
