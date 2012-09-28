//==============================================================================
//
// File:		PartLibrary.m
//
// Purpose:		This is the centralized repository for obtaining information 
//				about the contents of the LDraw folder. The part library is 
//				first created by scanning the LDraw folder and collecting all 
//				the part names, categories, and drawing instructions for each 
//				part. This information is then saved into an XML file and 
//				retrieved each time the program is relaunched. During runtime, 
//				other objects query the part library to draw and display 
//				information about parts.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "PartLibrary.h"

#import "LDrawFile.h"
#import "LDrawKeywords.h"
#import "LDrawModel.h"
#import "LDrawPart.h"
#import "LDrawPathNames.h"
#import "LDrawPaths.h"
#import "LDrawStep.h"
#import "LDrawTexture.h"
#import "LDrawUtilities.h"
#import "LDrawVertexes.h"
#import "StringCategory.h"


//The part catalog was regenerated from disk.
// Object is the new catalog. No userInfo.
NSString *LDrawPartLibraryDidChangeNotification = @"LDrawPartLibraryDidChangeNotification";


// The parts list file is stored at LDraw/PARTS_LIST_NAME.
// It contains a dictionary of parts. Each element in the dictionary 
// is an array of parts for a category; the key under which the array 
// is stored is the category name.
//
//The part catalog is a dictionary of parts filed by Category name.
#define PARTS_CATALOG_KEY						@"Part Catalog"
	//subdictionary keys.
NSString	*PART_NUMBER_KEY	= @"Part Number";
NSString	*PART_NAME_KEY		= @"Part Name";
NSString	*PART_CATEGORY_KEY	= @"Category";
NSString	*PART_KEYWORDS_KEY	= @"Keywords";

//Raw dictionary containing each part filed by number.
#define PARTS_LIST_KEY							@"Part List"
	//subdictionary keys.
	//PART_NUMBER_KEY							(defined above)
	//PART_NAME_KEY								(defined above)

NSString	*VERSION_KEY				= @"Version";
NSString	*COMPATIBILITY_VERSION_KEY	= @"CompatibilityVersion";

NSString	*CategoryNameKey			= @"Name";
NSString	*CategoryDisplayNameKey 	= @"DisplayName";
NSString	*CategoryChildrenKey		= @"Children";

NSString	*Category_All				= @"AllCategories";
NSString	*Category_Favorites 		= @"Favorites";
NSString	*Category_Alias 			= @"Alias";
NSString	*Category_Moved 			= @"Moved";
NSString	*Category_Primitives		= @"Primitives";
NSString	*Category_Subparts			= @"Subparts";

@implementation PartLibrary

static PartLibrary *SharedPartLibrary = nil;

//---------- sharedPartLibrary ---------------------------------------[static]--
//
// Purpose:		Returns the part libary, which contains the part catalog, which 
//				is read in from the file LDRAW_PATH_KEY/PART_CATALOG_NAME when 
//				the application launches.
//				This is a rather big XML file, so it behooves us to read it 
//				once then save it in memory.
//
//------------------------------------------------------------------------------
+ (PartLibrary *) sharedPartLibrary
{
	if(SharedPartLibrary == nil)
	{
		SharedPartLibrary = [[PartLibrary alloc] init];
	}
	
	return SharedPartLibrary;
	
}//end sharedPartLibrary


//========== init ==============================================================
//
// Purpose:		Creates a part library with no parts loaded.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	loadedFiles                 = [[NSMutableDictionary dictionaryWithCapacity:400] retain];
	loadedImages				= [[NSMutableDictionary alloc] init];
	optimizedRepresentations    = [[NSMutableDictionary dictionaryWithCapacity:400] retain];
	optimizedTextures			= [[NSMutableDictionary alloc] init];
	
	favorites                   = [[NSMutableArray alloc] init];
	
#if USE_BLOCKS
	catalogAccessQueue          = dispatch_queue_create("com.AllenSmith.Bricksmith.CatalogAccess", NULL);
#endif
	parsingGroups               = [[NSMutableDictionary alloc] init];
	
	[self setPartCatalog:[NSDictionary dictionary]];
	
	return self;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== allPartCatalogRecords =============================================
//
// Purpose:		Returns all the part numbers in the library.
//
//==============================================================================
- (NSArray *) allPartCatalogRecords
{
	NSDictionary	*partList	= [self->partCatalog objectForKey:PARTS_LIST_KEY];
	
	// all the reference numbers for parts.
	return [partList allValues];
	
}//end allPartCatalogRecords


//========== categories ========================================================
//
// Purpose:		Returns all the categories in the library, sorted in no 
//				particular order. 
//
//==============================================================================
- (NSArray *) categories
{
	return [[self->partCatalog objectForKey:PARTS_CATALOG_KEY] allKeys];
	
}//end categories


//========== categoryHierarchy =================================================
//
// Purpose:		Returns an outline-conducive list of all available categories.
//
//==============================================================================
- (NSArray *) categoryHierarchy
{
	NSMutableArray  *fullCategoryList   = [NSMutableArray array];
	NSMutableArray	*libraryItems		= [NSMutableArray array];
	NSMutableArray	*categoryItems		= [NSMutableArray array];
	NSMutableArray	*otherItems			= [NSMutableArray array];
	
	// Library group
	[libraryItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_All,										CategoryNameKey,
							 [self displayNameForCategory:Category_All],		CategoryDisplayNameKey,
							 nil]];
	
	[libraryItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_Favorites,								CategoryNameKey,
							 [self displayNameForCategory:Category_Favorites],	CategoryDisplayNameKey,
							 nil]];
							 
	[fullCategoryList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								 @"Library",										CategoryNameKey,
								 NSLocalizedString(@"CategoryGroup_Library",nil),	CategoryDisplayNameKey,
								 libraryItems,										CategoryChildrenKey,
								 nil]];
	
	// Main categories
	NSArray *categories = [[self categories] sortedArrayUsingSelector:@selector(compare:)];
	for(NSString *name in categories)
	{
		if(		[name isEqualToString:Category_Alias] == NO
		   &&	[name isEqualToString:Category_Moved] == NO
		   &&	[name isEqualToString:Category_Primitives] == NO
		   &&	[name isEqualToString:Category_Subparts] == NO )
		{
			[categoryItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									  name,									CategoryNameKey,
									  [self displayNameForCategory:name],	CategoryDisplayNameKey,
									  nil]];
		}
	}
	[fullCategoryList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								 @"Part Categories",										CategoryNameKey,
								 NSLocalizedString(@"CategoryGroup_PartCategories",nil),	CategoryDisplayNameKey,
								 categoryItems,												CategoryChildrenKey,
								 nil]];
	
	// Other categories
	
	[otherItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_Alias,									CategoryNameKey,
							 [self displayNameForCategory:Category_Alias],		CategoryDisplayNameKey,
							 nil]];
	
	[otherItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_Moved,									CategoryNameKey,
							 [self displayNameForCategory:Category_Moved],		CategoryDisplayNameKey,
							 nil]];
	
	[otherItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_Primitives,								CategoryNameKey,
							 [self displayNameForCategory:Category_Primitives],	CategoryDisplayNameKey,
							 nil]];
	
	[otherItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 Category_Subparts,									CategoryNameKey,
							 [self displayNameForCategory:Category_Subparts],	CategoryDisplayNameKey,
							 nil]];
	
	[fullCategoryList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								 @"Other",										CategoryNameKey,
								 NSLocalizedString(@"CategoryGroup_Other",nil),	CategoryDisplayNameKey,
								 otherItems,									CategoryChildrenKey,
								 nil]];
								 
	return fullCategoryList;
	
}//end categoryHierarchy


