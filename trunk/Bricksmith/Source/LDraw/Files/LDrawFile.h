//==============================================================================
//
// File:		LDrawFile.h
//
// Purpose:		Represents an LDraw file, composed of one or more models.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "LDrawContainer.h"

// forward declarations
@class LDrawMPDModel;


//Active model changed.
// Object is the LDrawFile in which the model resides. No userInfo.
#define LDrawFileActiveModelDidChangeNotification		@"LDrawFileActiveModelDidChangeNotification"


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawFile
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawFile : LDrawContainer
{
	LDrawMPDModel		*activeModel;
	NSString			*filePath;			//where this file came from on disk.
	NSUInteger			 drawCount;			//number of threads currently drawing us
	NSConditionLock		*editLock;
}

// Initialization
+ (LDrawFile *) file;
+ (LDrawFile *) fileFromContentsAtPath:(NSString *)path;
+ (LDrawFile *) parseFromFileContents:(NSString *) fileContents;

// Directives
- (void) lockForEditing;
- (void) unlockEditor;

// Accessors
- (LDrawMPDModel *) activeModel;
- (void) addSubmodel:(LDrawMPDModel *)newSubmodel;
- (NSArray *) draggingDirectives;
- (NSArray *) modelNames;
- (LDrawMPDModel *) modelWithName:(NSString *)soughtName;
- (NSString *)path;
- (NSArray *) submodels;

- (void) setActiveModel:(LDrawMPDModel *)newModel;
- (void) setDraggingDirectives:(NSArray *)directives;
- (void) setPath:(NSString *)newPath;

// Utilities
- (void) optimizeStructure;
- (void) optimizeVertexes;
- (void) renameModel:(LDrawMPDModel *)submodel toName:(NSString *)newName;

@end
