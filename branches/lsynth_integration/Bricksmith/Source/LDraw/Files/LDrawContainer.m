//==============================================================================
//
// File:		LDrawContainer.m
//
// Purpose:		Abstract subclass for LDrawDirectives which represent a 
//				collection of related directives.
//
//				Subclasses: LDrawFile, LDrawModel, LDrawStep
//
//  Created by Allen Smith on 3/31/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawContainer.h"

#import "LDrawUtilities.h"
#import "PartReport.h"

@implementation LDrawContainer

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Creates a new container with absolutely nothing in it, but 
//				ready to receive objects.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	containedObjects    = [[NSMutableArray alloc] init];
	postsNotifications  = NO;
	
	return self;
	
}//end init


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
	
	containedObjects = [[decoder decodeObjectForKey:@"containedObjects"] retain];
	
	for(id<LDrawObservable> i in containedObjects)
		[i addObserver:self];
	
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
	[super encodeWithCoder:encoder];
	
	[encoder encodeObject:containedObjects forKey:@"containedObjects"];

}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this object. Each contained directive is 
//				copied, so the returned object is a complete duplicate of the 
//				receiver.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawContainer  *copiedContainer    = (LDrawContainer *)[super copyWithZone:zone];
	id              currentObject       = nil;
	id              copiedObject        = nil;
	NSInteger       counter             = 0;
	
	// Copy each subdirective and transfer it into the copied container.
	for(currentObject in self->containedObjects)
	{
		copiedObject = [currentObject copy];
		[copiedContainer insertDirective:copiedObject atIndex:counter];
		[copiedObject release];
	}
	
	return copiedContainer;
	
}//end copyWithZone:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== allEnclosedElements ===============================================
//
// Purpose:		Returns all of the terminal (leaf-node) subdirectives contained 
//				within this object and all enclosed containers. Does not return 
//				the enclosed containers themselves.
//
//==============================================================================
- (NSArray *) allEnclosedElements
{
	NSMutableArray  *subelements        = [NSMutableArray array];
	id              currentDirective    = nil;
	
	for(currentDirective in self->containedObjects)
	{
		if([currentDirective respondsToSelector:@selector(allEnclosedElements)])
			[subelements addObjectsFromArray:[currentDirective allEnclosedElements]];
		else
			[subelements addObject:currentDirective];
	}
	
	return subelements;
	
}//end allEnclosedElements


//========== boundingBox3 ======================================================
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains this object.
//
//==============================================================================
//- (Box3) boundingBox3
//{
//	return [LDrawUtilities boundingBox3ForDirectives:self->containedObjects];
//
//}//end boundingBox3


//========== postsNotifications ================================================
//==============================================================================
- (BOOL) postsNotifications
{
	return self->postsNotifications;
}


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
	Box3        bounds              = InvalidBox;
	Box3        partBounds          = InvalidBox;
	id          currentDirective    = nil;
	NSInteger   numberOfDirectives  = [self->containedObjects count];
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < numberOfDirectives; counter++)
	{
		currentDirective = [self->containedObjects objectAtIndex:counter];
		if([currentDirective respondsToSelector:@selector(projectedBoundingBoxWithModelView:projection:view:)])
		{
			partBounds  = [currentDirective projectedBoundingBoxWithModelView:modelView
																   projection:projection
																		 view:viewport];
			bounds      = V3UnionBox(bounds, partBounds);
		}
	}
	
	return bounds;
	
}//end projectedBoundingBoxWithModelView:projection:view:


//========== indexOfDirective: =================================================
//
// Purpose:		Adds directive into the collection at position index.
//
//==============================================================================
- (NSInteger) indexOfDirective:(LDrawDirective *)directive
{
	return [containedObjects indexOfObjectIdenticalTo:directive];
	
}//end indexOfDirective:


//========== subdirectives =====================================================
//
// Purpose:		Returns the LDraw directives stored in this collection.
//
//==============================================================================
- (NSArray *) subdirectives
{
	return containedObjects;
	
}//end subdirectives


#pragma mark -