//========== categoryForPartName: ==============================================
//
// Purpose:		Returns the part's category.
//
//==============================================================================
- (NSString *) categoryForPartName:(NSString *)partName
{
	NSDictionary	*partList		= [self->partCatalog objectForKey:PARTS_LIST_KEY];
	NSDictionary	*catalogInfo	= [partList objectForKey:partName];
	NSString		*category		= [catalogInfo objectForKey:PART_CATEGORY_KEY];
	
	return category;
}


//========== favoritePartNames =================================================
//
// Purpose:		Returns all the part names the user has bookmarked as his 
//				favorites. 
//
//==============================================================================
- (NSArray *) favoritePartNames
{
	return self->favorites;
	
}//end favoritePartNames


//========== displayNameForCategory: ===========================================
//
// Purpose:		Returns the human-friendly category name
//
//==============================================================================
- (NSString *) displayNameForCategory:(NSString *)categoryName
{
	NSString *displayName = nil;
	
	if([categoryName isEqualToString:Category_All])
	{
		displayName = NSLocalizedString(@"AllCategories", nil);
	}
	else if([categoryName isEqualToString:Category_Favorites])
	{
		displayName = NSLocalizedString(@"FavoritesCategory", nil);
	}
	else
	{
		displayName = NSLocalizedString(categoryName, nil);
	}
	return displayName;
}


//========== favoritePartCatalogRecords ========================================
//
// Purpose:		Returns all the part info records the user has bookmarked as his 
//				favorites. 
//
//==============================================================================
- (NSArray *) favoritePartCatalogRecords
{
	NSDictionary	*partList		= [self->partCatalog objectForKey:PARTS_LIST_KEY];
	NSMutableArray	*parts			= [NSMutableArray array];
	NSDictionary	*partInfo		= nil;
	
	for(NSString *partName in self->favorites)
	{
		partInfo = [partList objectForKey:partName];
		
		if(partInfo)
			[parts addObject:partInfo];
	}
	
	return parts;
	
}//end favoritePartNames


//========== partCatalogRecordsInCategory: =====================================
//
// Purpose:		Returns all the parts in the given category. Returns nil if the 
//				category doesn't exist. 
//
//==============================================================================
- (NSArray *) partCatalogRecordsInCategory:(NSString *)categoryName
{
	NSArray	*parts		= nil;
	
	if([categoryName isEqualToString:Category_All])
	{
		// Retrieve all parts. We can do this by getting the entire (unsorted) 
		// contents of PARTS_LIST_KEY in the partCatalog, which is actually 
		// a dictionary of all parts.
		parts = [self allPartCatalogRecords];
		
	}
	else if([categoryName isEqualToString:Category_Favorites])
	{
		parts = [self favoritePartCatalogRecords];
	}
	else
	{
		NSArray 		*category			= [[partCatalog objectForKey:PARTS_CATALOG_KEY] objectForKey:categoryName];
		NSDictionary	*partList			= [self->partCatalog objectForKey:PARTS_LIST_KEY];
		NSMutableArray	*partsInCategory	= [NSMutableArray array];
		NSString		*partName			= nil;
		NSDictionary	*partInfo			= nil;

		for(NSDictionary* categoryRecord in category)
		{
			partName = [categoryRecord objectForKey:PART_NUMBER_KEY];
			partInfo = [partList objectForKey:partName];
			
			if(partInfo)
				[partsInCategory addObject:partInfo];
		}
		
		parts = partsInCategory;
	}
	
	return parts;

}//end partCatalogRecordsInCategory:


#pragma mark -

//========== setDelegate: ======================================================
//
// Purpose:		Set the object responsible for receiving important notifications 
//				from us. 
//
//==============================================================================
- (void) setDelegate:(id<PartLibraryDelegate>)delegateIn
{
	self->delegate = delegateIn;
}


//========== setFavorites: =====================================================
//
// Purpose:		Sets the parts which should appear in the Favorites category. 
//				This list should have been saved in preferences and loaded by 
//				the part library controller. 
//
//==============================================================================
- (void) setFavorites:(NSArray *)favoritesIn
{
	[self->favorites removeAllObjects];
	[self->favorites addObjectsFromArray:favoritesIn];
}


//========== setPartCatalog ====================================================
//
// Purpose:		Saves the local instance of the part catalog, which should be 
//				the only copy of it in the program. Use +setSharedPartCatalog to 
//				update it outside this class.
//
// Notes:		The Part Catalog is structured as follows:
//
//				partCatalog
//				|
//				|--> PARTS_CATALOG_KEY <NSDictionary>
//				|		|
//				|		Keys  are category names, e.g., "Brick"
//				|		<NSArray>
//				|			|
//				|			<NSDictionary>
//				|				|--> PART_NUMBER_KEY <NSString> (e.g., "3001.dat")
//				|
//				|--> PARTS_LIST_KEY <NSDictionary>
//						|
//						Keys are part reference numbers, e.g., "3001.dat"
//						<NSDictionary>
//							|--> PART_NUMBER_KEY
//							|--> PART_NAME_KEY
//
//				This data structure is PRIVATE. There is no get accessor. Query 
//				this object for its part lists and build your own records.
//
//==============================================================================
- (void) setPartCatalog:(NSDictionary *)newCatalog
{
	[newCatalog retain];
	[partCatalog release];
	
	partCatalog = newCatalog;
	
	//Inform any open parts browsers of the change.
	[[NSNotificationCenter defaultCenter] 
			postNotificationName: LDrawPartLibraryDidChangeNotification
						  object: self ];
	
}//end setPartCatalog


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== load ==============================================================
//
// Purpose:		Loads the catalog from the part list stashed in the LDraw 
//				folder. 
//
// Returns:		NO if no part list exists. (You need to call -reloadParts: in 
//				PartLibraryController then.) 
//
//==============================================================================
- (BOOL) load
{
	NSFileManager   *fileManager    = [[[NSFileManager alloc] init] autorelease];
	NSString        *catalogPath    = [[LDrawPaths sharedPaths] partCatalogPath];
	BOOL            partsListExists = NO;
	NSString		*version		= nil;
	NSDictionary    *newCatalog     = nil;
	
	// Do we have an LDraw folder?
	if(catalogPath != nil)
	{
		if([fileManager fileExistsAtPath:catalogPath])
			partsListExists = YES;
	}
	
	// Do we have a part list already? 
	if(partsListExists == YES)
	{
		newCatalog	= [NSDictionary dictionaryWithContentsOfFile:catalogPath];
		version 	= [newCatalog objectForKey:VERSION_KEY];
		
		if(version)
		{
			[self setPartCatalog:newCatalog];
		}
		else
		{
			// Older part catalogs don't have enough info in them
			partsListExists = NO;
		}

	}
	
	return partsListExists;

}//end load


