//==============================================================================
//
// File:		LDrawDirective.m
//
// Purpose:		Base class for all LDraw objects provides a few basic utilities.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDirective.h"

#import "LDrawContainer.h"
#import "LDrawFile.h"
#import "LDrawModel.h"
#import "LDrawStep.h"
	
@implementation LDrawDirective


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Start me up. This should be called before any other subclass 
//				initialization code.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	enclosingDirective = nil;

	#if NEW_SET
		LDrawFastSetInit(observers);
	#else
		observers = [[NSMutableArray alloc] init];
	#endif
	return self;
	
}//end init


//========== initWithLines:inRange: ============================================
//
// Purpose:		Convenience method to perform a blocking parse operation
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
{
	LDrawDirective      *directive  = nil;
	dispatch_group_t    group       = NULL;
	
#if USE_BLOCKS
	group = dispatch_group_create();
#endif

	directive = [self initWithLines:lines inRange:range parentGroup:group];
	
#if USE_BLOCKS
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	dispatch_release(group);
#endif
	
	return directive;
	
}//end initWithLines:inRange:



//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Returns the LDraw directive based on lineFromFile, a single line 
//				of LDraw code from a file.
//
//				This method is intended to be overridden by subclasses.
//				LDrawDirective's implementation simply returns a useless empty 
//				directive.
//
//				A subclass implementation would look something like:
//				---------------------------------------------------------------
//
//				Class LineTypeClass = [LDrawUtilities classForDirectiveBeginningWithLine:lineFromFile];
//				// Then initialize whatever subclass we came up with for this line.
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	self = [self init]; // call basic initializer
	
	if([lines count] == 0)
	{
		[self autorelease];
		self = nil;
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
- (id) initWithCoder:(NSCoder *)decoder
{
	//The superclass doesn't support NSCoding. So we just call the default init.
	self = [super init];

	#if NEW_SET
		LDrawFastSetInit(observers);
	#else
		observers = [[NSMutableArray alloc] init];
	#endif
	
	[self setEnclosingDirective:[decoder decodeObjectForKey:@"enclosingDirective"]];
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void) encodeWithCoder:(NSCoder *)encoder
{
	//self = [super encodeWithCoder:encoder]; //super doesn't implement this method.
	
	//We encode the parent conditionally--it won't actually get encoded unless 
	// someone else encodes the parent unconditionally.
	[encoder encodeConditionalObject:enclosingDirective forKey:@"enclosingDirective"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this object. 
//				This thing has issules. Note caveats in LDrawContainer.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	//Allocate a new instance because we don't inherit -copy: from anybody.
	// Note the code to ensure that the correct subclass is allocated!
	// Since LDrawDirective is the root LDraw class, all [subclass copy] 
	// messages wind up here.
	LDrawDirective *copied = [[[self class] allocWithZone:zone] init];
	
	[copied setEnclosingDirective:nil]; //if that is to be copied, then it should be assigned via accessors.
	[copied setSelected:self->isSelected];
	
	return copied;
	
}//end copyWithZone:


#pragma mark -

//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
//
// Purpose:		Returns the range from the first to the last LDraw line of the 
//				directive which starts at index. 
//
//				This is a core method of the LDraw parser. It allows supporting 
//				multiline directives and parallelization in parsing. 
//
// Parameters:	index	- Index of first line to be considered for the directive
//				lines	- (Potentially) All the lines of the enclosing file. The 
//						  directive is represented by a subset of the lines in 
//						  the range between index and maxIndex. 
//				maxIndex- Index of the last line which could possibly be part of 
//						  the directive. 
//
// Notes:		Subclasses of LDrawDirective override this method. You should 
//				ALWAYS call this method on a subclass. Find the subclass using 
//				+[LDrawUtilities classForDirectiveBeginningWithLine:].
//
//------------------------------------------------------------------------------
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
									 inLines:(NSArray *)lines
									maxIndex:(NSUInteger)maxIndex
{
	// Most LDraw directives are only one line. For those that aren't the 
	// subclass should override this method and perform its own parsing. 
	return NSMakeRange(index, 1);
	
}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Issues the OpenGL code necessary to draw this element.
//
//				This method is intended to be overridden by subclasses.
//				LDrawDirective's implementation does nothing.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor
{
	//subclasses should override this with OpenGL code to draw the line.
	
}//end draw:viewScale:parentColor:


//========== boundingBox3 ======================================================
//
// Purpose:		return the bounds (in model space) of the directive.
//
// Notes:		This routine is cached - the observers have a flag for whether
//				bounding box is invalidated.  Thus implementations that have a
//				sane bounding box should call revalCache before returning a 
//				value.
//
//				Directives that don't have spatial meaning (e.g. hidden 
//				directives and comments) can return InvalidBox.
//
//==============================================================================
- (Box3) boundingBox3
{
	return InvalidBox;
}//end boundingBox3


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Tests the directive and any of its children for intersections 
//				between the pickRay and the directive's drawn content. 
//
// Parameters:	pickRay - in world coordinates
//				transform - transformation to apply to directive points to get 
//						to world coordinates 
//				scaleFactor - the window zoom level (1.0 == 100%)
//				boundsOnly - test the bounding box, rather than the 
//						fully-detailed geometry 
//				creditObject - object which should get credit if the 
//						current object has been hit. (Used to credit nested 
//						geometry to its parent.) If nil, the hit object credits 
//						itself. 
//				hits - keys are hit objects. Values are NSNumbers of hit depths.
//
//==============================================================================
- (void) hitTest:(Ray3)pickRay
	   transform:(Matrix4)transform
	   viewScale:(float)scaleFactor
	  boundsOnly:(BOOL)boundsOnly
	creditObject:(id)creditObject
			hits:(NSMutableDictionary *)hits
{
	//subclasses should override this with hit-detection code
	
}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
//
// Purpose:		Tests the directive and any of its children for intersections 
//				between the directive's drawn form and the bounding box in the
//				XY plane, after perspective divide.
//
// Parameters:	bounds - the box to test against, in post-projection (clip)
//						coordinates
//				transform - transformation to apply to directive points to get 
//						to clip coordinates - perspective divide is required!
//				creditObject - object which should get credit if the 
//						current object has been hit. (Used to credit nested 
//						geometry to its parent.) If nil, the hit object credits 
//						itself. 
//				hits - a set of hit directives that we have accumulated so far
//						this routine adds more as found.
//
// Return:		This function returns true if the _credit object_ was added to 
//				the set.  This allows hierarchies below the credit object to 
//				early-exit.
//
// Notes:		This test is used to do marquee selection - the marquee is
//				converted back from viewport to clip coordinates, and then
//				the primitive is forward-transformed to clip coordinates, for a
//				simple 2-d screen-space test.
//
//				My original attempt to implement this used world-space clip 
//				planes but it is surprisingly expensive to intersect two 3-d 
//				polygons in arbitrary space.  By working in screen space we
//				ensure that the selection box is an axis-aligned bounding box,
//				which greatly simplifies the algorithm.
//
//				(To catch the case where the marquee is fully inside the interior
//				of the primitive, in screen space, but using 3-d primitives, we 
//				have to calculate the union of two convex polyhedra.  That's not
//				that hard but it requires memory allocations...2-d is much 
//				simpler.)
//
//==============================================================================
- (BOOL)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	//subclasses should override this with hit-detection code
	return FALSE;

}//end boxTest:transform:boundsOnly:creditObject:hits:


//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
//
// Purpose:		depthTest finds the closest primitive (in screen space) 
//				overlapping a given point, as well as its device coordinate
//				depth.
//
// Parameters:	pt - the 2-d location (in screen space) to intersect.
//				inBox - a bounding box in XY (in screen space) surrounding the
//						test point.  The size of the box (e.g. how much bigger
//						it is than the point) defines the "slop" for testing
//						infinitely thin primitives like lines and drag handles.
//				transform - a model view and projection matrix to transform from
//						the directive's model coordinates to screen space.
//				creditObject - if not nil, we credit this object with the hit;
//						otherwise we use self.
//				bestObject - a ptr to an object that is rewritten with the new
//						best object if one is found.
//				depth - a ptr to a depth (in normalized device coordinates: -1
//						is max near, 1 is max far) of that best object.  If a
//						hit is recorded, depth is updated.
//
// Notes:		Depth testing uses "replace if closer" semantics to provide
//				return results; thus bestDepth should be initialized to point
//				to 1.0f (the far clip plane) before being called.  The bounding
//				box needs to be enough bigger than the hit point to provide a
//				few pixels of slop.  The depth should be measured at the hit 
//				point.
//
//==============================================================================
- (void)	depthTest:(Point2) pt 
				inBox:(Box2)bounds 
			transform:(Matrix4)transform 
		 creditObject:(id)creditObject 
		   bestObject:(id *)bestObject 
			bestDepth:(float *)bestDepth
{
	// subclasses should override this.

}//end depthTest:inBox:transform: creditObject:bestObject:bestDepth:


//========== write =============================================================
//
// Purpose:		Returns the LDraw code for this directive, which can then be 
//				written out to a LDraw file and read by any LDraw interpreter.
//
//				This method is intended to be overridden by subclasses.
//				LDrawDirective's implementation does nothing.
//
//==============================================================================
- (NSString *) write
{
	//Returns a representation of the line which can be written out to a file.
	return [NSString string]; //empty string; subclasses should override this method.
	
}//end write


#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) browsingDescription
{
	return [NSString stringWithFormat:@"%@", [self class]];
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object.
//
//==============================================================================
- (NSString *) iconName
{
	return @""; //Nothing.
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -


//========== ancestors =========================================================
//
// Purpose:		Returns the ancestors enclosing this directive (as well as the 
//				directive itself), with the oldest ancestor (highest node) at
//				the first index.
//
//==============================================================================
- (NSArray *) ancestors
{
	NSMutableArray *ancestors		= [NSMutableArray arrayWithCapacity:3];
	LDrawDirective *currentAncestor = self;
	
	while(currentAncestor != nil){
		[ancestors insertObject:currentAncestor atIndex:0];
		currentAncestor = [currentAncestor enclosingDirective];
	}
	
	return ancestors;
	
}//end ancestors


//========== enclosingDirective ================================================
//
// Purpose:		Bricksmith imposes a rigid hierarchy on the data in a file:
//
//				LDrawFile
//					|
//					|-----> LDrawMPDModels
//								|
//								|-----> LDrawSteps
//											|
//											|-----> LDrawParts
//											|
//											|-----> LDraw Primitives
//											|
//											|-----> LDrawMetaCommands
//
//				With the exception of LDrawFile at the root, all directives 
//				must be enclosed within another directive. This method returns 
//				the directive in which this one is stored. 
//
// Notes:		LDrawFiles return nil.
//
//==============================================================================
- (LDrawContainer *) enclosingDirective
{
	return enclosingDirective;
	
}//end enclosingDirective


//========== enclosingFile =====================================================
//
// Purpose:		Returns the highest LDrawFile which contains this directive, or 
//				nil if the directive is not in the hierarchy of an LDrawFile.
//
//==============================================================================
- (LDrawFile *) enclosingFile
{
	LDrawDirective	*currentAncestor	= self;
	BOOL			foundIt 			= NO;
	
	while(currentAncestor != nil)
	{
		if([currentAncestor isKindOfClass:[LDrawFile class]])
		{
			foundIt = YES;
			break;
		}
		currentAncestor = [currentAncestor enclosingDirective];
	}
	
	if(foundIt == YES)
		return (LDrawFile *)currentAncestor;
	else
		return nil;
	
}//end enclosingFile


//========== enclosingModel ====================================================
//
// Purpose:		Returns the highest LDrawModel which contains this directive, or 
//				nil if the directive is not in the hierarchy of an LDrawModel.
//
//==============================================================================
- (LDrawModel *) enclosingModel
{
	LDrawDirective	*currentAncestor	= self;
	BOOL			foundIt 			= NO;
	
	while(currentAncestor != nil)
	{
		if([currentAncestor isKindOfClass:[LDrawModel class]])
		{
			foundIt = YES;
			break;
		}
		currentAncestor = [currentAncestor enclosingDirective];
	}
	
	if(foundIt == YES)
		return (LDrawModel *)currentAncestor;
	else
		return nil;
	
}//end enclosingModel


//========== enclosingStep =====================================================
//
// Purpose:		Returns the highest LDrawStep which contains this directive, or 
//				nil if the directive is not in the hierarchy of an LDrawStep.
//
//==============================================================================
- (LDrawStep *) enclosingStep
{
	LDrawDirective	*currentAncestor	= self;
	BOOL			foundIt 			= NO;
	
	while(currentAncestor != nil)
	{
		if([currentAncestor isKindOfClass:[LDrawStep class]])
		{
			foundIt = YES;
			break;
		}
		currentAncestor = [currentAncestor enclosingDirective];
	}
	
	if(foundIt == YES)
		return (LDrawStep *)currentAncestor;
	else
		return nil;
	
}//end enclosingStep


//========== isSelected ========================================================
//
// Purpose:		Returns whether this directive thinks it's selected.
//
//==============================================================================
- (BOOL) isSelected
{
	return self->isSelected;

}//end isSelected


#pragma mark -

//========== setEnclosingDirective: ============================================
//
// Purpose:		Just about all directives can be nested inside another one, so 
//				this is where this method landed.
//
//==============================================================================
- (void) setEnclosingDirective:(LDrawContainer *)newParent
{
	enclosingDirective = newParent;
	
}//end setEnclosingDirective:


//========== setSelected: ======================================================
//
// Purpose:		Somebody make this a protocol method.
//
//==============================================================================
- (void) setSelected:(BOOL)flag
{
	self->isSelected = flag;
	
}//end setSelected:

#pragma mark -
#pragma mark <INSPECTABLE>
#pragma mark -

//========== lockForEditing ====================================================
//
// Purpose:		Provide thread-safety for this object during inspection.
//
//==============================================================================
- (void) lockForEditing
{
	[[self enclosingFile] lockForEditing];
	
}//end lockForEditing


//========== unlockEditor ======================================================
//
// Purpose:		Provide thread-safety for this object during inspection.
//
//==============================================================================
- (void) unlockEditor
{
	[[self enclosingFile] unlockEditor];
	
}//end unlockEditor


#pragma mark -
#pragma mark UTILITIES
#pragma mark -
//This is stuff that didn't really go anywhere else.

//========== containsReferenceTo: ==============================================
//
// Purpose:		Overridden by subclasses to indicate if the object (or any of 
//				its potential children) references a model with the given name. 
//
//==============================================================================
- (BOOL) containsReferenceTo:(NSString *)name
{
	return NO;
}


//========== description =======================================================
//
// Purpose:		Overrides NSObject method to get a more meaningful description 
//				suitable for printing to the console.
//
//==============================================================================
- (NSString *) description
{
	return [NSString stringWithFormat:@"%@\n%@", [self class], [self write]];
	
}//end description


//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
//
// Purpose:		Appends the directive (or a copy of the directive) into the 
//				appropriate container. 
//
// Notes:		This is used to flatten a complicated hiearchy of primitives and 
//				part references to files containing yet more primitives into a 
//				single flat list, which may be drawn to produce a shape visually 
//				identical to the original structure. The flattened structure, 
//				however, has the advantage that it is much faster to traverse 
//				during drawing. 
//
//				This is the core of -[LDrawModel optimizeStructure].
//
//==============================================================================
- (void) flattenIntoLines:(NSMutableArray *)lines
				triangles:(NSMutableArray *)triangles
		   quadrilaterals:(NSMutableArray *)quadrilaterals
					other:(NSMutableArray *)everythingElse
			 currentColor:(LDrawColor *)parentColor
		 currentTransform:(Matrix4)transform
		  normalTransform:(Matrix3)normalTransform
				recursive:(BOOL)recursive
{
	// By default, a directive does not add itself to the list, an indication 
	// that it is not drawn. Subclasses override this routine to add themselves 
	// to the appropriate list. 

}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


//========== isAncestorInList: =================================================
//
// Purpose:		Given a list of LDrawContainers, returns YES if any of the 
//				containers is a direct ancestor of the receiver. An ancestor is 
//				specified by enclosingDirective; each enclosingDirective can 
//				also have an ancestor. This method searchs the whole chain.
//
// Note:		I think this method is potentially buggy. Shouldn't we be doing 
//				pointer equality tests?
//
//==============================================================================
- (BOOL)isAncestorInList:(NSArray *)containers
{
	LDrawDirective	*ancestor		= self;
	BOOL			 foundInList	= NO;
	
	do
	{
		ancestor = [ancestor enclosingDirective];
		foundInList = [containers containsObject:ancestor];
		
	}while(ancestor != nil && foundInList == NO);
	
	return foundInList;
	
}//end isAncestorInList:


//========== noteNeedsDisplay ==================================================
//
// Purpose:		An object can certainly be displayed in multiple views, and we 
//				don't really care to find out which ones here. So we just post 
//				a notification, and anyone can pick that up.
//
//==============================================================================
- (void) noteNeedsDisplay
{
	[[NSNotificationCenter defaultCenter]
					postNotificationName:LDrawDirectiveDidChangeNotification
								  object:self];
}//end setNeedsDisplay


//========== optimizeOpenGL ====================================================
//
// Purpose:		The caller is asking this instance to optimize itself for faster 
//				drawing. 
//
//				OpenGL optimization is not thread-safe. No OpenGL optimization 
//				is ever performed during parsing because of the thread-safety 
//				limitation, so you are responsible for calling this method on 
//				newly-parsed models. 
//
//==============================================================================
- (void) optimizeOpenGL
{
	// only meaningful in a subclass
	
}//end optimizeOpenGL


//========== optimizeVertexes ==================================================
//
// Purpose:		Optimizes raw vertex data into VBOs. The model collects raw 
//				vertex data through use of primitives. 
//
//==============================================================================
- (void) optimizeVertexes
{
	// only meaningful in a subclass
}


//========== registerUndoActions: ==============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	//LDrawDirectives are fairly abstract, so all undoable attributes come 
	// from subclasses.
	
}//end registerUndoActions:

- (void) addObserver:(id<LDrawObserver>) observer
{
	#if NEW_SET
		LDrawFastSetInsert(observers, observer);	
	#else
	if(observers == nil)
		printf("WARNING: OBSERVERS ARE NULL.\n");
	//printf("directive %p told to add observer %p.\n", self,observer);
	[observers addObject:[NSValue valueWithPointer:observer]];
	#endif
}

- (void) removeObserver:(id<LDrawObserver>) observer
{
	#if NEW_SET
		LDrawFastSetRemove(observers,observer);
	#else	
		if(observers == nil)
			printf("WARNING: OBSERVERS ARE NULL.\n");
		//printf("directive %p told to lose observer %p.\n", self,observer);
		if(![observers containsObject:[NSValue valueWithPointer:observer]])
			NSLog(@"ERROR: removing unknown observer.\n");

		[observers removeObject:[NSValue valueWithPointer:observer]];
	#endif
}

#pragma mark -
#pragma mark OBSERVATION
#pragma mark -


//============ dealloc =========================================================
//
// Purpose:		Gone daddy gone, the love has gone awaaaaay...
//
// Notes:		When an observable dies, it has to notify its observers to drop
//				their weak references.  Since directives implement the observable
//				protocol, we have to notify.
//
//==============================================================================
- (void) dealloc
{
	#if NEW_SET
		MESSAGE_FOR_SET(observers,LDrawObserver,observableSaysGoodbyeCruelWorld:self);
		LDrawFastSetDealloc(observers);
	#else
		if(observers == nil)
			printf("WARNING: OBSERVERS ARE NULL.\n");
		//printf("Directive %p about to die.\n",self);
		NSSet * orig = [NSSet setWithSet:observers];	
		for (NSValue * o in orig)
		{
			if([observers containsObject:o])
			{
				id<LDrawObserver> oo = [o pointerValue];
				//printf("   directive %p telling observer %p that we are going to die.\n",self,oo);		
				[oo observableSaysGoodbyeCruelWorld:self];
			}
		}
		[observers release];
		observers = (id) 0xDEADBEEF;
	#endif



	[super dealloc];
	//printf(" %p is clear.\n",self);
}


//============ sendMessageToObservers ==========================================
//
// Purpose:		This is a utility to send a message to every observer.  
//				Subclasses use it to reach observers since the observer
//				set is private.
//
//==============================================================================
- (void) sendMessageToObservers:(MessageT) msg
{
	#if NEW_SET
		MESSAGE_FOR_SET(observers,LDrawObserver,receiveMessage:msg who:self);
	#else
		NSSet * orig = [NSSet setWithSet:observers];
		for (NSValue * o in orig)
		{
			if([observers containsObject:o])
			{
				id<LDrawObserver> oo = [o pointerValue];		
				[oo receiveMessage:msg who:self];
			}
		}
	#endif
}


//============ invalCache ======================================================
//
// Purpose:		This is a utility that marks the cache flags as invalid for a
//				given subset of flags.  If the flags were not already dirty,
//				observers are notified.
//
// Usage:		Observables should call invalCache with the flag for a bit of 
//				data EVERY TIME that data changes.  Most of the time this will
//				result in a no-op or a small quantity of messages.  The 
//				internals take care of tracking cached state.
//
//==============================================================================
- (void) invalCache:(CacheFlagsT) flags
{
	CacheFlagsT newFlags = flags & ~invalFlags;
	if(newFlags != 0)
	{
		invalFlags |= newFlags;
		
		#if NEW_SET
			MESSAGE_FOR_SET(observers,LDrawObserver,statusInvalidated:newFlags who:self);
		#else		
			NSSet * orig = [NSSet setWithSet:observers];
			for (NSValue * o in orig)
			{
				if([observers containsObject:o])
				{
					id<LDrawObserver> oo = [o pointerValue];			
					[oo statusInvalidated:newFlags who:self];
				}
			}
		#endif			
	}
}


//============== revalCache ====================================================
//
// Purpose:		This is a utility that clears out cache flags.  Clients call 
//				this when they rebuild their own cached data as it is queried
//				by clients.
//
// Return:		The function returns the flags that were previously dirty from
//				among the set specified.
//
// Usage 1:		For an observable that does not need to cache its internals:
//				The observable should call this with the flag for the data when
//				the accessor is called.  This "re-arms" inval notifications for
//				observers.
//
// Usage 2:		For an observable that uses a cache with lazy rebuilding for a
//				property:
//				The observer should call revalCache with the flag for the 
//				property.  Then IF the return is the flag passed in, it should
//				rebuild the cache.  finally, it should return the cache.
//
//				In case 2, the cache is being lazily rebuilt when needed and
//				notifications rearmed at the same time.
//
//==============================================================================
- (CacheFlagsT) revalCache:(CacheFlagsT) flags
{
	CacheFlagsT were_dirty = flags & invalFlags;
	invalFlags &= ~flags;
	return were_dirty;
}

@end
