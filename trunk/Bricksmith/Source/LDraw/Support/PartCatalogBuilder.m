//
//  PartCatalogBuilder.m
//  Bricksmith
//
//  Created by Allen Smith on 1/6/22.
//

#import "PartCatalogBuilder.h"

#import "LDrawKeywords.h"
#import "LDrawPathNames.h"
#import "LDrawPaths.h"
#import "LDrawUtilities.h"
#import "PartLibrary.h"
#import "StringCategory.h"

@implementation PartCatalogBuilder

//========== makePartCatalogWithDelegate: ======================================
///
/// @abstract	Scans the contents of the LDraw/ folder and produces a
///				Mac-friendly index of parts.
///
///				Executed on a background thread.
///
///				Is it fast? No. Is it easy to code? Yes.
///
///				Someday in the rosy future, this method should be recoded to
///				simply traverse the directory tree and deal with subfolders on
///				the fly. But that's not how it is now. Instead, I'm doing it
///				all manually. Folders searched are:
///
///				LDraw/p/
///				LDraw/p/48/
///
///				LDraw/parts/
///				LDraw/parts/s/
///
///				LDraw/Unofficial/p/
///				LDraw/Unofficial/p/48/
///				LDraw/Unofficial/parts/
///				LDraw/Unofficial/parts/s/
///
///				It is important that the part name added to the library bear
///				the correct reference style. For LDraw/p/ and LDraw/parts/, it
///				is simply the filename (in lowercase). But for subdirectories,
///				the filename must be prefixed with the subdirectory in DOS
///				format, i.e., "s\file.dat" or "48\file.dat".
///
/// @param 		maxLoadCountHandler			Will be called (on a background
/// 										thread) to indicate the total number
/// 										of objects to be loaded.
///
/// @param 		progressIncrementHandler	Will be called (on a background
/// 										thread) to indicate an object has
/// 										been processed toward the max load
/// 										count.
///
/// @param 		completionHandler 			Will be called (on a background
/// 										thread) to when the catalog has
/// 										fully loaded. The new catalog is
/// 										passed as an argument.
///
//==============================================================================
- (void) makePartCatalogWithMaxLoadCountHandler:(void (^)(NSUInteger maxPartCount))maxLoadCountHandler
					   progressIncrementHandler:(void (^)())progressIncrementHandler
							  completionHandler:(void (^)(NSDictionary<NSString*, id> *newCatalog))completionHandler
{
	NSFileManager	*fileManager			= [[[NSFileManager alloc] init] autorelease];
	LDrawPaths		*paths					= [[[LDrawPaths alloc] init] autorelease];
	NSString		*ldrawPath				= [paths preferredLDrawPath];
	NSMutableArray	*searchPaths			= [NSMutableArray array];
	
	NSString		*prefix_primitives48	= [NSString stringWithFormat:@"%@\\", PRIMITIVES_48_DIRECTORY_NAME];
	NSString		*prefix_subparts		= [NSString stringWithFormat:@"%@\\", SUBPARTS_DIRECTORY_NAME];
	
	//make sure the LDraw folder is still valid; otherwise, why bother doing anything?
	if([paths validateLDrawFolder:ldrawPath] == NO)
	{
		completionHandler(nil);
		return;
	}
	
	dispatch_queue_t catalogAccessQueue = dispatch_queue_create("com.AllenSmith.Bricksmith.CatalogLoader", NULL);
	dispatch_async(catalogAccessQueue, ^{
		
		// Parts
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths partsPathForDomain:LDrawUserOfficial],				@"path",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths partsPathForDomain:LDrawUserUnofficial],				@"path",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths partsPathForDomain:LDrawInternalOfficial],			@"path",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths partsPathForDomain:LDrawInternalUnofficial],			@"path",
									nil]];

		// Primitives
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitivesPathForDomain:LDrawUserOfficial],			@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									nil]];
									
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitivesPathForDomain:LDrawUserUnofficial],		@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									nil]];
		
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitivesPathForDomain:LDrawInternalOfficial],		@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									nil]];
									
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitivesPathForDomain:LDrawInternalUnofficial],	@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									nil]];
		
		// Primitives 48
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitives48PathForDomain:LDrawUserOfficial],		@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									prefix_primitives48,										@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitives48PathForDomain:LDrawUserUnofficial],		@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									prefix_primitives48,										@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitives48PathForDomain:LDrawInternalOfficial],	@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									prefix_primitives48,										@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths primitives48PathForDomain:LDrawInternalUnofficial],	@"path",
									NSLocalizedString(Category_Primitives, nil),				@"category",
									prefix_primitives48,										@"prefix",
									nil]];

		// Subparts
		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths subpartsPathForDomain:LDrawUserOfficial],			@"path",
									NSLocalizedString(Category_Subparts, nil),					@"category",
									prefix_subparts,											@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths subpartsPathForDomain:LDrawUserUnofficial],			@"path",
									NSLocalizedString(Category_Subparts, nil),					@"category",
									prefix_subparts,											@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths subpartsPathForDomain:LDrawInternalOfficial],		@"path",
									NSLocalizedString(Category_Subparts, nil),					@"category",
									prefix_subparts,											@"prefix",
									nil]];

		[searchPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[paths subpartsPathForDomain:LDrawInternalUnofficial],		@"path",
									NSLocalizedString(Category_Subparts, nil),					@"category",
									prefix_subparts,											@"prefix",
									nil]];

		NSString							*partCatalogPath	= [paths partCatalogPath];
		NSMutableDictionary<NSString*, id>	*newPartCatalog 	= [NSMutableDictionary dictionary];
		
		NSUInteger							partCount			= 0;

		// Start the progress bar so that we know what's happening.
		for(NSString *path in [searchPaths valueForKey:@"path"])
		{
			partCount += [[fileManager contentsOfDirectoryAtPath:path error:NULL] count];
		}
		if(maxLoadCountHandler)
		{
			maxLoadCountHandler(partCount);
		}
		
		// Create the new part catalog. We will then fill it with folder contents.
		[newPartCatalog setObject:[NSMutableDictionary dictionary] forKey:PARTS_CATALOG_KEY];
		[newPartCatalog setObject:[NSMutableDictionary dictionary] forKey:PARTS_LIST_KEY];
		
		// Scan for each part folder.
		for(NSDictionary *record in searchPaths)
		{
			[self addPartsInFolder:[record objectForKey:@"path"]
						 toCatalog:newPartCatalog
					 underCategory:[record objectForKey:@"category"] //override all internal categories
						namePrefix:[record objectForKey:@"prefix"]
		  progressIncrementHandler:progressIncrementHandler];
		}
		
		NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
		[newPartCatalog setObject:version forKey:VERSION_KEY];
		[newPartCatalog setObject:@"1.0"  forKey:COMPATIBILITY_VERSION_KEY];
		
		//Save the part catalog out for future reference.
		[newPartCatalog writeToFile:partCatalogPath atomically:YES];
		
		// We succeeded in loading the parts!
		completionHandler(newPartCatalog);
	});
	
}//end reloadParts:


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
//
//==============================================================================
- (void) addPartsInFolder:(NSString *)folderPath
				toCatalog:(NSMutableDictionary *)catalog
			underCategory:(NSString *)categoryOverride
			   namePrefix:(NSString *)namePrefix
 progressIncrementHandler:(void (^)())progressIncrementHandler
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
				if(category)
				{
					// Check for dupe parts and reject later ones.  If we don't and the unofficial
					// library has a part that has had its category edited, we'll end up with the
					// part in BOTH categories.  This can hose us when the library changes which
					// part is canonical vs alias.
					NSString * partNumber = [categoryRecord objectForKey:PART_NUMBER_KEY];
					if([catalog_partNumbers objectForKey:partNumber] == nil)
					{
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
						NSDictionary *categoryEntry = [NSDictionary dictionaryWithObject:[categoryRecord objectForKey:PART_NUMBER_KEY]
																			  forKey:PART_NUMBER_KEY];
																			  
						[catalog_category addObject:categoryEntry];
						
						// Also file the part in a master list by reference name.
						[catalog_partNumbers setObject:categoryRecord
												forKey:[categoryRecord objectForKey:PART_NUMBER_KEY] ];
					}
					else
					{
						//NSLog(@"Skipped part %s at path %s - duplicate part ID.\n", [partNumber UTF8String],[currentPath UTF8String]);
					}
				}
										