//========== reloadParts: ======================================================
//
// Purpose:		Scans the contents of the LDraw/ folder and produces a 
//				Mac-friendly index of parts.
//
//				Is it fast? No. Is it easy to code? Yes.
//
//				Someday in the rosy future, this method should be recoded to 
//				simply traverse the directory tree and deal with subfolders on 
//				the fly. But that's not how it is now. Instead, I'm doing it 
//				all manually. Folders searched are:
//
//				LDraw/p/
//				LDraw/p/48/
//
//				LDraw/parts/
//				LDraw/parts/s/
//
//				LDraw/Unofficial/p/
//				LDraw/Unofficial/p/48/
//				LDraw/Unofficial/parts/
//				LDraw/Unofficial/parts/s/
//
//				It is important that the part name added to the library bear 
//				the correct reference style. For LDraw/p/ and LDraw/parts/, it 
//				is simply the filename (in lowercase). But for subdirectories, 
//				the filename must be prefixed with the subdirectory in DOS 
//				format, i.e., "s\file.dat" or "48\file.dat".
//
//==============================================================================
- (BOOL) reloadParts
{
	NSFileManager		*fileManager		= [[[NSFileManager alloc] init] autorelease];
	NSString			*ldrawPath			= [[LDrawPaths sharedPaths] preferredLDrawPath];
	
	//make sure the LDraw folder is still valid; otherwise, why bother doing anything?
	if([[LDrawPaths sharedPaths] validateLDrawFolder:ldrawPath] == NO)
		return NO;
	
	//assemble all the pathnames to be searched.
	NSString            *primitivesPath             = [[LDrawPaths sharedPaths] primitivesPathForDomain:LDrawOfficial];
	NSString            *primitives48Path           = [[LDrawPaths sharedPaths] primitives48PathForDomain:LDrawOfficial];
	NSString            *partsPath                  = [[LDrawPaths sharedPaths] partsPathForDomain:LDrawOfficial];
	NSString            *subpartsPath               = [[LDrawPaths sharedPaths] subpartsPathForDomain:LDrawOfficial];
	
	//search unofficial directories as well.
	NSString            *unofficialPrimitivesPath   = [[LDrawPaths sharedPaths] primitivesPathForDomain:LDrawUnofficial];
	NSString            *unofficialPrimitives48Path = [[LDrawPaths sharedPaths] primitives48PathForDomain:LDrawUnofficial];
	NSString            *unofficialPartsPath        = [[LDrawPaths sharedPaths] partsPathForDomain:LDrawUnofficial];
	NSString            *unofficialSubpartsPath     = [[LDrawPaths sharedPaths] subpartsPathForDomain:LDrawUnofficial];
	
	NSString            *partCatalogPath            = [[LDrawPaths sharedPaths] partCatalogPath];
	NSMutableDictionary *newPartCatalog             = [NSMutableDictionary dictionary];
	
	// Start the progress bar so that we know what's happening.
	NSUInteger			partCount					=		[[fileManager contentsOfDirectoryAtPath:primitivesPath				error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:primitives48Path			error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:partsPath					error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:subpartsPath				error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:unofficialPrimitivesPath	error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:unofficialPrimitives48Path	error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:unofficialPartsPath			error:NULL] count]
														+	[[fileManager contentsOfDirectoryAtPath:unofficialSubpartsPath		error:NULL] count];
	[delegate partLibrary:self maximumPartCountToLoad:partCount];
	
	
	// Create the new part catalog. We will then fill it with folder contents.
	[newPartCatalog setObject:[NSMutableDictionary dictionary] forKey:PARTS_CATALOG_KEY];
	[newPartCatalog setObject:[NSMutableDictionary dictionary] forKey:PARTS_LIST_KEY];
	
	
	// Scan for each part folder.
	[self addPartsInFolder:primitivesPath
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Primitives, nil) //override all internal categories
				namePrefix:nil ];
	
	[self addPartsInFolder:primitives48Path
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Primitives, nil) //override all internal categories
				namePrefix:[NSString stringWithFormat:@"%@\\", PRIMITIVES_48_DIRECTORY_NAME] ];
	
	[self addPartsInFolder:partsPath
				 toCatalog:newPartCatalog
			 underCategory:nil //pick up category names defined by parts
				namePrefix:nil ];
	
	[self addPartsInFolder:subpartsPath
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Subparts, nil)
				namePrefix:[NSString stringWithFormat:@"%@\\", SUBPARTS_DIRECTORY_NAME] ]; //prefix subpart numbers with the DOS path "s\"; that's just how it is. Yuck!
	
	
	//Scan unofficial part folders.
	[self addPartsInFolder:unofficialPrimitivesPath
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Primitives, nil) //groups unofficial primitives with official primitives
			    namePrefix:nil ]; //a directory deeper, but no DOS path separators to manage
	
	[self addPartsInFolder:unofficialPrimitives48Path
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Primitives, nil)
				namePrefix:[NSString stringWithFormat:@"%@\\", PRIMITIVES_48_DIRECTORY_NAME] ];
	
	[self addPartsInFolder:unofficialPartsPath
				 toCatalog:newPartCatalog
			 underCategory:nil
				namePrefix:nil ];
	
	[self addPartsInFolder:unofficialSubpartsPath
				 toCatalog:newPartCatalog
			 underCategory:NSLocalizedString(Category_Subparts, nil) //groups unofficial subparts with official subparts
				namePrefix:[NSString stringWithFormat:@"%@\\", SUBPARTS_DIRECTORY_NAME] ];
	
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[newPartCatalog setObject:version forKey:VERSION_KEY];
	[newPartCatalog setObject:@"1.0"  forKey:COMPATIBILITY_VERSION_KEY];
	
	//Save the part catalog out for future reference.
	[newPartCatalog writeToFile:partCatalogPath atomically:YES];
	[self setPartCatalog:newPartCatalog];
	
	// We succeeded in loading the parts!
	return YES;
	
}//end reloadParts:


#pragma mark -
#pragma mark FAVORITES
#pragma mark -

//========== addPartNameToFavorites: ===========================================
//
// Purpose:		Adds the given part name to the "Favorites" category.
//
//==============================================================================
- (void) addPartNameToFavorites:(NSString *)partName
{
	[self->favorites addObject:partName];
	[self saveFavoritesToUserDefaults];
	
	//Inform any open parts browsers of the change.
	[[NSNotificationCenter defaultCenter] 
			postNotificationName: LDrawPartLibraryDidChangeNotification
						  object: self ];
	
}//end addPartNameToFavorites:


//========== removePartNameFromFavorites: ======================================
//
// Purpose:		Removes the given part name to the "Favorites" category.
//
//==============================================================================
- (void) removePartNameFromFavorites:(NSString *)partName
{
	[self->favorites removeObject:partName];
	[self saveFavoritesToUserDefaults];
	
	//Inform any open parts browsers of the change.
	[[NSNotificationCenter defaultCenter] 
			postNotificationName: LDrawPartLibraryDidChangeNotification
						  object: self ];
	
}//end removePartNameFromFavorites:


//========== saveFavoritesToUserDefaults =======================================
//
// Purpose:		Writes the favorite parts list to preferences.
//
//==============================================================================
- (void) saveFavoritesToUserDefaults
{
	[self->delegate partLibrary:self didChangeFavorites:(self->favorites)];
	
}//end saveFavoritesToUserDefaults


