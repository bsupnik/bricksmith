//==============================================================================
//
// File:		ModelManager.m
//
// Purpose:		The model manager maintains a database of loaded models from
//				other files for use by documents the users are editing.
//
//  Created by bsupnik on 8/20/12.
//  Copyright 2012, All rights reserved.
//==============================================================================

#import "ModelManager.h"
#import "StringCategory.h"
#import "LDrawFile.h"
#import "LDrawMPDModel.h"
#import "LDrawUtilities.h"

// ModelManager Implementation:
//
// A "service table" is the object allocated for each signed in model to keep
// track of the peer models that have been loaded for it.  The service table
// contains a directory listing and a list of files we've opened for the client.
//
// Note that each time a service table opens a model, that model in turn gets
// a service table!  This is how recursive resolution of models works.


////////////////////////////////////////////////////////////////////////////////
//
// ModelManager private API
//
////////////////////////////////////////////////////////////////////////////////
@interface ModelManager (private)

// Internal API: when the model manager has to open a file to resolve a peer model,
// it has to start service on THAT model too to make recursive peer files work!
// The formula for this is a little bit different than the case when a user-edited 
// document is opened.
- (void) documentSignInInternal:(NSString *) docPath withFile:(LDrawFile *) file;

@end


////////////////////////////////////////////////////////////////////////////////
//
// ModelServicesTable
//
////////////////////////////////////////////////////////////////////////////////
@interface ModelServiceTable : NSObject {

@public
	LDrawFile *				file;
	NSString *				fileName;
	NSString *				parentDirectory;

	NSMutableSet *			peerFileNames;		// NSString * filename
	NSMutableDictionary *	trackedFiles;		// NSString * filename -> LDrawFile* modelfile
}

- (id)			initWithFileName:(NSString *) fileName parentDir:(NSString *) parentDir file:(LDrawFile *) file;
- (void)		dealloc;
- (LDrawFile *) beginService:(NSString *) fileName;
- (BOOL)		dropService:(NSString *) fileName;		// Returns true if it realLy did find this thing and drop it!

@end

@implementation ModelServiceTable


//========== initWithFileName:parentDir:file ===================================
//
// Purpose:		Create a service table and prepare it for use.
//
// Notes:		The service table grabs the directory contents once and stashes
//				it.  Someday we should be checking for file system changes and
//				updating the table to note when new files pop up.
//
//==============================================================================
- (id) initWithFileName:(NSString *) inFileName parentDir:(NSString *) inParentDir file:(LDrawFile *) inFile;
{
	//NSLog(@"Starting service on file %p as %@/%@\n",inFile,inParentDir,inFileName);
	self = [super init];
	
	//NSLog(@"Init service table %p\n", self);
	self->file				= inFile;
	self->fileName			= [inFileName retain];
	self->parentDirectory	= [inParentDir retain];
	
	NSFileManager	*fileManager	= [[[NSFileManager alloc] init] autorelease];
	NSArray 		*partNames		= [fileManager contentsOfDirectoryAtPath:inParentDir error:NULL];
	
	// Must use reference-style names. Peer file names are only cached for the 
	// purposes of finding whether or not a part references a peer file. 
	partNames = [partNames valueForKey:@"lowercaseString"];
	
	peerFileNames	= [[NSMutableSet alloc] initWithArray:partNames];
	trackedFiles	= [[NSMutableDictionary alloc] init];
	
	//NSLog(@"Found %d peers.\n", [self->peerFileNames count]);

	return self;
}


//========== dealloc ==========================================================
//
// Purpose:		Goodbye cruel world, I'm leaving you today....
//
// Notes:		Open issue: do we really need to send the message-scope-changed
//				instruction here?  Yes.  Even though in theory the model should
//				signal when it goes away, in practice the model might be in an
//				auto-release pool and thus it's lifetime lives on.  We can't 
//				use obj lifetime for management here, so we manually signal.
//
//==============================================================================
- (void) dealloc
{
	//NSLog(@"Nuking sevice table %p\n",self);
	
	// Go through all tracked files and tell their first model's clients that
	// they are going away.  
	for(NSString * partName in trackedFiles)
	{
		LDrawFile * deadFile = [trackedFiles objectForKey:partName];		
		[[deadFile firstModel] sendMessageToObservers:MessageScopeChanged];
		[[ModelManager sharedModelManager] documentSignOut:deadFile];

	}
	
	[peerFileNames release];
	// When we nuke the trackedFiles we release our retain count on the 
	// LDrawFiles.
	[trackedFiles release];
	[fileName release];
	[parentDirectory release];

	//NSLog(@"%p Gone\n",self);	
	[super dealloc];
}


