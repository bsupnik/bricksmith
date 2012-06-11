//==============================================================================
//
// File:		StringUtilities.h
//
// Purpose:		General string utility methods.
//
// Modified:	12/21/2008 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


@interface StringUtilities : NSObject
{

}

+ (NSString *) nextCopyNameForString:(NSString *)originalString;
+ (NSString *) nextCopyPathForFilePath:(NSString *)basePath;

@end
