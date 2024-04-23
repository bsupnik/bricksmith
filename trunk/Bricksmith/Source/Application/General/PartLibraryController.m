//==============================================================================
//
// File:		PartLibraryController.h
//
// Purpose:		UI layerings on top of PartLibrary.
//
// Modified:	01/28/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "PartLibraryController.h"

#import <AMSProgressBar/AMSProgressBar.h>

#import "LDrawPaths.h"
#import "MacLDraw.h"

@implementation PartLibraryController

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize a controller for a part library (also initialize the 
//				library itself). 
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	// Create the part library
	PartLibrary *library = [PartLibrary sharedPartLibrary];
	[library setDelegate:self];
	
	return self;

}//end init


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== loadPartCatalog ===================================================
//
// Purpose:		Reads the part catalog out of the LDraw folder. Returns YES upon 
//				success.
//
//==============================================================================
- (void) loadPartCatalog:(void (^)(BOOL success))completionHandler
{
	PartLibrary *library    = [PartLibrary sharedPartLibrary];
	NSArray     *favorites  = [[NSUserDefaults standardUserDefaults] objectForKey:FAVORITE_PARTS_KEY];
	BOOL        success     = NO;
	
	// Try loading an existing library first.
	[library setFavorites:favorites];
	success = [library load];
	
	if(success == NO)
	{
		// loading failed; try reloading (generates a new part list)
		[self reloadPartCatalog:completionHandler];
	}
	else if(completionHandler != nil)
	{
		completionHandler(success);
	}
	
}//end loadPartCatalog


//========== reloadPartCatalog =================================================
//
// Purpose:		Scans the contents of the LDraw/ folder and produces a 
//				Mac-friendly index of parts, displaying a progress bar.
//
//==============================================================================
- (void) reloadPartCatalog:(void (^)(BOOL success))completionHandler
{
	AMSProgressPanel* progressPanel	= [AMSProgressPanel progressPanel];
	
	[progressPanel setMessage:@"Loading Parts"];
	[progressPanel showProgressPanel];
	
	[[PartLibrary sharedPartLibrary] reloadPartsWithMaxLoadCountHandler:
	 ^(NSUInteger maxPartCount)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[progressPanel setMaxValue:maxPartCount];
		});
	}
											   progressIncrementHandler:
	 ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[progressPanel increment];
		});
	}
													  completionHandler:
	 ^(BOOL success)
	 {
		dispatch_async(dispatch_get_main_queue(), ^{
			[progressPanel close];
			if(completionHandler)
			{
				completionHandler(success);
			}
		});
	}];
	
	// To print out a list of all categories. For debugging !CATEGORY coverage.
//	NSArray *categories = [[[PartLibrary sharedPartLibrary] categories] sortedArrayUsingSelector:@selector(compare:)];
//	NSMutableString* list = [NSMutableString string];
//	for(NSString* name in categories)
//	{
//		[list appendString:name];
//		[list appendString:@"\n"];
//	}
//	NSLog(@"%@", list);
	
}//end reloadPartCatalog


//========== validateLDrawFolderWithMessage: ===================================
//
// Purpose:		Checks to see that the folder at path is indeed a valid LDraw 
//				folder and contains the vital Parts and P directories.
//
//==============================================================================
- (BOOL) validateLDrawFolderWithMessage:(NSString *) folderPath
{
	BOOL folderIsValid = [[LDrawPaths sharedPaths] validateLDrawFolder:folderPath];
	
	if(folderIsValid == NO)
	{
		NSAlert *error = [[NSAlert alloc] init];
		[error setAlertStyle:NSCriticalAlertStyle];
		[error addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		
		[error setMessageText:NSLocalizedString(@"LDrawFolderChooserErrorMessage", nil)];
		[error setInformativeText:NSLocalizedString(@"LDrawFolderChooserErrorInformative", nil)];
		
		[error runModal];
	}
	
	return folderIsValid;
	
}//end validateLDrawFolder


#pragma mark -
#pragma mark PART LIBRARY DELEGATE
#pragma mark -

//========== partLibrary:didChangeFavorites: ===================================
//
// Purpose:		Save new favorites into preferences.
//
//==============================================================================
- (void) partLibrary:(PartLibrary *)partLibrary didChangeFavorites:(NSArray *)newFavorites
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults setObject:newFavorites forKey:FAVORITE_PARTS_KEY];
}


@end