//========== beginService ======================================================
//
// Purpose:		Grab a peer model from a peer file for a client.
//
//==============================================================================
- (LDrawFile *) beginService:(NSString *) inFileName
{
	//NSLog(@"%p: Loading model for part name: %@\n", self, inFileName);

	NSString *		fullPath	= [parentDirectory stringByAppendingPathComponent:inFileName];
	NSFileManager * fileManager = [[[NSFileManager alloc] init] autorelease];

	fullPath = [fullPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];

	// Quick check whether the file is still there.
	if (![fileManager fileExistsAtPath:fullPath])
		return nil;
	
	NSString *	fileContents	= [LDrawUtilities stringFromFile:fullPath];
	NSArray *	lines			= [fileContents separateByLine];		
	
	dispatch_group_t group = NULL;
#if USE_BLOCKS
	group           = dispatch_group_create();
#endif
	
	LDrawFile * parsedFile = [[LDrawFile alloc] initWithLines:lines
												   inRange:NSMakeRange(0, [lines count])
											   parentGroup:group];
	
#if USE_BLOCKS
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	dispatch_release(group);
#endif	
	if(parsedFile)
	{
		[parsedFile setPath:fullPath];
		[trackedFiles setObject:parsedFile forKey:inFileName];
		[parsedFile release];			// Hash table tracked files retains the ONLY
										// ref count - our "init" ref count gets tossed!
		
		// The model we just opened (to help the user's doc) might in turn refer to yet more 
		// peer files, so recursively open service on it.  The "internal" version won't freak
		// out that another document owns us.
		[[ModelManager sharedModelManager] documentSignInInternal:fullPath withFile:parsedFile];		
	}
	

	//NSLog(@"   Loaded %p\n", parsedFile);
	return parsedFile;
}


//========== dropService ======================================================
//
// Purpose:		Release a file used by a client.
//
// Returns:		True if we had that file open and had to close it, false if we
//				were not using it at all.
//
// Notes:		Clients don't announce that they are done with a part.  This 
//				call comes from the model manager itself; when a user opens a
//				second document, the model manager drops any files that 
//				duplicate that doc.
//
//==============================================================================
- (BOOL)	dropService:(NSString *) inFileName
{
	LDrawFile * deadFile = [trackedFiles objectForKey:inFileName];
	if(deadFile)
	{
		//NSLog(@"%p: drop sevice for %@\n", self,inFileName);		
		[[deadFile firstModel] sendMessageToObservers:MessageScopeChanged];

		// This releases any files that deadFile was in tunr using.
		[[ModelManager sharedModelManager] documentSignOut:deadFile];

		[trackedFiles removeObjectForKey:inFileName];

		return TRUE;
	}
	return FALSE;
}

@end


@implementation ModelManager

static ModelManager *SharedModelManager = nil;

//========== sharedModelManager ====================================[static]====
//
// Purpose:		return the singleton model manager.
//
//==============================================================================
+ (ModelManager *)	sharedModelManager
{
	if(SharedModelManager == nil)
	{
		SharedModelManager = [[ModelManager alloc] init];
	}
	
	return SharedModelManager;
}


//========== init ==============================================================
//
// Purpose:		initialize the model manager.
//
//==============================================================================
- (id) init
{
	self = [super init];	
	serviceTables = [[NSMutableDictionary alloc] init];	
	dirChars = [[NSCharacterSet characterSetWithCharactersInString:@"\\/"] retain];
	return self;
}


//========== dealloc ===========================================================
//
// Purpose:		This is the end...my beautiful friend...the end...
//
//==============================================================================
- (void) dealloc
{
	//NSLog(@"model mgr gone - why?\n");
//	for(NSValue * key in serviceTables)
//	{
//		LDrawFile * f = [key pointerValue];
//		[f release];
//	}
	[serviceTables release];
	[dirChars release];
	[super dealloc];
}