#pragma mark -
#pragma mark FINDING PARTS
#pragma mark -

//========== loadImageForName:inGroup: =========================================
//
// Purpose:		This is a thread-safe method which causes the texture image of 
//				the given name to be loaded out of the LDraw folder. 
//
//==============================================================================
- (void) loadImageForName:(NSString *)imageName
				  inGroup:(dispatch_group_t)parentGroup
{
	// Determine if the model needs to be parsed.
	// Dispatch to a serial queue to effectively mutex the query
#if USE_BLOCKS
	dispatch_group_async(parentGroup, self->catalogAccessQueue,
	^{
		NSMutableArray  *requestingGroups   = nil;
#endif
		CGImageRef      image              = NULL;
		BOOL            alreadyParsing      = NO;	// another thread is already parsing partName
	
		// Already been parsed?
		image = (CGImageRef)[self->loadedImages objectForKey:imageName];
		if(image == nil)
		{
#if USE_BLOCKS
			// Is it being parsed? If so, all we need to do is wait for whoever 
			// is parsing it to finish. 
			requestingGroups    = [self->parsingGroups objectForKey:imageName];
			alreadyParsing      = (requestingGroups != nil);
			
			if(alreadyParsing == NO)
			{
				// Start a registry for all the dispatch groups which attempt to 
				// load the same model. When parsing is complete, they will all 
				// be signaled. 
				requestingGroups = [[NSMutableArray alloc] init];
				[self->parsingGroups setObject:requestingGroups forKey:imageName];
				[requestingGroups release];
			}
				
			// Register the calling group as having also requested a parse 
			// for this file. This ensures the calling group cannot complete 
			// until the parse is complete on whatever thread is actually 
			// doing it. 
			dispatch_group_enter(parentGroup);
			[requestingGroups addObject:[NSValue valueWithPointer:parentGroup]];
#endif
			
			// Nobody has started parsing it yet, so we win! Parse from disk.
			if(alreadyParsing == NO)
			{
#if USE_BLOCKS
				dispatch_group_async(parentGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
				^{
#endif
					NSString    *imagePath   = [[LDrawPaths sharedPaths] pathForTextureName:imageName];
						
#if USE_BLOCKS //------------------------------------------------------
					[self readImageAtPath:imagePath asynchronously:YES completionHandler:^(CGImageRef image)
					{
						if(image) CFRetain(image);
						
						// Register new image in the library (serial queue "mutex" protected)
						dispatch_group_async(parentGroup, self->catalogAccessQueue,
						^{
							if(image != nil)
							{
								[self->loadedImages setObject:(id)image forKey:imageName];
							}
							
							// Notify waiting threads we are finished parsing this part.
							for(NSValue *waitingGroupPtr in requestingGroups)
							{
								dispatch_group_t waitingGroup = [waitingGroupPtr pointerValue];
								dispatch_group_leave(waitingGroup);
							}
							[self->parsingGroups removeObjectForKey:imageName];
							
							if(image) CFRelease(image);
						});
					}];
#else //------------------------------------------------------------------------
					// **** Non-multithreaded fallback code ****
					image = (CGImageRef)[self readImageAtPath:imagePath asynchronously:NO completionHandler:NULL];
					if(image != nil)
					{
						[self->loadedImages setObject:(id)image forKey:imageName];
					}
#endif //-----------------------------------------------------------------------
#if USE_BLOCKS
				});
#endif
			}
		}
#if USE_BLOCKS
	});
#endif
	
}//end loadImageForName:


//========== loadModelForName:inGroup: =========================================
//
// Purpose:		This is a thread-safe method which causes the model of the given 
//				name to be loaded out of the LDraw folder. 
//
//==============================================================================
- (void) loadModelForName:(NSString *)partName
				  inGroup:(dispatch_group_t)parentGroup
{
	// Determine if the model needs to be parsed.
	// Dispatch to a serial queue to effectively mutex the query
#if USE_BLOCKS
	dispatch_group_async(parentGroup, self->catalogAccessQueue,
	^{
		NSMutableArray  *requestingGroups   = nil;
#endif
		LDrawModel      *model              = nil;
		BOOL            alreadyParsing      = NO;	// another thread is already parsing partName
	
		// Already been parsed?
		model = [self->loadedFiles objectForKey:partName];
		if(model == nil)
		{
#if USE_BLOCKS
			// Is it being parsed? If so, all we need to do is wait for whoever 
			// is parsing it to finish. 
			requestingGroups    = [self->parsingGroups objectForKey:partName];
			alreadyParsing      = (requestingGroups != nil);
			
			if(alreadyParsing == NO)
			{
				// Start a registry for all the dispatch groups which attempt to 
				// load the same model. When parsing is complete, they will all 
				// be signaled. 
				requestingGroups = [[NSMutableArray alloc] init];
				[self->parsingGroups setObject:requestingGroups forKey:partName];
				[requestingGroups release];
			}
				
			// Register the calling group as having also requested a parse 
			// for this file. This ensures the calling group cannot complete 
			// until the parse is complete on whatever thread is actually 
			// doing it. 
			dispatch_group_enter(parentGroup);
			[requestingGroups addObject:[NSValue valueWithPointer:parentGroup]];
#endif
			
			// Nobody has started parsing it yet, so we win! Parse from disk.
			if(alreadyParsing == NO)
			{
#if USE_BLOCKS
				dispatch_group_async(parentGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
				^{
#endif
					NSString    *partPath   = [[LDrawPaths sharedPaths] pathForPartName:partName];
						
#if USE_BLOCKS //------------------------------------------------------
					[self readModelAtPath:partPath asynchronously:YES completionHandler:^(LDrawModel *model)
					{
						// Register new model in the library (serial queue "mutex" protected)
						dispatch_group_async(parentGroup, self->catalogAccessQueue,
						^{
							if(model != nil)
							{
								[self->loadedFiles setObject:model forKey:partName];
							}
							
							// Notify waiting threads we are finished parsing this part.
							for(NSValue *waitingGroupPtr in requestingGroups)
							{
								dispatch_group_t waitingGroup = [waitingGroupPtr pointerValue];
								dispatch_group_leave(waitingGroup);
							}
							[self->parsingGroups removeObjectForKey:partName];
						});
					}];
#else //------------------------------------------------------------------------
					// **** Non-multithreaded fallback code ****
					model = [self readModelAtPath:partPath asynchronously:NO completionHandler:NULL];
					if(model != nil)
					{
						[self->loadedFiles setObject:model forKey:partName];
					}
#endif //-----------------------------------------------------------------------
#if USE_BLOCKS
				});
#endif
			}
		}
#if USE_BLOCKS
	});
#endif
	
}//end loadModelForName:


//========== imageForTextureName: ==============================================
//
// Purpose:		Returns an image from our library cache.
//
//==============================================================================
- (CGImageRef) imageForTextureName:(NSString *)imageName
{
	CGImageRef	image		= NULL;
	NSString	*imagePath	= nil;
	
	// Has it already been parsed?
	image = (CGImageRef)[self->loadedImages objectForKey:imageName];
	
	if(image == nil)
	{
		// Well, this means we have to try getting it off the disk!
		imagePath	= [[LDrawPaths sharedPaths] pathForTextureName:imageName];
		image		= [self readImageAtPath:imagePath asynchronously:NO completionHandler:NULL];
		
		if(image != nil)
			[self->loadedImages setObject:(id)image forKey:imageName];
	}
	
	return image;
	
}


