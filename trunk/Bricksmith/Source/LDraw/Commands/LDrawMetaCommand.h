//==============================================================================
//
// File:		LDrawMetaCommand.m
//
// Purpose:		Basic holder for a meta-command.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDirective.h"


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawMetaCommand
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawMetaCommand : LDrawDirective
{
	NSString		*commandString;
}

// Initialization
- (BOOL) finishParsing:(NSScanner *)scanner;

// Directives
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor;
- (NSString *) write;

//Accessors
-(void) setStringValue:(NSString *)newString;
-(NSString *) stringValue;

@end
