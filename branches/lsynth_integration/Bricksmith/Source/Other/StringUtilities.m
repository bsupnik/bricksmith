//==============================================================================
//
// File:		StringUtilities.m
//
// Purpose:		General string utility methods.
//
// Modified:	12/21/2008 Allen Smith. Creation Date.
//
//==============================================================================
#import "StringUtilities.h"


@implementation StringUtilities

//---------- nextCopyNameForString: ----------------------------------[static]--
//
// Purpose:		Returns the next name (in sequence) for a copy of the given 
//				name. 
//
// Notes:		This method does not attempt to check for the existence of the 
//				copy name it returns; that is the caller's responsibility. 
//
// Examples:	Base Name				New Name
//				----------				----------
//				foo						foo copy
//				foo copy				foo copy 2
//				foo copy 3				foo copy 4
//				foo.txt					foo.txt copy		// ignores extensions!
//				foo copy.txt			foo copy.txt copy
//
//------------------------------------------------------------------------------
+ (NSString *) nextCopyNameForString:(NSString *)originalString
{
	NSString    *copyToken          = NSLocalizedString(@"CopySuffix", nil);
	NSRange     rangeOfCopyToken    = [originalString rangeOfString:copyToken options:NSBackwardsSearch];
	NSScanner   *copyNumberScanner  = nil;
	NSInteger   currentCopyNumber   = 0;
	BOOL        foundCopyNumber     = NO;
	NSString    *baseName           = nil;
	NSString    *newCopyString      = nil;
	
	// This string doesn't have the word "copy" in it yet.
	if(rangeOfCopyToken.location == NSNotFound)
	{
		currentCopyNumber = 0;
	}
	// This is already a copy itself; now we need to figure out which copy is 
	// next! 
	else
	{
		copyNumberScanner	= [NSScanner scannerWithString:originalString];
		[copyNumberScanner setScanLocation:NSMaxRange(rangeOfCopyToken)];
		
		// Is there a number at the end?
		foundCopyNumber = [copyNumberScanner scanInteger:&currentCopyNumber];
		
		if([copyNumberScanner isAtEnd] == NO)
		{
			// The word "copy" in the name was apparently followed by something 
			// other than an integer or the empty string. Thus, it is not a 
			// valid copy token. So just append the word copy to the end and be 
			// done with it. 
			currentCopyNumber = 0;
		}
		else if(	[copyNumberScanner isAtEnd] == YES
				&&	foundCopyNumber == NO )
		{
			// The word copy is there, but not followed by a number. So this is 
			// the first copy. 
			currentCopyNumber = 1;
		}
		
		// Pathological case: It's a negative number!
		if(currentCopyNumber < 0)
			currentCopyNumber = 0;
	}
	
	// Build the copy string.
	switch(currentCopyNumber)
	{
		case 0:
			// Just append the word "copy" for the first copy
			newCopyString = [originalString stringByAppendingFormat:@" %@", copyToken];
			break;
		
		default:
			// Strip the old copy number
			baseName = [originalString substringToIndex:NSMaxRange(rangeOfCopyToken)];
		
			// Increment the copy number.
			newCopyString = [baseName stringByAppendingFormat:@" %ld", (long)(currentCopyNumber + 1)];
			break;
	}
	
	return newCopyString;
			
}//end nextCopyNameForString:


//---------- nextCopyPathForFilePath: --------------------------------[static]--
//
// Purpose:		Returns the next path or file name (in sequence) for a copy of 
//				the given name. Correctly handles file extensions.
//
// Notes:		This method does not attempt to check for the existence of the 
//				copy name it returns; that is the caller's responsibility. 
//
// Examples:	Base Name				New Name
//				----------				----------
//				foo						foo copy
//				foo copy				foo copy 2
//				foo copy 3				foo copy 4
//				foo.txt					foo copy.txt
//				foo copy.txt			foo copy 2.txt
//
//------------------------------------------------------------------------------
+ (NSString *) nextCopyPathForFilePath:(NSString *)basePath
{
	NSString	*fileName				= [basePath lastPathComponent];
	NSString	*enclosingPath			= [basePath stringByDeletingLastPathComponent];
	NSString	*extension				= [basePath pathExtension];
	NSString	*fileNameSansExtension	= [fileName stringByDeletingPathExtension];
	NSString	*copyBaseName			= nil;
	NSString	*copyPath				= nil;
	
	// Derive the copy name and reconstitute the new path based on it.
	copyBaseName	= [StringUtilities nextCopyNameForString:fileNameSansExtension];
	copyPath		= [enclosingPath stringByAppendingPathComponent:copyBaseName];
	copyPath		= [copyPath stringByAppendingPathExtension:extension];
	
	return copyPath;
	
}//end nextCopyPathForFilePath:


@end