//========== imageForTexture: ==================================================
//
// Purpose:		Returns the image specified by the texture object.
//
//==============================================================================
- (CGImageRef) imageForTexture:(LDrawTexture *)texture
{
	NSString	*imageName	= [texture imageReferenceName];
	CGImageRef	image		= NULL;
	
	// Try to get a live link if we have parsed this part off disk already.
	image = [self imageForTextureName:imageName];
	
	if(image == nil) {
		//we're grasping at straws. See if this is a reference to an external 
		// file in the same folder.
		image = [self imageFromNeighboringFileForTexture:texture];
	}
	
	return image;
	
}//end imageForTexture:


//========== imageFromNeighboringFileForTexture: ===============================
//
// Purpose:		Attempts to resolve the part's name reference against a file 
//				located in the same parent folder as the file in which the part 
//				is contained.
//
//				This should be a method of last resort, after searching the part 
//				library and looking for an MPD reference.
//
// Note:		Once a model is found under this method, we READ AND CACHE IT.
//				You must RESTART Bricksmith to see any updates made to the 
//				referenced file. This feature is not intended to be convenient, 
//				bug-free, or industrial-strength. It is merely here to support 
//				the LDraw standard, and any files that may have been created 
//				under it.
//
//==============================================================================
- (CGImageRef) imageFromNeighboringFileForTexture:(LDrawTexture *)texture
{
	LDrawFile		*enclosingFile	= [texture enclosingFile];
	NSString		*filePath		= [enclosingFile path];
	NSString		*partName		= nil;
	NSString		*testPath		= nil;
	CGImageRef		image			= nil;
	NSFileManager	*fileManager	= nil;
	
	if(filePath != nil)
	{
		fileManager		= [[[NSFileManager alloc] init] autorelease];
		
		//look at path = parentFolder/referenceName
		partName		= [texture imageDisplayName]; // handle case-sensitive filesystem
		testPath		= [filePath stringByDeletingLastPathComponent];
		testPath		= [testPath stringByAppendingPathComponent:partName];
		
		//see if it exists!
		if([fileManager fileExistsAtPath:testPath])
		{
			image = [self readImageAtPath:testPath asynchronously:NO completionHandler:NULL];
			if(image != nil)
				[self->loadedImages setObject:(id)image forKey:partName];
		}
	}
	
	return image;
	
}//end imageFromNeighboringFileForTexture:


//========== modelForName: =====================================================
//
// Purpose:		Attempts to find the part based only on the given name.
//				This method can only find parts in the LDraw folder; it returns 
//				nil if fed an MPD submodel name.
//
//				NOT THREAD SAFE!
//
// Notes:		The part is looked up by the name specified in the part command. 
//				For regular parts and primitives, this is simply the filename 
//				as found in LDraw/parts or LDraw/p. But for subparts found in 
//				LDraw/parts/s, the filename is "s\partname.dat". (Same goes for 
//				LDraw/p/48.) This icky inconsistency is handled in 
//				-pathForFileName:.
//
//==============================================================================
- (LDrawModel *) modelForName:(NSString *) partName
{
	LDrawModel	*model		= nil;
	NSString	*partPath	= nil;
	
	// Has it already been parsed?
	model = [self->loadedFiles objectForKey:partName];


	if(model == nil)
	{
		//Well, this means we have to try getting it off the disk!
		// This case is only hit when a library part uses another library part, e.g.
		// a brick grabs a collection-of-studs part.
		partPath	= [[LDrawPaths sharedPaths] pathForPartName:partName];
		model		= [self readModelAtPath:partPath asynchronously:NO completionHandler:NULL];
		
		if(model != nil)
			[self->loadedFiles setObject:model forKey:partName];
	}

	return model;
	
}//end modelForName


//========== modelForPartInternal: =====================================================
//
// Purpose:		Returns the model to which this part refers. You can then ask
//				the model to draw itself.
//
//				NOT THREAD SAFE!
//
// Notes:		The part is looked up by the name specified in the part command. 
//				For regular parts and primitives, this is simply the filename 
//				as found in LDraw/parts or LDraw/p. But for subparts found in 
//				LDraw/parts/s, the filename is "s\partname.dat". (Same goes for 
//				LDraw/p/48.) This icky inconsistency is handled in 
//				-pathForFileName:.
//
//				This has been marked "internal" because the API is now only used
//				_within_ the part library, not by public clients.
//
//==============================================================================
- (LDrawModel *) modelForPartInternal:(LDrawPart *) part
{
	NSString	*partName	= [part referenceName];
	LDrawModel	*model		= nil;
	
	//Try to get a live link if we have parsed this part off disk already.
	//Ben sez: This routine is currently authorized to load on demand, but 
	//I never see that code run and I don't think it is suppose to.
	model = [self modelForName:partName];
	
	if(model == nil) {
		// We didn't find it in the LDraw folder. Hopefully this is a reference 
		// to another model in an MPD file. 
		model = [part referencedMPDSubmodel];
	}
	
	return model;
	
}//end modelForPartInternal:


//========== modelForName_threadSafe: ==========================================
//
// Purpose:		Returns the model to which this part name refers, thread-safe.
//
// Notes:		This will NOT attempt to read the file off disk. This method is 
//				only intended to be called during the multi-threaded file 
//				loading process, so there should be no need to do lazy loading.
//
//==============================================================================
- (LDrawModel *) modelForName_threadSafe:(NSString *)partName
{
	__block LDrawModel	*model		= nil;

	dispatch_sync(self->catalogAccessQueue, ^{
		model = [self->loadedFiles objectForKey:partName];
		
	});
	
	return model;
}

#pragma mark -

//========== optimizedDrawableForPart:color: ==================================
//
// Purpose:		Returns a vertex container which has been optimized to draw the 
//				given part. Vertex objects are shared among multiple part 
//				instances of the same name and color in order to reduce memory 
//				space. 
//
// Parameters:	part	- part to get/create a display list for.
//				color	- RGBA color for the part. We can't just ask the part for 
//						  its color because it might be LDrawCurrentColor, in 
//						  which case it is supposed to draw with its parent 
//						  color. 
//
//==============================================================================
- (LDrawDirective *) optimizedDrawableForPart:(LDrawPart *) part
										color:(LDrawColor *)color
{
	NSString            *referenceName  = [part referenceName];
	LDrawVertexes       *vertexObject   = nil;
	
	if([referenceName length] > 0)
	{
		vertexObject	= [self->optimizedRepresentations objectForKey:referenceName];
		
		if(vertexObject == nil)
		{
			LDrawModel	*modelToDraw = [self modelForPartInternal:part];
			
			if(modelToDraw != nil)
			{
				vertexObject = [[LDrawVertexes alloc] init];
				
				// Extract the optimized structure of the model.
				NSArray *modelSteps = [modelToDraw steps];
				NSArray *lines      = nil;
				NSArray *triangles  = nil;
				NSArray *quads      = nil;
				NSArray *allOthers  = nil;
				
				for(LDrawStep *currentStep in modelSteps)
				{
					switch([currentStep stepFlavor])
					{
						case LDrawStepLines:
							lines = [currentStep subdirectives];
							break;
						case LDrawStepTriangles:
							triangles = [currentStep subdirectives];
							break;
						case LDrawStepQuadrilaterals:
							quads = [currentStep subdirectives];
							break;
						case LDrawStepAnyDirectives:
							allOthers = [currentStep subdirectives];
							break;
						case LDrawStepConditionalLines: // ignore
							break;
					}
				}
				
				[vertexObject setLines:lines triangles:triangles quadrilaterals:quads other:allOthers];

				[self->optimizedRepresentations setObject:vertexObject forKey:referenceName];
			}
		}
		
		if(vertexObject != nil)
		{
			if([vertexObject isOptimizedForColor:color] == NO)
			{
				[vertexObject optimizeOpenGLWithParentColor:color];
			}
		}
	}
	
	return vertexObject;
	
}//end optimizedDrawableForPart:color:


//========== textureTagForTexture: =============================================
//
// Purpose:		Returns the OpenGL tag necessary to draw the image represented 
//				by the high-level texture object. 
//
//==============================================================================
- (GLuint) textureTagForTexture:(LDrawTexture*)texture
{
	NSString	*name		= [texture imageReferenceName];
	NSNumber	*tagNumber	= [self->optimizedTextures objectForKey:name];
	GLuint		textureTag	= 0;
	
	if(tagNumber)
	{
		textureTag = [tagNumber unsignedIntValue];
	}
	else
	{
		CGImageRef	image	= [self imageForTexture:texture];
		
		if(image)
		{
			CGRect			canvasRect		= CGRectMake( 0, 0, FloorPowerOfTwo(CGImageGetWidth(image)), FloorPowerOfTwo(CGImageGetHeight(image)) );
			uint8_t 		*imageBuffer	= malloc( (canvasRect.size.width) * (canvasRect.size.height) * 4 );
			CGColorSpaceRef colorSpace		= CGColorSpaceCreateDeviceRGB();
			CGContextRef	bitmapContext	= CGBitmapContextCreate(imageBuffer,
																	canvasRect.size.width,
																	canvasRect.size.height,
																	8, // bits per component
																	canvasRect.size.width * 4, // bytes per row
																	colorSpace,
																	kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst
																	);
			
			// Draw the image into the bitmap context. By doing so, we use the mighty 
			// power of Quartz handle the nasty conversion details necessary to fill up 
			// a pixel buffer in an OpenGL-friendly storage format and color space. 
			CGContextSetBlendMode(bitmapContext, kCGBlendModeCopy);
			CGContextDrawImage(bitmapContext, canvasRect, image);
			
//			CGImageRef output = CGBitmapContextCreateImage(bitmapContext);
//			CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:@"/out.png"], kUTTypePNG, 1, nil);
//			//NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:1.0], kCGImageDestinationLossyCompressionQuality, nil]; // Don't know if this is necessary
//			CGImageDestinationAddImage(myImageDest, output, NULL);
//			CGImageDestinationFinalize(myImageDest);
//			CFRelease(myImageDest);
			
			// Generate a tag for the texture we're about to generate, then set it as 
			// the active texture. 
			// Note: We are using non-rectangular textures here, which started as an 
			//		 extension (_EXT) and is now ratified by the review board (_ARB) 
			glGenTextures(1, &textureTag);
			glBindTexture(GL_TEXTURE_2D, textureTag);
			
			// Generate Texture!
			glPixelStorei(GL_PACK_ROW_LENGTH,	canvasRect.size.width * 4);
			glPixelStorei(GL_PACK_ALIGNMENT,	1); // byte alignment
			
			glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA8,			// texture type params
						 canvasRect.size.width, canvasRect.size.height, 0,	// source image (w, h)
						 GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV,				// source storage format
						 imageBuffer );
						// see function notes about the source storage format.
			
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

			glBindTexture(GL_TEXTURE_2D, 0);
			
			[self->optimizedTextures setObject:[NSNumber numberWithUnsignedInt:textureTag] forKey:name];
			
			// free memory
			//	free(imageBuffer);
			CFRelease(colorSpace);
			CFRelease(bitmapContext);
		}
	}
	
	return textureTag;
}


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== addPartsInFolder:toCatalog:underCategory: =========================
//
// Purpose:		Scans all the parts in folderPath and adds them to the given 
//				catalog, filing them under the given category. Pass nil for 
//				category if you wish to use the categories defined in the parts 
//				themselves.
//
// Parameters:	categoryOverride	- force all parts in the folder to be filed 
//									  under this category, rather than the one 
//									  defined inside the part. 
//				namePrefix			- appends this prefix to each part scanned. 
//									  Part references in LDraw/parts/s should be 
//									  prefixed with the DOS path "s\". Pass nil 
//									  to ignore the prefix. 
//				progressPanel		- a progress panel which is displaying the 
//									  progress of the creation of the part 
//									  catalog. 
//
//==============================================================================
- (void) addPartsInFolder:(NSString *)folderPath
				toCatalog:(NSMutableDictionary *)catalog
			underCategory:(NSString *)categoryOverride
			   namePrefix:(NSString *)namePrefix
{
	NSFileManager		*fileManager			= [[[NSFileManager alloc] init] autorelease];
// Not working for some reason. Why?
//	NSArray 			*readableFileTypes = [NSDocument readableTypes];
//	NSLog(@"readable types: %@", readableFileTypes);
	NSArray 			*readableFileTypes		= [NSArray arrayWithObjects:@"dat", @"ldr", nil];
	
	NSArray 			*partNames				= [fileManager contentsOfDirectoryAtPath:folderPath error:NULL];
	NSUInteger			numberOfParts			= [partNames count];
	NSUInteger			counter;
	
	NSString			*currentPath			= nil;
	NSMutableDictionary *categoryRecord 		= nil;
	
	//Get the subreference tables out of the main catalog (they should already exist!).
	NSMutableDictionary *catalog_partNumbers	= [catalog objectForKey:PARTS_LIST_KEY]; //lookup parts by number
	NSMutableDictionary *catalog_categories 	= [catalog objectForKey:PARTS_CATALOG_KEY]; //lookup parts by category
	NSMutableArray		*catalog_category		= nil;
	
	
	
	//Loop through the entire contents of the directory and extract the 
	// information for every part therein.	
	for(counter = 0; counter < numberOfParts; counter++) 
	{
		currentPath = [folderPath stringByAppendingPathComponent:[partNames objectAtIndex:counter]];
		
		if([readableFileTypes containsObject:[currentPath pathExtension]] == YES)
		{
			categoryRecord		= [self catalogInfoForFileAtPath:currentPath];
			
			// Make sure the part file was valid!
			if(categoryRecord != nil && [categoryRecord count] > 0)
			{
				//---------- Alter catalog info --------------------------------
				
				if(categoryOverride)
					[categoryRecord setObject:categoryOverride forKey:PART_CATEGORY_KEY];
				
				// Parts in subfolders of LDraw/parts must have a name prefix of 
				// their subpath, e.g., "s\partname.dat" for a part in the 
				// LDraw/parts/s folder. 
				if(namePrefix != nil)
				{
					NSString *partNumber = nil;
					partNumber	= [categoryRecord objectForKey:PART_NUMBER_KEY];
					partNumber	= [namePrefix stringByAppendingString:partNumber];
					[categoryRecord setObject:partNumber forKey:PART_NUMBER_KEY];
				}
				
				//---------- Catalog the part ----------------------------------
				
				NSString *category = [categoryRecord objectForKey:PART_CATEGORY_KEY];
				catalog_category = [catalog_categories objectForKey:category];
				if(catalog_category == nil)
				{
					//We haven't encountered this category yet. Initialize it now.
					catalog_category = [NSMutableArray array];
					[catalog_categories setObject:catalog_category forKey:category ];
				}
				
				// For some reason, I made each entry in the category a 
				// dictionary with part info. This was a database design 
				// mistake; it should have been an array of part reference 
				// numbers, if not just built up at runtime. 
				NSString *categoryEntry = [NSDictionary dictionaryWithObject:[categoryRecord objectForKey:PART_NUMBER_KEY]
																	  forKey:PART_NUMBER_KEY];
				[catalog_category addObject:categoryEntry];
				
				
				// Also file the part in a master list by reference name.
				[catalog_partNumbers setObject:categoryRecord
										forKey:[categoryRecord objectForKey:PART_NUMBER_KEY] ];
										
//				NSLog(@"processed %@", [partNames objectAtIndex:counter]);
			}
		}
		[self->delegate partLibraryIncrementLoadProgressCount:self];
		
	}//end loop through files
	
}//end addPartsInFolder:toCatalog:underCategory:


//========== categoryForDescription: ===========================================
//
// Purpose:		Returns the category for the given modelDescription. This is 
//				the first line of the file for non-MPD documents. For instance:
//
//				0 Brick  2 x  4
//
//				This part would be in the category "Brick", and has the 
//				description "Brick  2 x  4".
//
//==============================================================================
- (NSString *)categoryForDescription:(NSString *)modelDescription
{
	NSString	*category	= nil;
	NSRange		 firstSpace;			//range of the category string in the first line.
	
	//The category name is the first word in the description.
	firstSpace = [modelDescription rangeOfString:@" "];
	if(firstSpace.location != NSNotFound)
		category = [modelDescription substringToIndex:firstSpace.location];
	else
		category = [NSString stringWithString:modelDescription];
	
	
	// Deal with any weird notational marks
	
	// Alias parts begin with an underscore. These things are so annoying I'm 
	// going to dump them in a pseudo category. This is kind of a hack, but at 
	// least it's a prettifying one. 
	if([category hasPrefix:@"_"])
	{
		category = Category_Alias;
	}
	// Moved parts always begin with ~Moved, which is ugly. We'll strip the '~'.
	else if([category hasPrefix:@"~"])
	{
		category = [category substringFromIndex:1];
	}
	
	return category;
	
}//end categoryForDescription:


//========== descriptionForPart: ===============================================
//
// Purpose:		Returns the description of the given part based on its name.
//
//==============================================================================
- (NSString *) descriptionForPart:(LDrawPart *)part
{
	//Look up the verbose part description in the scanned part catalog.
	NSDictionary	*partList			= [self->partCatalog	objectForKey:PARTS_LIST_KEY];
	NSDictionary	*partRecord			= [partList				objectForKey:[part referenceName]];
	NSString		*partDescription	= [partRecord			objectForKey:PART_NAME_KEY];
	
	// Maybe it's an MPD reference?
	if(partDescription == nil)
	{
		partDescription = [[part referencedMPDSubmodel] browsingDescription];
	}
	
	// If the part STILL isn't known, all we can really do is just display the 
	// number. 
	if(partDescription == nil)
	{
		partDescription = [part displayName];
	}
	
	return partDescription;
	
}//end descriptionForPart:


//========== descriptionForPartName: ===========================================
//
// Purpose:		Returns the description associated with the given part name. 
//				For example, passing "3001.dat" returns "Brick 2 x 4".
//				If the name isn't known to the Part Library, we just return name.
//
// Note:		If you have a reference to the LDrawPart itself, you should pass 
//				it to -descriptionForPart instead.
//
//==============================================================================
- (NSString *) descriptionForPartName:(NSString *)name
{
	//Look up the verbose part description in the scanned part catalog.
	NSDictionary	*partList			= [self->partCatalog	objectForKey:PARTS_LIST_KEY];
	NSDictionary	*partRecord			= [partList				objectForKey:name];
	NSString		*partDescription	= [partRecord			objectForKey:PART_NAME_KEY];
	//If the part isn't known, all we can really do is just display the number.
	if(partDescription == nil)
		partDescription = name;
	
	return partDescription;
	
}//end descriptionForPartName:


