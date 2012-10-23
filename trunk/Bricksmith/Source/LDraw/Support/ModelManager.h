//==============================================================================
//
// File:		ModelManager.h
//
// Purpose:		The model manager maintains a database of loaded models from
//				other files for use by documents the users are editing.
//
//
//  Created by bsupnik on 8/20/12.
//  Copyright 2012, All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

@class LDrawModel;
@class LDrawFile;

// Model Manager terminology:
//
// Documents "sign in" and "sign out" with the model manager when they first are
// opened or receive their path.  The document uses its LDrawFile * as its
// identifier.
//
// A signed in document can then request a model based on its "part name" (which
// is really just the file name in its home directory).  The file is loaded 
// and retained by the model manager until the document signs out.
//
// If a requested model changes (e.g. the user opens the requested model and
// thus the existing LDrawFile is thrown out in favor of the one that the user 
// opened) then the client part will receive a notification that its model is
// going away, and the next call to requestModel will return the new correct
// model.


////////////////////////////////////////////////////////////////////////////////
//
// class ModelManager
//
////////////////////////////////////////////////////////////////////////////////
@interface ModelManager : NSObject {

	NSMutableDictionary *	serviceTables;	// Maps NSValue<LDrawfile*> -> ServiceTable.  Service table is in the cpp.
	NSCharacterSet *		dirChars;
}

// Singleton access
+ (ModelManager *)	sharedModelManager;

// Accept docs signing in.  Begin service on their dir with a scan, and sub out any
// previously opened "reference" files.
- (void) documentSignIn:(NSString *) docPath withFile:(LDrawFile *) file;

// Terminate service: close out the file, purge the dir if needed, purge any files they use.
- (void) documentSignOut:(LDrawFile *) doc;

// Signed in document (ID-ed by its ldraw-doc) can request a part by name.
// Code will search its service table and load the part if needed.  The model is
// retained by the model manager until the document signs out.
- (LDrawModel *) requestModel:(NSString *) partName withDocument:(LDrawFile *) whoIsAsking;


@end
