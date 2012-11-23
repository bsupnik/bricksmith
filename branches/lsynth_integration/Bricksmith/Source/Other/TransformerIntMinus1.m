//==============================================================================
//
// File:		TransformerIntMinus1.m
//
// Purpose:		A value transformer that subtracts one from the integer value of 
//				the input.
//
//  Created by Allen Smith on 7/18/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import "TransformerIntMinus1.h"


@implementation TransformerIntMinus1

//---------- allowsReverseTransformation -----------------------------[static]--
//
// Purpose:		Returns whether this class knows how to un-transform its value.
//
//------------------------------------------------------------------------------
+ (BOOL) allowsReverseTransformation
{
	return NO;
	
}//end allowsReverseTransformation


//---------- transformedValueClass -----------------------------------[static]--
//
// Purpose:		Returns the kind of objects we output.
//
//------------------------------------------------------------------------------
+ (Class) transformedValueClass
{
	return [NSNumber class];
	
}//end transformedValueClass


//========== transformedValue: =================================================
//
// Purpose:		Transforms the original value, and returns the result.
//
//==============================================================================
- (id)transformedValue:(id)value
{
	NSInteger intValue = [value integerValue];
	
	return [NSNumber numberWithInteger:(intValue - 1)];
	
}//end transformedValue:


@end
