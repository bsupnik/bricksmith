//
//  PartCatalogBuilder.h
//  Bricksmith
//
//  Created by Allen Smith on 1/6/22.
//

#import <Foundation/Foundation.h>

//------------------------------------------------------------------------------
///
/// @class		PartCatalogBuilder
///
/// @abstract	Scans the LDraw folder for a list of all available parts and
/// 			categories. 
///
//------------------------------------------------------------------------------
@interface PartCatalogBuilder : NSObject

- (void) makePartCatalogWithMaxLoadCountHandler:(void (^)(NSUInteger maxPartCount))maxLoadCountHandler
					   progressIncrementHandler:(void (^)())progressIncrementHandler
							  completionHandler:(void (^)(NSDictionary<NSString*, id> *newCatalog))completionHandler;

@end