//========== catalogInfoForFileAtPath: =========================================
//
// Purpose:		Pulls out the catalog-relevate metadata out of the given file. 
//				By convention, the first line of an non-MPD LDraw file is the 
//				description; e.g., 
//
//				0 Brick  2 x  4
//
//				This part is thus in the category "Brick", and has the  
//				description "Brick  2 x  4".
//
// Returns:		nil if the file is not valid.
//
//				PART_NUMBER_KEY		string
//				PART_CATEGORY_KEY	string
//				PART_KEYWORDS_KEY	array
//				PART_NAME_KEY		string
//
//==============================================================================
- (NSMutableDictionary *) catalogInfoForFileAtPath:(NSString *)filepath
{
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];

	NSString			*fileContents		= [LDrawUtilities stringFromFile:filepath];
	NSCharacterSet		*whitespace 		= [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	NSString            *partNumber         = nil;
	NSString			*partDescription	= nil;
	NSString			*category			= nil;
	NSMutableArray		*keywords			= nil;
	
	NSMutableDictionary *catalogInfo		= nil;
	
	
	// Read the first line of the file. Make sure the file is parsable.
	if(		fileContents != nil
	   &&	[fileContents length] > 0 )
	{
		NSUInteger	stringLength		= [fileContents length];
		NSUInteger	lineStartIndex		= 0;
		NSUInteger	nextlineStartIndex	= 0;
		NSUInteger	newlineIndex		= 0; //index of the first newline character in the line.
		NSInteger	lineLength			= 0;
		NSString	*line				= nil;
		NSString	*lineCode			= nil;
		NSString	*lineRemainder		= nil;
		
		catalogInfo = [NSMutableDictionary dictionary];
		
		// Get the name of the part.
		// We need a standard way to reference it; use lower-case to avoid any 
		// case-sensitivity issues. 
		partNumber = [[filepath lastPathComponent] lowercaseString];
		[catalogInfo setObject:partNumber forKey:PART_NUMBER_KEY];
		
		while(nextlineStartIndex < stringLength)
		{
			// LDraw uses DOS lineendings
			[fileContents getLineStart: &lineStartIndex
								   end: &nextlineStartIndex
						   contentsEnd: &newlineIndex
							  forRange: NSMakeRange(nextlineStartIndex,1) ]; //that is, contains the first character.
			
			lineLength	= newlineIndex - lineStartIndex;
			line		= [fileContents substringWithRange:NSMakeRange(lineStartIndex, lineLength)];
			lineCode	= [LDrawUtilities readNextField:line remainder:&lineRemainder ];

			//Check to see if this is a valid LDraw header.
			if(lineStartIndex == 0)
			{
				if([lineCode isEqualToString:@"0"] == NO)
					break;
					
				partDescription = [lineRemainder stringByTrimmingCharactersInSet:whitespace];
				[catalogInfo setObject:partDescription forKey:PART_NAME_KEY];
			}
			else if([lineCode isEqualToString:@"0"] == YES)
			{
				// Try to find keywords or category
				NSString *meta = [LDrawUtilities readNextField:lineRemainder remainder:&lineRemainder];
				
				if([meta isEqualToString:LDRAW_CATEGORY])
				{
					category = [lineRemainder stringByTrimmingCharactersInSet:whitespace];
					
					// Turns out !CATEGORY is not as reliable as it ought to be. 
					// In typical LDraw fashion, the feature was not have a 
					// simultaneous, universal deployment. Unfortunately, the 
					// only categories I deem to be consistent and advantageous 
					// under the current system are the two-word categories that 
					// couldn't be represented under the old system. 
					//
					// Also, allow the !LDRAW_ORG Part Alias to take precedence 
					// if it has already been found. 
					if(		[category rangeOfString:@" "].location != NSNotFound
					   &&	[catalogInfo objectForKey:PART_CATEGORY_KEY] == nil )
					{
						[catalogInfo setObject:category forKey:PART_CATEGORY_KEY];
					}
				}
				else if([meta isEqualToString:LDRAW_KEYWORDS])
				{
					if(keywords == nil)
					{
						keywords = [NSMutableArray array];
						[catalogInfo setObject:keywords forKey:PART_KEYWORDS_KEY];
					}
					// Keywords can be multiline, so must add to any we've already collected! 
					NSArray *newKeywords = [lineRemainder componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
					for(NSString *keyword in newKeywords)
					{
						[keywords addObject:[keyword stringByTrimmingCharactersInSet:whitespace]];
					}
				}
				else if([meta isEqualToString:LDRAW_ORG])
				{
					// Force alias parts into a ghetto category which will keep 
					// them far away from normal building. 
					NSString *officialStatus = [lineRemainder stringByTrimmingCharactersInSet:whitespace];
					if([officialStatus containsString:@"Part Alias" options:kNilOptions])
					{
						category = Category_Alias;
						[catalogInfo setObject:category forKey:PART_CATEGORY_KEY];
					}
				}
			}
			else if([lineCode length] == 0)
			{
				// line is blank. Skip.
			}
			else
			{
				// Non-comment, non-blank line. This cannot be part of the header.
				break;
			}
		}
		
		// If no !CATEGORY directive, the the category is to be derived from the 
		// first word of the description. 
		if(		[catalogInfo objectForKey:PART_NAME_KEY]
		   &&	[catalogInfo objectForKey:PART_CATEGORY_KEY] == nil)
		{
			partDescription = [catalogInfo objectForKey:PART_NAME_KEY];
			category		= [self categoryForDescription:partDescription];
			[catalogInfo setObject:category forKey:PART_CATEGORY_KEY];
		}
	}
	else
	{
		NSLog(@"%@ is not a valid file", filepath);
	}
	
	[catalogInfo retain];
	[pool drain];
	
	return [catalogInfo autorelease];
	
}//end catalogInfoForFileAtPath


//========== readImageAtPath: ==================================================
//
// Purpose:		Parses the model found at the given path, adds it to the list of 
//				loaded parts, and returns the model.
//
// Notes:		The model is returned from the method if asynchronous is NO.
//				Otherwise, returns nil and passes the completed model via the 
//				block instead. 
//
//==============================================================================
- (CGImageRef) readImageAtPath:(NSString *)imagePath
				asynchronously:(BOOL)asynchronous
			 completionHandler:(void (^)(CGImageRef))completionBlock
{
	dispatch_group_t    group           = NULL;
#if USE_BLOCKS
	__block
#endif
	CGImageRef			image          = nil;
	
#if USE_BLOCKS
	group           = dispatch_group_create();
#endif
	
#if USE_BLOCKS
	if(asynchronous == NO)
	{
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#endif
		image = [LDrawUtilities imageAtPath:imagePath];
#if USE_BLOCKS
	}
	else
	{
		dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
							  ^{
								  image = [LDrawUtilities imageAtPath:imagePath];
								  
								  if(completionBlock)
									  completionBlock(image);
							  });
	}
	
	dispatch_release(group);
#endif
	
	return (CGImageRef)[(id)image autorelease];
	
}//end readImageAtPath:


//========== readModelAtPath:asynchronously:completionHandler: =================
//
// Purpose:		Parses the model found at the given path, adds it to the list of 
//				loaded parts, and returns the model.
//
// Notes:		The model is returned from the method if asynchronous is NO.
//				Otherwise, returns nil and passes the completed model via the 
//				block instead. 
//
//==============================================================================
- (LDrawModel *) readModelAtPath:(NSString *)partPath
				  asynchronously:(BOOL)asynchronous
			   completionHandler:(void (^)(LDrawModel *))completionBlock
{
	NSString            *fileContents   = nil;
	NSArray             *lines          = nil;
	LDrawFile           *parsedFile     = nil;
	dispatch_group_t    group           = NULL;
#if USE_BLOCKS
	__block
#endif
			LDrawModel  *model          = nil;
	
#if USE_BLOCKS
	group           = dispatch_group_create();
#endif

	if(partPath != nil)
	{
		// We found it in the LDraw folder; now all we need to do is get the 
		// model for it. 
		fileContents    = [LDrawUtilities stringFromFile:partPath];
		lines           = [fileContents separateByLine];
		
		parsedFile      = [[LDrawFile alloc] initWithLines:lines
												   inRange:NSMakeRange(0, [lines count])
											   parentGroup:group];
	}
	
#if USE_BLOCKS
	if(asynchronous == NO)
	{
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#endif
		[parsedFile optimizeStructure];
		model = [[[[parsedFile submodels] objectAtIndex:0] retain] autorelease];
		// We are "leaking" the enclosing file, but returning an internal model 
		// without disconnecting it from its file is pretty dodgy and it would 
		// be easy to code a bug in. We'd be better off returning the file 
		// itself, or perhaps removing the model from its file (since everything 
		// is theoretically flattened). 
//		[parsedFile release];
#if USE_BLOCKS
	}
	else
	{
		dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
							  ^{
								  [parsedFile optimizeStructure];
								  model = [[[[parsedFile submodels] objectAtIndex:0] retain] autorelease];
								  
								  if(completionBlock)
									  completionBlock(model);
								  
								  //			[parsedFile release]; // see notes above
							  });
	}
	
	dispatch_release(group);
#endif
	
	return model;
	
}//end readModelAtPath:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We have turned a corner on the Circle of Life.
//
//==============================================================================
- (void) dealloc
{
	[partCatalog				release];
	[favorites					release];
	[loadedFiles				release];
	[loadedImages				release];
	[optimizedRepresentations	release];
	[optimizedTextures			release];
#if USE_BLOCKS
	dispatch_release(catalogAccessQueue);
#endif
	[parsingGroups		release];
	
	[super dealloc];
	
}//end dealloc


@end
