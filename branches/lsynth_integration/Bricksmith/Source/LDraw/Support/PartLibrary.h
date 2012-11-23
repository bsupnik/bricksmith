//==============================================================================
//
// File:		PartLibrary.m
//
// Purpose:		This is the centralized repository for obtaining information 
//				about the contents of the LDraw folder.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "ColorLibrary.h"

@class LDrawDirective;
@class LDrawModel;
@class LDrawPart;
@class LDrawTexture;
@protocol PartLibraryDelegate;

//The part catalog was regenerated from disk.
// Object is the new catalog. No userInfo.
extern NSString *LDrawPartLibraryDidChangeNotification;

// Catalog info keys
extern NSString *PART_NUMBER_KEY;
extern NSString *PART_NAME_KEY;
extern NSString *PART_CATEGORY_KEY;
extern NSString *PART_KEYWORDS_KEY;

extern NSString	*CategoryNameKey;
extern NSString	*CategoryDisplayNameKey;
extern NSString	*CategoryChildrenKey;

extern NSString	*Category_All;
extern NSString	*Category_Favorites;
extern NSString	*Category_Alias;
extern NSString *Category_Moved;
extern NSString	*Category_Primitives;
extern NSString	*Category_Subparts;


////////////////////////////////////////////////////////////////////////////////
//
// class PartLibrary
//
////////////////////////////////////////////////////////////////////////////////
@interface PartLibrary : NSObject
{
	id<PartLibraryDelegate> delegate;
	NSDictionary            *partCatalog;
	NSMutableArray          *favorites;					// parts names in the "Favorites" pseduocategory
	NSMutableDictionary     *loadedFiles;				// list of LDrawFiles which have been read off disk.
	NSMutableDictionary		*loadedImages;
	NSMutableDictionary		*optimizedTextures;			// GLuint texture tags
	NSMutableDictionary     *optimizedRepresentations;	// access stored vertex objects by part name, then color.
	dispatch_queue_t        catalogAccessQueue;			// serial queue to mutex changes to the part catalog
	NSMutableDictionary     *parsingGroups;				// arrays of dispatch_group_t's which have requested each file currently being parsed
}

// Initialization
+ (PartLibrary *) sharedPartLibrary;

// Accessors
- (NSArray *) allPartCatalogRecords;
- (NSArray *) categories;
- (NSArray *) categoryHierarchy;
- (NSString *) displayNameForCategory:(NSString *)categoryName;
- (NSArray *) favoritePartNames;
- (NSArray *) favoritePartCatalogRecords;
- (NSArray *) partCatalogRecordsInCategory:(NSString *)category;
- (NSString *) categoryForPartName:(NSString *)partName;

- (void) setDelegate:(id<PartLibraryDelegate>)delegateIn;
- (void) setFavorites:(NSArray *)favoritesIn;
- (void) setPartCatalog:(NSDictionary *)newCatalog;

// Actions
- (BOOL) load;
- (BOOL) reloadParts;

// Favorites
- (void) addPartNameToFavorites:(NSString *)partName;
- (void) removePartNameFromFavorites:(NSString *)partName;
- (void) saveFavoritesToUserDefaults;

// Finding Parts
- (void) loadImageForName:(NSString *)imageName inGroup:(dispatch_group_t)parentGroup;
- (void) loadModelForName:(NSString *)name inGroup:(dispatch_group_t)parentGroup;
- (CGImageRef) imageForTextureName:(NSString *)imageName;
- (CGImageRef) imageForTexture:(LDrawTexture *)texture;
- (CGImageRef) imageFromNeighboringFileForTexture:(LDrawTexture *)texture;
- (LDrawModel *) modelForName:(NSString *) partName;
- (LDrawModel *) modelForName_threadSafe:(NSString *) partName;

- (LDrawDirective *) optimizedDrawableForPart:(LDrawPart *) part color:(LDrawColor *)color;
- (GLuint) textureTagForTexture:(LDrawTexture*)texture;

// Utilites
- (void) addPartsInFolder:(NSString *)folderPath
				toCatalog:(NSMutableDictionary *)catalog
			underCategory:(NSString *)category
			   namePrefix:(NSString *)namePrefix;
- (NSString *)categoryForDescription:(NSString *)modelDescription;
- (NSString *)descriptionForPart:(LDrawPart *)part;
- (NSString *)descriptionForPartName:(NSString *)name;
- (NSMutableDictionary *) catalogInfoForFileAtPath:(NSString *)filepath;
- (CGImageRef) readImageAtPath:(NSString *)imagePath
				asynchronously:(BOOL)asynchronous
			 completionHandler:(void (^)(CGImageRef))completionBlock;
- (LDrawModel *) readModelAtPath:(NSString *)partPath
				  asynchronously:(BOOL)asynchronous
			   completionHandler:(void (^)(LDrawModel *))completionBlock;

@end


////////////////////////////////////////////////////////////////////////////////
//
// delegate PartLibraryReloadPartsDelegate
// (all methods are required)
//
////////////////////////////////////////////////////////////////////////////////
@protocol PartLibraryDelegate

- (void) partLibrary:(PartLibrary *)partLibrary didChangeFavorites:(NSArray *)newFavorites;
- (void) partLibrary:(PartLibrary *)partLibrary maximumPartCountToLoad:(NSUInteger)maxPartCount;
- (void) partLibraryIncrementLoadProgressCount:(PartLibrary *)partLibrary;

@end