//========== setPostsNotifications: ============================================
//
// Purpose:		Sets whether the container posts 
//				LDrawDirectiveDidChangeNotifications when its contents change. 
//
// Notes:		Posting notifications is extremely time-consuming and only 
//				needed for editable containers. Given the huge number of 
//				container changes which occur during parsing, you generally want 
//				this flag off except in parseable directives. 
//
//==============================================================================
- (void) setPostsNotifications:(BOOL)flag
{
	self->postsNotifications = flag;
	
	// Apply new setting to children
	for(id childDirective in self->containedObjects)
	{
		if([childDirective respondsToSelector:@selector(setPostsNotifications:)] == YES)
		{
			[childDirective setPostsNotifications:flag];
		}
	}
}//end setPostsNotifications:


//========== setVertexesNeedRebuilding =========================================
//
// Purpose:		Marks all the vertex optimizations of this container as needing 
//				rebuilding. 
//
//==============================================================================
- (void) setVertexesNeedRebuilding
{
	// pass to the superclass; subclasses can override to redirect this message 
	// to vertexes they manage. 
	[[self enclosingDirective] setVertexesNeedRebuilding];
}


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== addDirective: =====================================================
//
// Purpose:		Adds directive into the collection at the end of the list.
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)directive
{
	NSInteger index = [containedObjects count];
	[self insertDirective:directive atIndex:index];
	
}//end addDirective:


//========== collectPartReport: ================================================
//
// Purpose:		Collects a report on all the parts in this container, no matter 
//				how deeply they may be contained.
//
//==============================================================================
- (void) collectPartReport:(PartReport *)report
{
	id          currentDirective    = nil;
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < [containedObjects count]; counter++)
	{
		currentDirective = [containedObjects objectAtIndex:counter];
		
		if([currentDirective respondsToSelector:@selector(collectPartReport:)])
			[currentDirective collectPartReport:report];
	}
	
}//end collectPartReport:


//========== removeDirective: ==================================================
//
// Purpose:		Removes the specified LDraw directive stored in this collection.
//
//				If it isn't in the collection, well, that's that.
//
//==============================================================================
- (void) removeDirective:(LDrawDirective *)doomedDirective
{
	//First, find the object (making sure it's actually there in the process)
	NSInteger indexOfObject = [self indexOfDirective:doomedDirective];
	
	if(indexOfObject != NSNotFound)
	{
		//We found it; kill it!
		[self removeDirectiveAtIndex:indexOfObject];
	}
}//end removeDirective:


//========== insertDirective:atIndex: ==========================================
//
// Purpose:		Adds directive into the collection at position index.
//
//==============================================================================
- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index
{
	// Insert
	[containedObjects insertObject:directive atIndex:index];
	[directive setEnclosingDirective:self];
	
	// Apply notification policy to new children
	if([directive respondsToSelector:@selector(setPostsNotifications:)] == YES)
	{
		if([(LDrawContainer*)directive postsNotifications] != self->postsNotifications)
		{
			[(LDrawContainer*)directive setPostsNotifications:self->postsNotifications];
		}
	}
	
	// We have to do this FIRST - otherwise, our cache gets rebuilt by the notification handlers before the view hierarchy is fully wired
	// up and things go pretty sideways from there.
	[directive addObserver:self];

	if(self->postsNotifications == YES)
	{
		[self noteNeedsDisplay];
	}

	
}//end insertDirective:atIndex:


//========== removeDirectiveAtIndex: ===========================================
//
// Purpose:		Removes the LDraw directive stored at index in this collection.
//
//==============================================================================
- (void) removeDirectiveAtIndex:(NSInteger)index
{
	LDrawDirective *doomedDirective = [self->containedObjects objectAtIndex:index];
	
	if([doomedDirective enclosingDirective] == self)
		[doomedDirective setEnclosingDirective:nil]; //no parent anymore; it's an orphan now.

	// Do this first...the actual remove may drop the directive's ref count.  In that 
	// case we'll puke.
	[doomedDirective removeObserver:self];
	
	[containedObjects removeObjectAtIndex:index]; //or disowned at least.
	
	if(self->postsNotifications == YES)
	{
		[self noteNeedsDisplay];
	}
						  
}//end removeDirectiveAtIndex:


#pragma mark -
#pragma mark UTILITES
#pragma mark -

//========== containsReferenceTo: ==============================================
//
// Purpose:		Returns if this object (or any of its children) references a 
//				model with the given name. 
//
//==============================================================================
- (BOOL) containsReferenceTo:(NSString *)name
{
	NSArray 		*subdirectives		= [self subdirectives];
	LDrawDirective	*currentDirective	= 0;
	BOOL			containsReference	= NO;
	
	for(currentDirective in subdirectives)
	{
		containsReference = [currentDirective containsReferenceTo:name];
		
		if(containsReference)
			break;
	}
	
	return containsReference;
}


//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
//
// Purpose:		Appends the directive into the appropriate container. 
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
	NSArray         *subdirectives      = [self subdirectives];
	LDrawDirective  *currentDirective   = 0;
	
	for(currentDirective in subdirectives)
	{
		[currentDirective flattenIntoLines:lines
								 triangles:triangles
							quadrilaterals:quadrilaterals
									 other:everythingElse
							  currentColor:parentColor
						  currentTransform:transform
						   normalTransform:normalTransform
								 recursive:recursive];
	}
	
}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


//========== optimizeOpenGL ====================================================
//
// Purpose:		Makes this part run faster by compiling its contents into a 
//				display list if possible.
//
//==============================================================================
- (void) optimizeOpenGL
{
	for(LDrawDirective *currentDirective in self->containedObjects)
	{
		[currentDirective optimizeOpenGL];
	}

}//end optimizeOpenGL


//========== optimizeVertexes ==================================================
//
// Purpose:		Subclasses would use this to optimize vertexes they manage. We 
//				just pass it along until it finds a subclass which does. 
//
//==============================================================================
- (void) optimizeVertexes
{
	for(LDrawDirective *currentDirective in self->containedObjects)
	{
		[currentDirective optimizeVertexes];
	}
}


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		IT'S THE END OF THE WORLD AS WE KNOW IT!!!
//
//==============================================================================
- (void) dealloc
{
	for(id<LDrawObservable> i in self->containedObjects)
		[i removeObserver:self];
	//the children must not be allowed to remember us. Crashes could result otherwise.
	[self->containedObjects makeObjectsPerformSelector:@selector(setEnclosingDirective:)
											withObject:nil ];

	//release instance variables
	[containedObjects release];
	
	[super dealloc];
	
}//end dealloc


#pragma mark -
#pragma mark OBSERVABLE/OBSERVER
#pragma mark -

//========== observableSaysGoodbyeCruelWorld====================================
//
// Purpose:		this is the message receiving method for observers when their
//				observable is yanked out from under them.  Observation is a weak
//				reference so the thing you are observing may be nuked.
//
//				In the case of the container, we only observe the directives
//				we contain and we are supposed to remove all directives before
//				they die (and containing them is a strong reference).  So...
//				If any dying directives call out to us, it's a programming error.
//				Just log it out for now?
//
//==============================================================================
- (void) observableSaysGoodbyeCruelWorld:(id<LDrawObservable>) doomedObservable
{
	if([self->containedObjects indexOfObject:doomedObservable] != NSNotFound)
	{
		NSLog(@"Observer's observable is dying but we have no idea who it is...");
	}
}


//========== statusInvalidated =================================================
//
// Purpose:		The things we watch call this when one of their states that we 
//				might have cached is no longer valid.  This tells us to not rely
//				on that data.
//
//==============================================================================
- (void) statusInvalidated:(CacheFlagsT) flags who:(id<LDrawObservable>) observable
{
	[self invalCache:flags];
}


//========== receiveMessage ====================================================
//
// Purpose:		The things we observe call this when something one-time and 
//				eventful happens - we can repsond if desired.
//
//==============================================================================
- (void) receiveMessage:(MessageT) msg who:(id<LDrawObservable>) observable
{
}

@end
