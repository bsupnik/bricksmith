//==============================================================================
//
// File:		PartLibraryController.h
//
// Purpose:		UI layerings on top of PartLibrary.
//
// Modified:	01/28/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "PartLibrary.h"


////////////////////////////////////////////////////////////////////////////////
//
// class PartLibraryController
//
////////////////////////////////////////////////////////////////////////////////
@interface PartLibraryController : NSObject <PartLibraryDelegate>

// Actions
- (void) loadPartCatalog:(void (^)(BOOL success))completionHandler;
- (void) reloadPartCatalog:(void (^)(BOOL success))completionHandler;
- (BOOL) validateLDrawFolderWithMessage:(NSString *) folderPath;

@end