//				NSLog(@"processed %@", [partNames objectAtIndex:counter]);
			}
		}
		if(progressIncrementHandler)
		{
			progressIncrementHandler();
		}
		
	}//end loop through files
	
}//end addPartsInFolder:toCatalog:underCategory:


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
    NSMutableDictionary *catalogInfo        = nil;
    
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];

	NSString			*fileContents		= [LDrawUtilities stringFromFile:filepath];
	NSCharacterSet		*whitespace 		= [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	NSString            *partNumber         = nil;
	NSString			*partDescription	= nil;
	NSString			*category			= nil;
	NSMutableArray		*keywords			= nil;
	
	
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
		NSString	*implicitCategory	= nil;
		
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
				implicitCategory = [self categoryForDescription:partDescription];
				[catalogInfo setObject:partDescription forKey:PART_NAME_KEY];
			}
			else if([lineCode isEqualToString:@"0"] == YES)
			{
				// Try to find keywords or category
				NSString *meta = [LDrawUtilities readNextField:lineRemainder remainder:&lineRemainder];
				
				if([meta isEqualToString:LDRAW_CATEGORY])
				{
					// Turns out !CATEGORY is not as reliable as it ought to be.
					// In typical LDraw fashion, the feature was not have a
					// simultaneous, universal deployment. Circa 2014, the only
					// categories I deemed to be consistent and advantageous
					// under the current system are the two-word categories that
					// couldn't be represented under the old system.
					//
					// 2020 update: I am not going to fight !CATEGORY anymore.
					// With one exception: Duplo parts should not be mixed in,
					// and LDraw is making no attempt to separate them. So if
					// the description begins with Duplo, I'm ignoring the
					// !CATEGORY, which will cause implicitCategory (Duplo) to
					// win.
					//
					// Also, allow the !LDRAW_ORG Part Alias to take precedence
					// if it has already been found.
					if(		[implicitCategory hasPrefix:@"Duplo"] == NO
					   &&	[catalogInfo objectForKey:PART_CATEGORY_KEY] == nil )
					{
						category = [lineRemainder stringByTrimmingCharactersInSet:whitespace];
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
					// !LDRAW_ORG: optional qualifier Alias can appear with Part/Shortcut/etc https://www.ldraw.org/article/398.html
					if([lineRemainder ams_containsString:@"Alias" options:kNilOptions])
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
			category		= implicitCategory;
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
	
	// Physical Color parts begin with an underscore. Then they got obsoleted,
	// and obsolete parts begin with ~, so now *most* of them begin with ~|. But
	// not all. These things are so annoying I'm going to dump them in a pseudo
	// category. This is kind of a hack, but at least it's a prettifying one.
	if([category hasPrefix:@"_"] || [category hasPrefix:@"~_"])
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


@end