//========== documentSignIn:withFile ===========================================
//
// Purpose:		Begin providing model-finding services for a new file.
//
// Notes:		This is the public sign-in method.  It will close the file if 
//				it is open to someone else, then swap in the user's doc.
//
//==============================================================================
- (void) documentSignIn:(NSString *) docPath withFile:(LDrawFile *) file
{
	if([serviceTables objectForKey:[NSValue valueWithPointer:file]] != nil)
		return;

	//NSLog(@"Accepting sign-in of document %@ as file %p\n", docPath, file);

	NSString *	docParentDir	= [docPath stringByDeletingLastPathComponent];
	NSString *	docFileName 	= [docPath lastPathComponent];
	
	// First: go figure out if we were providing this ldraw file for some other document.
	// If so, we really need to drop it!
	
	// Two bits of chaos:
	// 1. While we walk the service table to see if the document coming in was opened as a peer
	// to someone else we may close that document.  If we do, we drop that doc's service table
	// which mutates the collection.  So for now we hack and just restart the search.
	// 2. This restart is needed anyway, because closing a doc might cause a chain reaction
	// of service roll-ups.
	
	bool did_drop = false;
	do {
		did_drop = false;
		
		for(NSValue * key in serviceTables)
		{
			ModelServiceTable * table = [serviceTables objectForKey:key];
			if([docParentDir isEqualToString:table->parentDirectory])
			{
				//NSLog(@"Open document %@/%@ had to drop service on peer %@\n", table->parentDirectory, table->fileName, docFileName);
				if([table dropService:docFileName])
				{
					did_drop = true;
					break;
				}
			}
		}		
	} while(did_drop);
	
	ModelServiceTable * newTable = [[ModelServiceTable alloc] initWithFileName:docFileName parentDir:docParentDir file:file];	
	[serviceTables setObject:newTable forKey:[NSValue valueWithPointer:file]];
	[newTable release];
}


//========== documentSignInInternal:withFile ===================================
//
// Purpose:		Begin providing model-finding services for a new file.
//
// Notes:		Recursive sign-in.  This is called for files opened not by the
//				user but by the model manager itself in reponse to a part.
//
//==============================================================================
- (void) documentSignInInternal:(NSString *) docPath withFile:(LDrawFile *) file
{
	if([serviceTables objectForKey:[NSValue valueWithPointer:file]] != nil)
		return;

	//NSLog(@"Accepting sign-in of document %@ as file %p\n", docPath, file);

	NSString *	docParentDir	= [docPath stringByDeletingLastPathComponent];
	NSString *	docFileName 	= [docPath lastPathComponent];
	
	ModelServiceTable * newTable = [[ModelServiceTable alloc] initWithFileName:docFileName parentDir:docParentDir file:file];	
	[serviceTables setObject:newTable forKey:[NSValue valueWithPointer:file]];
	[newTable release];
}


//========== documentSignOut ===================================================
//
// Purpose:		Release models and internal resources being used by a document.
//
// Notes:		This can be called recursively, from a table being torn down.
//
//==============================================================================
- (void) documentSignOut:(LDrawFile *) doc
{
	ModelServiceTable * t = [serviceTables objectForKey:[NSValue valueWithPointer:doc]];
	if(t)
	{
		//NSLog(@"Accepting sign-out for doc %p\n", doc);
		[serviceTables removeObjectForKey:[NSValue valueWithPointer:doc]];
	}
}


//========== requestModel:withDocument =========================================
//
//	Purpose:	Locate and return a model from a file in the same directory as
//				the client file who is asking.
//
//	Notes:		This routine will first look for other open documents; if there
//				are none then it will open a model and store it in the service
//				table for the requestor.
//
//==============================================================================
- (LDrawModel *) requestModel:(NSString *) partName withDocument:(LDrawFile *) whoIsAsking
{
	ModelServiceTable * table = [serviceTables objectForKey:[NSValue valueWithPointer:whoIsAsking]];
	if(table == nil) 
	{
		//NSLog(@"    ignoring part lookup on part %@ because file %p is unknown.\n", partName, whoIsAsking);
		return nil;
	}
	//NSLog(@"Part check for known file %@/%@ - wants part %@\n", table->parentDirectory, table->fileName, partName);
	
	NSString *	partDir 		= table->parentDirectory;
	NSString *	partFileName	= partName;

	for(LDrawFile * key in serviceTables)
	{
		ModelServiceTable * otherDoc = [serviceTables objectForKey:key];
		
		if(		[partFileName isEqualToString:otherDoc->fileName]
		   &&	[partDir isEqualToString:otherDoc->parentDirectory])
		{
			//NSLog(@" Part was already loaded - returning.\n");
			return [otherDoc->file firstModel];
		}
	}
	
	LDrawFile * alreadyOpenedFile = [table->trackedFiles objectForKey:partName];
	if (alreadyOpenedFile)
		return [alreadyOpenedFile firstModel];
	
	if (![table->peerFileNames containsObject:partName])
	{
		// Fast case: since we cached our directory, if the part has no relative path
		// and is missing, we can bail now.
		if([partName rangeOfCharacterFromSet:dirChars].location == NSNotFound)
			return nil;
	}
	//NSLog(@" Part may exist - trying to open. - returning.\n");
	
	LDrawFile * justOpenedNow = [table beginService:partName];
	
	if(justOpenedNow)
		return [justOpenedNow firstModel];

	return nil;
}

@end
