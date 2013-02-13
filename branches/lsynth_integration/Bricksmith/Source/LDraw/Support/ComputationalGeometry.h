//==============================================================================
//
// File:		ComputationalGeometry.h
//
// Purpose:		General purpose computational geometry functionality
//
// Created by rmacharg on 14/12/2012.
//==============================================================================

#import <Foundation/Foundation.h>
#import "LDrawPart.h";

@interface ComputationalGeometry : NSObject

+(void)doJarvisMarch:(NSMutableArray *)preparedData;
+(NSMutableArray *)tangentBetweenCircle:(NSMutableDictionary *)c1 andCircle:(NSMutableDictionary *)c2;

@end