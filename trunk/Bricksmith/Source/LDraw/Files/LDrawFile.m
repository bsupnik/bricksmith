//==============================================================================
//
// File:		LDrawFile.h
//
// Purpose:		Represents an LDraw file, composed of one or more models.
//				In Bricksmith, each file is interpreted as a Multi-Part Document
//				having multiple submodels. Only LDrawMPDModels can be contained 
//				in the file's subdirective array. However, when the document is 
//				written out, the MPD commands are stripped if there is only 
//				one model in the file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawFile.h"

#if USE_BLOCKS
#import <dispatch/dispatch.h>
#endif

#import "MacLDraw.h"
#import "LDrawMPDModel.h"
#import "LDrawPart.h"
#import "LDrawUtilities.h"
#import "PartReport.h"
#import "StringCategory.h"
#import "LDrawLSynthDirective.h"


@implementation LDrawFile

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- file ----------------------------------------------------[static]--
//
// Purpose:		Creates a new LDraw document ready for editing. It should 
//				include one submodel with one step inside it.
//
//------------------------------------------------------------------------------
+ (LDrawFile *) file
{
	LDrawFile       *newFile    = [[LDrawFile alloc] init];
	LDrawMPDModel   *firstModel = [LDrawMPDModel model];
	
	//Fill it with one empty model.
	[newFile addSubmodel:firstModel];
	[newFile setActiveModel:firstModel];
	
	return newFile;
	
}//end file


//---------- fileFromContentsAtPath: ---------------------------------[static]--
//
// Purpose:		Reads a file from the specified path. 
//
//------------------------------------------------------------------------------
+ (LDrawFile *) fileFromContentsAtPath:(NSString *)path
{
	NSString	*fileContents	= [LDrawUtilities stringFromFile:path];
	LDrawFile	*parsedFile		= nil;
	
	if(fileContents != nil)
	{
		parsedFile = [LDrawFile parseFromFileContents:fileContents];
		[parsedFile setPath:path];
	}
		
	return parsedFile;
	
}//end fileFromContentsAtPath:


//---------- parseFromFileContents: ----------------------------------[static]--
//
// Purpose:		Reads a file out of the raw file contents. 
//
//------------------------------------------------------------------------------
+ (LDrawFile *) parseFromFileContents:(NSString *) fileContents
{
	LDrawFile   *newFile    = nil;
	NSArray     *lines      = [fileContents separateByLine];
	
	newFile = [[LDrawFile alloc] initWithLines:lines
									   inRange:NSMakeRange(0, [lines count]) ];
	
	return newFile;
	
}//end parseFromFileContents:allowThreads:


#pragma mark -

//========== init ==============================================================
//
// Purpose:		Creates a new file with absolutely nothing in it.
//
//==============================================================================
- (id) init
{
	self = [super init]; //initializes an empty list of subdirectives--in this 
	// case, the models in the file.
	
	activeModel = nil;
	
	return self;
	
}//end init

//========== updateModelLookupTable ============================================
//
// Purpose:		Rebuilds the optimized lookup table for models.  This is now
//				an internal method, run when we add or remove a directive,
//				after coder init, and any time one of our children renames 
//				itself.
//
//==============================================================================
- (void) updateModelLookupTable
{
	NSArray 		*submodels	= [self submodels];
	NSMutableArray	*names		= [NSMutableArray arrayWithCapacity:[submodels count]];
	
	for(LDrawMPDModel *model in submodels)
	{
		// always use lowercase for comparison
		[names addObject:[[model modelName] lowercaseString]];
	}
	
	self->nameModelDict = [[NSDictionary alloc] initWithObjects:submodels forKeys:names];
}



//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Parses the MPD models out of the lines. If lines contains a 
//				single non-MPD model, it will be wrapped in an MPD model. 
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSRange					modelRange      = range;
	NSUInteger				modelStartIndex = range.location;
	__strong LDrawMPDModel  **submodels     = NULL;
	NSUInteger				insertIndex     = 0;
	
	self = [super initWithLines:lines inRange:range parentGroup:parentGroup];
	if(self)
	{
		// Creation a C array of retained pointers under ARC
		// (see Transitioning to ARC Release Notes for details)
		submodels = (__strong LDrawMPDModel **)calloc(range.length, sizeof(LDrawMPDModel *));
		dispatch_group_t    dispatchGroup = NULL;
#if USE_BLOCKS		
		dispatch_queue_t    queue           = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);	
							dispatchGroup   = dispatch_group_create();

		if(parentGroup != NULL)
			dispatch_group_enter(parentGroup);
