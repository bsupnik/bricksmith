//==============================================================================
//
// File:		LDrawMPDModel.h
//
// Purpose:		Represents a model which can be used as a submodel within a file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "LDrawModel.h"

@interface LDrawMPDModel : LDrawModel <NSCoding>
{
	//MPD submodels have a name to identify them.
	// it gets written out as 0 FILE modelName at the beginning.
	NSString		*modelName;
	
}

+ (id) model;

// Directives
- (NSString *) writeModel;

// Accessors
- (NSString *) modelDisplayName;
- (NSString *)modelName;
- (void) setModelDisplayName:(NSString *)newDisplayName;
- (void) setModelName:(NSString *)newModelName;

// Utilities
+ (NSString *) ldrawCompliantNameForName:(NSString *)newDisplayName;

@end
