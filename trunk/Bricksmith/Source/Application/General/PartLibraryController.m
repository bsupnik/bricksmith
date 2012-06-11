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
- (BOOL) loadPartCatalog
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
		success = [self reloadPartCatalog];
	}
		
	return success;
	
}//end loadPartCatalog


//========== reloadPartCatalog =================================================
//
// Purpose:		Scans the contents of the LDraw/ folder and produces a 
//				Mac-friendly index of parts, displaying a progress bar.
//
//==============================================================================
- (BOOL) reloadPartCatalog
{
	BOOL success = NO;

	self->progressPanel	= [AMSProgressPanel progressPanel];
	
	[self->progressPanel setMessage:@"Loading Parts"];
	[self->progressPanel showProgressPanel];
	
	success = [[PartLibrary sharedPartLibrary] reloadParts];
	
	[self->progressPanel close];
	
	return success;
	
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
		
		[error release];
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


//========== partLibrary:maximumPartCountToLoad: ===============================
//
// Purpose:		The reloader is telling us the maximum number of files to 
//				expect. 
//
//==============================================================================
- (void)		partLibrary:(PartLibrary *)partLibrary
	 maximumPartCountToLoad:(NSUInteger)maxPartCount
{
	[self->progressPanel setMaxValue:maxPartCount];
	
}//end partLibrary:maximumPartCountToLoad:


//========== partLibraryIncrementLoadProgressCount: ============================
//
// Purpose:		Tells us that the reloader has loaded one additional item.
//
//==============================================================================
- (void) partLibraryIncrementLoadProgressCount:(PartLibrary *)partLibrary
{
	[self->progressPanel increment];
	
}//end partLibraryIncrementLoadProgressCount:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're, uh, checking out.
//
//==============================================================================
- (void) dealloc
{
	[super dealloc];
	
}//end dealloc


@end