#endif
														
		// Search through all the lines in the file, and separate them out into 
		// submodels.
		do
		{
			modelRange  = [LDrawMPDModel rangeOfDirectiveBeginningAtIndex:modelStartIndex
																  inLines:lines
																 maxIndex:NSMaxRange(range) - 1];
			// Parse
#if USE_BLOCKS			
			dispatch_group_async(dispatchGroup, queue,
			^{
#endif			
				LDrawMPDModel *newModel    = [[LDrawMPDModel alloc] initWithLines:lines inRange:modelRange parentGroup:dispatchGroup];
				
				// Store non-retaining, but *thread-safe* container 
				// (NSMutableArray is NOT). Since it doesn't retain, we mustn't 
				// autorelease newDirective. 
				submodels[insertIndex] = newModel;
#if USE_BLOCKS
			});
#endif			
			
			modelStartIndex = NSMaxRange(modelRange);
			insertIndex     += 1;
		}
		while(modelStartIndex < NSMaxRange(range));

#if USE_BLOCKS		
		dispatch_group_notify(dispatchGroup,queue,
		^{
#endif		
				NSUInteger      counter         = 0;
				LDrawMPDModel   *currentModel   = nil;
		
			// Add all the models in order
			for(counter = 0; counter < insertIndex; counter++)
			{
				currentModel = submodels[counter];
				
				[self addSubmodel:currentModel];
				
				// Tell ARC to release the object
				submodels[counter] = nil;
			}
			
			if([[self submodels] count] > 0)
				[self setActiveModel:[[self submodels] objectAtIndex:0]];

			free(submodels);

#if USE_BLOCKS			
			if(parentGroup != NULL)
				dispatch_group_leave(parentGroup);
			
		});
#endif		
	}
	
	
	return self;

}//end initWithLines:inRange:


//========== initWithCoder: ====================================================
//
// Purpose:		Reads a representation of this object from the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	//We don't encode the active model; it is just assumed to be the first 
	// model each time the file is created.
	LDrawMPDModel *firstModel = [[self submodels] objectAtIndex:0];
	[self setActiveModel:firstModel];
	
	[self updateModelLookupTable];
	
	return self;
	
}//end initWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawFile   *copiedFile         = (LDrawFile *)[super copyWithZone:zone];
	NSInteger   indexOfActiveModel  = [self indexOfDirective:self->activeModel];
	id          copiedActiveModel   = [[copiedFile subdirectives] objectAtIndex:indexOfActiveModel];
	
	[copiedFile setActiveModel:copiedActiveModel];
	
	return copiedFile;
	
}//end copyWithZone:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Draw only the active model. The other submodels in an MPD file 
//				are only meant to be seen when they are are referenced from the 
//				active submodel.
//
// Threading:	Drawing and editing are mutually-exclusive tasks. However, 
//				drawing and drawing are NOT exclusive. So, we maintain a lock 
//				here which keeps track of the number of threads that are 
//				currently drawing the File. The mutex is never locked DURING a 
//				draw, so we can have as many simultaneous drawing threads as we 
//				please. However, an editing task would request this lock with a 
//				condition (draw count) of 0, and not unlock until editing is 
//				complete. Thus, no draws can happen during that time.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	//
	// Draw!
	//	(only the active model.)
	//
	[activeModel draw:optionsMask viewScale:scaleFactor parentColor:parentColor];

}//end draw:viewScale:parentColor:


//========== drawSelf: ===========================================================
//
// Purpose:		Draw this directive and its subdirectives by calling APIs on 
//				the passed in renderer, then calling drawSelf on children.
//
//================================================================================
- (void) drawSelf:(id<LDrawRenderer>)renderer
{
	[activeModel drawSelf:renderer];
}//end drawSelf:


//========== collectSelf: ========================================================
//
// Purpose:		Collect self is called on each directive by its parents to
//				accumulate _mesh_ data into a display list for later drawing.
//				The collector protocol passed in is some object capable of 
//				remembering the collectable data.
//
// Notes:		The file should never be 'collected', because parts do not 
//				reference files - rather they reference the models WITHIN
//				files.  So while we have a release implementation of passing
//				the message on, we have an assert to catch this case.
//
//================================================================================
- (void) collectSelf:(id<LDrawCollector>)renderer
{
	assert(!"Why are we here?");
	[activeModel collectSelf:renderer];
}//end collectSelf:


//========== debugDrawboundingBox ==============================================
//
// Purpose:		Draw a translucent visualization of our bounding box to test
//				bounding box caching.
//
//==============================================================================
- (void) debugDrawboundingBox
{
	[activeModel debugDrawboundingBox];
}//end debugDrawboundingBox


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Hit-test the geometry.
//
//==============================================================================
- (void) hitTest:(Ray3)pickRay
	   transform:(Matrix4)transform
	   viewScale:(float)scaleFactor
	  boundsOnly:(BOOL)boundsOnly
	creditObject:(id)creditObject
			hits:(NSMutableDictionary *)hits
{
	[activeModel hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
//
// Purpose:		Check for intersections with screen-space geometry.
//
//==============================================================================
- (BOOL)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	return [activeModel boxTest:bounds transform:transform boundsOnly:boundsOnly creditObject:creditObject hits:hits];
}//end boxTest:transform:boundsOnly:creditObject:hits:


//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
//
// Purpose:		depthTest finds the closest primitive (in screen space) 
//				overlapping a given point, as well as its device coordinate
//				depth.
//
//==============================================================================
- (void)	depthTest:(Point2) pt 
				inBox:(Box2)bounds 
			transform:(Matrix4)transform 
		 creditObject:(id)creditObject 
		   bestObject:(id *)bestObject 
			bestDepth:(float *)bestDepth
{
	[activeModel depthTest:pt inBox:bounds transform:transform creditObject:creditObject bestObject:bestObject bestDepth:bestDepth];
}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


//========== write =============================================================
//
// Purpose:		Write out all the submodels sequentially.
//
//==============================================================================
- (NSString *) write
{
	NSMutableString *written        = [NSMutableString string];
	NSString        *CRLF           = [NSString CRLF];
	LDrawMPDModel   *currentModel   = nil;
	NSArray         *modelsInFile   = [self subdirectives];
	NSInteger       numberModels    = [modelsInFile count];
	NSInteger       counter         = 0;
	
	//If there is only one submodel, this hardly qualifies as an MPD document.
	// So write out the single model without the MPD FILE/NOFILE wrapper.
	if(numberModels == 1)
	{
		currentModel = [modelsInFile objectAtIndex:0];
		//Write out the model, without MPD wrappers.
		[written appendString:[currentModel writeModel]];
	}
	else
	{
		//Write out each MPD submodel, one after another.
		for(counter = 0; counter < numberModels; counter++){
			currentModel = [modelsInFile objectAtIndex:counter];
			[written appendString:[currentModel write]];
			[written appendString:CRLF];
		}
	}
	
	//Trim off any final newline characters.
	return [written stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
}//end write


#pragma mark -


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== activeModel =======================================================
//
// Purpose:		Returns the name of the currently-active model in the file.
//
//==============================================================================
- (LDrawMPDModel *) activeModel
{
	return activeModel;
	
}//end activeModel


//========== firstModel =======================================================
//
// Purpose:		Returns the first model in the file, which is the one to use
//				when referred to from a separate peer file.
//
//==============================================================================
- (LDrawMPDModel *) firstModel
{
	return [[self subdirectives] objectAtIndex:0];
	
}//end firstModel



//========== draggingDirectives ================================================
//
// Purpose:		Returns the objects that are currently being displayed as part 
//			    of drag-and-drop. 
//
//==============================================================================
- (NSArray *) draggingDirectives
{
	return [[self activeModel] draggingDirectives];
	
}//end draggingDirectives


//========== modelNames ========================================================
//
// Purpose:		Returns the the names of all the submodels in the file.
//
//==============================================================================
- (NSArray *) modelNames
{
	NSArray         *submodels      = [self subdirectives];
	NSInteger       numberModels    = [submodels count];
	LDrawMPDModel   *currentModel   = nil;
	NSMutableArray  *modelNames     = [NSMutableArray array];
	NSInteger       counter         = 0;
	
	for(counter = 0; counter < numberModels; counter++)
	{
		currentModel = [submodels objectAtIndex:counter];
		[modelNames addObject:[currentModel modelName]];
	}
	
	return modelNames;
	
}//end modelNames


//========== modelWithName: ====================================================
//
// Purpose:		Returns the submodel with the given name, or nil if one couldn't 
//				be found.
//
//==============================================================================
- (LDrawMPDModel *) modelWithName:(NSString *)soughtName
{
	NSString		*referenceName	= [soughtName lowercaseString]; // we standardized on lower-case names for searching.
	LDrawMPDModel	*foundModel 	= [self->nameModelDict objectForKey:referenceName];
	
	return foundModel;
	
}//end modelWithName:


//========== path ==============================================================
//
// Purpose:		Returns the filesystem path at which this file was resides, or 
//				nil if that information is undetermined. Only files that are 
//				read by the user will have their paths set; parts from the 
//				library disregard this information.
//
//==============================================================================
- (NSString *)path
{
	return self->filePath;
	
}//end path


//========== submodels =========================================================
//
// Purpose:		Returns an array of the LDrawModels (or more likely, the 
//				LDrawMPDModels) which constitute this file.
//
//==============================================================================
- (NSArray *) submodels
{
	return [self subdirectives];
	
}//end submodels


#pragma mark -

//========== setActiveModel: ===================================================
//
// Purpose:		Sets newModel to be the currently-active model in the file. 
//				The active model is the only one drawn.
//
//==============================================================================
- (void) setActiveModel:(LDrawMPDModel *)newModel
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	if([[self subdirectives] containsObject:newModel])
	{
		//Don't bother doing anything if we aren't really changing models.
		if(newModel != activeModel)
		{
			//Update the active model and note that something happened.
			activeModel = newModel;
			if(postsNotifications)
				[notificationCenter postNotificationName:LDrawFileActiveModelDidChangeNotification
												  object:self];
		}
	}
	else if (newModel == nil)
	{
		activeModel = nil;
	}
	else
		NSLog(@"Attempted to set the active model to one which is not in the file!");
		
}//end setActiveModel:


//========== setDraggingDirectives: ============================================
//
// Purpose:		Sets the parts which are being manipulated in the model via 
//			    drag-and-drop. 
//
// Notes:		This is a convenience method for LDrawGLView, which might not 
//			    care to wonder whether it's displaying a model or a file. In 
//			    either event, we just want to drag-and-drop, and that's defined 
//			    in the model. 
//
//==============================================================================
- (void) setDraggingDirectives:(NSArray *)directives
{
	[[self activeModel] setDraggingDirectives:directives];
	
}//end setDraggingDirectives:


//========== setEnclosingDirective: ============================================
//
// Purpose:		In other containers, this method would set the object which 
//				encloses this one. LDrawFiles, however, are intended to be at 
//				the root of the LDraw container hierarchy, and thus calling this 
//				method should have no effect.
//
//==============================================================================
- (void) setEnclosingDirective:(LDrawContainer *)newParent
{
	// Do Nothing.
	
}//end setEnclosingDirective:


//========== setPath: ==========================================================
//
// Purpose:		Sets the filesystem path at which this file was resides. Only 
//				files that are read by the user will have their paths set; parts 
//				from the library disregard this information.
//
//==============================================================================
- (void) setPath:(NSString *)newPath
{
	self->filePath = newPath;
	
}//end setPath:


//========== removeDirective: ==================================================
//
// Purpose:		In other containers, this method would set the object which 
//				encloses this one. LDrawFiles, however, are intended to be at 
//				the root of the LDraw container hierarchy, and thus calling this 
//				method should have no effect.
//
//==============================================================================
- (void) removeDirective:(LDrawDirective *)doomedDirective
{
	BOOL removedActiveModel = NO;
	
	if(doomedDirective == self->activeModel)
		removedActiveModel = YES;
		
	[super removeDirective:doomedDirective];
	
	if(removedActiveModel == YES) {
		if([[self submodels] count] > 0)
			[self setActiveModel:[[self submodels] objectAtIndex:0]];
		else
			[self setActiveModel:nil]; //this is probably not a good thing.
	}
	
}//end removeDirective:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== addSubmodel: ======================================================
//
// Purpose:		Adds a new submodel to the file. This method only accepts MPD 
//				models, because adding additional submodels is meaningless 
//				outside of MPD models.
//
//==============================================================================
- (void) addSubmodel:(LDrawMPDModel *)newSubmodel
{
	[self insertDirective:newSubmodel atIndex:[[self subdirectives] count]];
	
}//end addSubmodel:


//========== insertDirective:atIndex: ==========================================
//
// Purpose:		Adds directive into the collection at position index.
//
//==============================================================================
- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index
{
	[super insertDirective:directive atIndex:index];
	[self updateModelLookupTable];
	
	// Post a notification on ourself that a model was added - missing parts need
	// to know this to re-check whether they match this model.
	[[NSNotificationCenter defaultCenter]
			postNotificationName:LDrawMPDSubModelAdded object:self ];
	
}//end insertDirective:atIndex:


//========== removeDirectiveAtIndex: ===========================================
//
// Purpose:		Removes the LDraw directive stored at index in this collection.
//
//==============================================================================
- (void) removeDirectiveAtIndex:(NSInteger)index
{
	[super removeDirectiveAtIndex:index];
	[self updateModelLookupTable];
	
}//end removeDirectiveAtIndex:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== acceptsDroppedDirective: ==========================================
//
// Purpose:		Returns YES if this container will accept a directive dropped on
//              it.  Explicitly excludes LDrawLSynthDirectives such as INSIDE/OUTSIDE
//
//==============================================================================
-(BOOL)acceptsDroppedDirective:(LDrawDirective *)directive
{
    // explicitly disregard LSynth directives
    if ([directive isKindOfClass:[LDrawLSynthDirective class]]) {
        return NO;
    }
    return YES;
}

//========== boundingBox3 ======================================================
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains the part of this file being displayed.
//
//==============================================================================
- (Box3) boundingBox3
{
	[self revalCache:CacheFlagBounds];
	Box3 ret = [[self activeModel] boundingBox3];
	return ret;
	
}//end boundingBox3


//========== projectedBoundingBoxWithModelView:projection:view: ================
//
// Purpose:		Returns the 2D projection (you should ignore the z) of the 
//				object's bounds. 
//
//==============================================================================
- (Box3) projectedBoundingBoxWithModelView:(Matrix4)modelView
								projection:(Matrix4)projection
									  view:(Box2)viewport;
{
	return [[self activeModel] projectedBoundingBoxWithModelView:modelView
													  projection:projection
															view:viewport];
	
}//end projectedBoundingBoxWithModelView:projection:view:


//========== optimizeStructure =================================================
//
// Purpose:		Arranges the directives in such a way that the file will be 
//				drawn faster. This method should *never* be called on files 
//				which the user has created himself, since it reorganizes the 
//				file contents. It is intended only for parts read from the part  
//				library.
//
//==============================================================================
- (void) optimizeStructure
{
	LDrawMPDModel   *currentModel   = nil;
	NSArray         *modelsInFile   = [self subdirectives];
	NSInteger       numberModels    = [modelsInFile count];
	NSInteger       counter         = 0;
	
	//Write out each MPD submodel, one after another.
	for(counter = 0; counter < numberModels; counter++)
	{
		currentModel = [modelsInFile objectAtIndex:counter];
		[currentModel optimizeStructure];
	}

}//end optimizeStructure


//========== renameModel:toName: ===============================================
//
// Purpose:		Sets the name of the given member submodel to the new name, and 
//				updates all internal references to the submodel to use the new 
//				name as well. 
//
//==============================================================================
- (void) renameModel:(LDrawMPDModel *)submodel
			  toName:(NSString *)newName
{
	NSArray     *submodels          = [self submodels];
	BOOL        containsSubmodel    = ([submodels indexOfObjectIdenticalTo:submodel] != NSNotFound);
	NSString    *oldName            = [submodel modelName];
	PartReport  *partReport         = nil;
	NSArray     *allParts           = nil;
	LDrawPart   *currentPart        = nil;
	NSInteger   counter             = 0;

	if(		containsSubmodel == YES
	   &&	[oldName isEqualToString:newName] == NO )
	{
		// Update the model name itself
		[submodel setModelName:newName];
		
		// Update all references to the old name
		partReport	= [PartReport partReportForContainer:self];
		allParts	= [partReport allParts];
		
		for(counter = 0; counter < [allParts count]; counter++)
		{
			currentPart = [allParts objectAtIndex:counter];
			
			// If the part points to the old name, change it to the new one.
			// Since the user can enter these values and Bricksmith is 
			// case-insensitive, make sure to ignore case. 
			if([[currentPart referenceName] caseInsensitiveCompare:oldName] == NSOrderedSame)
			{
				[currentPart setDisplayName:newName];
			}
		}
	}
	
}//end renameModel:toName:


#pragma mark -
#pragma mark OBSERVATION
#pragma mark -


//========== receiveMessage:who: ===============================================
//
// Purpose:		LDrawFile overrides the message handler to get access to name
//				change announcements from its contained MDP models.  In this
//				way it can rebuild the lookup table.
//
// Notes:		Someday if we want to get clever we could rebuild only part
//				of the lookup table based on the actual object that changed.
//				But since renames are rare it's probably not worth it.
//
//==============================================================================
- (void) receiveMessage:(MessageT) msg who:(id<LDrawObservable>) observable
{
	if (msg == MessageNameChanged)
		[self updateModelLookupTable];
		
	[super receiveMessage:msg who:observable];
}


@end
