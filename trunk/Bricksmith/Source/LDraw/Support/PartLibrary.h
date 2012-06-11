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
@protocol PartLibraryDelegate;

//The part catalog was regenerated from disk.
// Object is the new catalog. No userInfo.
extern NSString *LDrawPartLibraryDidChangeNotification;


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
	NSMutableDictionary     *optimizedRepresentations;	// access stored vertex objects by part name, then color.
	dispatch_queue_t        catalogAccessQueue;			// serial queue to mutex changes to the part catalog
	NSMutableDictionary     *parsingGroups;				// arrays of dispatch_group_t's which have requested each file currently being parsed
}

// Initialization
+ (PartLibrary *) sharedPartLibrary;

// Accessors
- (NSArray *) allPartNames;
- (NSArray *) categories;
- (NSArray *) favoritePartNames;
- (NSArray *) partNamesInCategory:(NSString *)category;

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
- (void) loadModelForName:(NSString *)name inGroup:(dispatch_group_t)parentGroup;
- (LDrawModel *) modelForName:(NSString *) partName;
- (LDrawModel *) modelForPart:(LDrawPart *) part;
- (LDrawModel *) modelFromNeighboringFileForPart:(LDrawPart *)part;
- (LDrawDirective *) optimizedDrawableForPart:(LDrawPart *) part color:(LDrawColor *)color;
// Utilites
- (void) addPartsInFolder:(NSString *)folderPath
				toCatalog:(NSMutableDictionary *)catalog
			underCategory:(NSString *)category
			   namePrefix:(NSString *)namePrefix;
- (NSString *)categoryForDescription:(NSString *)modelDescription;
- (NSString *)categoryForPart:(LDrawPart *)part;
- (NSString *)descriptionForPart:(LDrawPart *)part;
- (NSString *)descriptionForPartName:(NSString *)name;
- (NSString *) descriptionForFilePath:(NSString *)filepath;
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

