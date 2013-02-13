//
// Created by rmacharg on 14/12/2012.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


@interface ComputationalGeometry : NSObject

+(NSMutableArray *)prepareHullData:(NSMutableArray *)directives;
+(void)doJarvisMarch:(NSMutableArray *)preparedData;

@end