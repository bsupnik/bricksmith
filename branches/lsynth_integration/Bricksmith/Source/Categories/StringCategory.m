//==============================================================================
//
// File:		StringCategory.m
//
// Purpose:		Handy string utilities. Provides one-stop (Interface Builder-
//				compatible!) method for doing a numeric sort and other nice 
//				convenience methods.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "StringCategory.h"

#include <stdlib.h>

@implementation NSString (StringCategory)


//========== containsString:options: ===========================================
//
// Purpose:		Handy for quick searches.
//
// Note:		Every string is reported as containing the empty string (@"").
//
//==============================================================================
- (BOOL) containsString:(NSString *)substring options:(NSUInteger)mask
{
	NSRange foundRange = [self rangeOfString:substring options:mask];
	
	if(		foundRange.location == NSNotFound
		&& [substring isEqualToString:@""] == NO)
	{
		return NO;
	}
	else
		return YES;
		
}//end containsString:options:


//---------- CRLF ----------------------------------------------------[static]--
//
// Purpose:		Returns a DOS line-end marker, which is a hideous two characters 
//				in length.
//
//------------------------------------------------------------------------------
+ (NSString *) CRLF
{
	unichar CRLFchars[] = {0x000D, 0x000A}; //DOS linefeed.
	NSString *CRLF = [NSString stringWithCharacters:CRLFchars length:2];
	
	return CRLF;
	
}//end CRLF


//========== numericCompare: ===================================================
//
// Purpose:		Provides one-stop (Interface Builder-compatible!) method for 
//				doing a numeric sort.
//
//==============================================================================
- (NSComparisonResult)numericCompare:(NSString *)string
{
	return [self compare:string options:NSNumericSearch];
	
}//end numericCompare:


//========== separateByLine ====================================================
//
// Purpose:		Returns an array of all the lines in the string, with line 
//				terminators removed.
//
//==============================================================================
- (NSArray *) separateByLine
{
	NSMutableArray  *lines              = [NSMutableArray array];
	NSUInteger      stringLength        = [self length];
	
	NSUInteger      lineStartIndex      = 0;
	NSUInteger      nextlineStartIndex  = 0;
	NSUInteger      newlineIndex        = 0; //index of the first newline character in the line.
	
	NSString        *isolatedLine;
	NSInteger       lineLength          = 0;
	
	while(nextlineStartIndex < stringLength){
		//Read the first line. LDraw files are in DOS format. Oh the agony.
		// But Cocoa is nice to us.
		[self getLineStart: &lineStartIndex
					   end: &nextlineStartIndex
			   contentsEnd: &newlineIndex
				  forRange: NSMakeRange(nextlineStartIndex,1) ]; //that is, contains the first character.
		
		lineLength = newlineIndex - lineStartIndex;
		isolatedLine = [self substringWithRange:NSMakeRange(lineStartIndex, lineLength)];
		[lines addObject:isolatedLine];
	}
	
	return lines;
	
}//end separateStringByLine


//========== stringByRemovingWhitespace ========================================
//
// Purpose:		Returns a new string equal to the receiver, except that it 
//				contains no whitespace charaters. 
//
//==============================================================================
- (NSString *) stringByRemovingWhitespace
{
	NSInteger       originalLength      = [self length];
	unichar         *resultBuffer       = malloc( sizeof(unichar) * originalLength );
	NSCharacterSet  *whitespaceSet      = [NSCharacterSet whitespaceCharacterSet];
	unichar         currentCharacter    = '\0';
	NSInteger       resultLength        = 0;
	NSInteger       counter             = 0;
	NSString        *strippedString     = nil;
	
	// Copy only non-whitespace characters into the new string.
	//	* We'll assume the Unicode Consortium will never be sick enough to put 
	//	  whitespace outside the BMP, or that our users will never employ such a 
	//	  beast if they did. 
	for(counter = 0; counter < originalLength; counter++)
	{
		currentCharacter = [self characterAtIndex:counter];
		if([whitespaceSet characterIsMember:currentCharacter] == NO)
		{
			resultBuffer[resultLength] = currentCharacter;
			resultLength++;
		}
	}
	strippedString = [NSString stringWithCharacters:resultBuffer length:resultLength];
	
	// free memory
	free(resultBuffer);
	
	return strippedString;
	
}//end stringByRemovingWhitespace


@end

