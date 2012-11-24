//==============================================================================
//
// File:		LDrawDirective.h
//
// Purpose:		This is an abstract base class for all elements of an LDraw 
//				document.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "MatrixMath.h"
#import "LDrawFastSet.h"
#import "LDrawRenderer.h"

// This uses the hacky C wrapper around NSSet to improve performance.
#define NEW_SET 1

@class LDrawColor;
@class LDrawContainer;
@class LDrawFile;
@class LDrawModel;
@class LDrawStep;

////////////////////////////////////////////////////////////////////////////////
//
//				OBSERVABLE/OBSERVER PROTOCOLS FOR DIRECTIVES
//
////////////////////////////////////////////////////////////////////////////////

// The observer protocol builds a one-way DAG out of our directives allowing
// directives to note changes in their child directives and manage cached data
// appropriately.  The protocol rules:
//
// 1. An observer/observable relationship is a pair of _weak_ references.  No
//	  retain counts are maintained, and it is always possible that either party
//	  could end the relationship by dying.  Observers who have good reason why
//	  their observables should not go away (or vice versa) should maintain 
//	  retain counts separately as part of a separate parallel structure; this is
//	  only for message flow.
//
// 2. An observer begins observation by requesting that the observable at it to
//	  an internal hypothetical observer list.  Observables do not start the 
//    relationship.
//
//	  Similarly, an observer ends observation by requesting its observable to
//	  remove me from the list.
//
// 3. Death: if the observer dies first, it is responsible for terminating the
//	  relationship in the usual way by calling removeObserver on its observable
//	  with itself as the direct object.
//
//	  But if the observable dies first (while being observed) it sends a 
//	  "goodbye cruel world" message to all observers currently watching it.  
//	  Those observers note that the observable is no longer, um, observable but
//	  they do _not_ need to call back with a removeObservable message.
//
// The method receiveMessage is used to send a set of specific messages to all
// observing.  This is for one-time, relatively rare, non-deallocation events
// that happen.
//
// Observables maintain a bit-field of flags about the status of cachable 
// information; an invalidate cache message is sent to all observers once each
// time cachable info is changed until _any_ external caller reads that property.
// (When a caller reads the property, the cache is rebuilt and a new invalidate
// message will be generated.)
//
// CACHING BEHAVIORS
//
// The idea behind the caching flags is this: an observer that produces the sum
// or union from many observables can benefit from knowing that none of the
// observables has changed.  (E.g. it's nice for a step to know that no bricks
// have moved.)  The correct caching behavior is this:
//
// - Every time the observer reads an observable's property, the observable
//	 clears the flag for that property, because the observer and observable
//	 are now in sync.  If the property requires expensive computation in the
//	 observable, the observable probably updates its own internal cache.
//
// - Every time the obserable changes that property, it sends a notification
//	 only IF the cache flag is clear; it then sets the cache flag.
//
// - An observer who receievs an invalidate message may in turn invalidate
//	 its own cache (if necessary), causing a cascade up the observation tree.
//
// Thus if the position of an object is changed 8 times between any external
// code reading the object, an inval message is sent to observers only once.
// See invalCache and revalCache for more details.

@protocol LDrawObserver;
@protocol LDrawObservable;

// Cache flags.  For now, we can maintain all cache flags in one place.  In
// theory observable/observer could be used in many places in the app but for
// now since it is just used for directives, maintain all directive-related
// enusm and flags here...

typedef enum CacheFlags {

	// The bounding box of the directive has changed and is no longer valid.
	CacheFlagBounds = 1,
	DisplayList		= 2
} CacheFlagsT;

typedef enum Message {

	// The reference name of the MPD model has changed and observers should 
	// update their string references.
	MessageNameChanged = 0,
	
	// The MPD's parent has changed, and thus its scope may have changed
	MessageScopeChanged = 1
	
	// The 
} MessageT;

@protocol LDrawObserver
@required
- (void) observableSaysGoodbyeCruelWorld:(id<LDrawObservable>) doomedObservable;
- (void) statusInvalidated:(CacheFlagsT) flags who:(id<LDrawObservable>) observable;
- (void) receiveMessage:(MessageT) msg who:(id<LDrawObservable>) observable;
@end


@protocol LDrawObservable
@required
- (void) addObserver:(id<LDrawObserver>) observer;
- (void) removeObserver:(id<LDrawObserver>) observer;
@end




////////////////////////////////////////////////////////////////////////////////



//A directive was modified, either explicitly by the user or by undo/redo.
// Object is the LDrawDirective that changed. No userInfo.
#define LDrawDirectiveDidChangeNotification				@"LDrawDirectiveDidChangeNotification"


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Drawing Mask bits and Constants
//
////////////////////////////////////////////////////////////////////////////////
#define DRAW_NO_OPTIONS							0
#define DRAW_WIREFRAME							1 << 1
#define DRAW_BOUNDS_ONLY						1 << 3


////////////////////////////////////////////////////////////////////////////////
//
// LDrawDirective
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawDirective : NSObject <NSCoding, NSCopying, LDrawObservable>
{
	@private
	LDrawContainer *enclosingDirective; //LDraw files are a hierarchy.
	#if NEW_SET
		LDrawFastSet	observers;
	#else
		NSMutableSet   *observers;			//Any observers watching us.  This is an array of NSValues of pointers to create WEAK references.
	#endif
	CacheFlagsT		invalFlags;
	BOOL			isSelected;
	
}

// Initialization
- (id) initWithLines:(NSArray *)lines inRange:(NSRange)range;
- (id) initWithLines:(NSArray *)lines inRange:(NSRange)range parentGroup:(dispatch_group_t)parentGroup;
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index inLines:(NSArray *)lines maxIndex:(NSUInteger)maxIndex;

// Directives
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor;
- (void) drawSelf:(id<LDrawRenderer>)renderer;
- (void) collectSelf:(id<LDrawCollector>)renderer;
- (Box3) boundingBox3;
- (void) debugDrawboundingBox;

// Hit testing primitives
- (void) hitTest:(Ray3)pickRay transform:(Matrix4)transform viewScale:(float)scaleFactor boundsOnly:(BOOL)boundsOnly creditObject:(id)creditObject hits:(NSMutableDictionary *)hits;
- (BOOL) boxTest:(Box2)bounds transform:(Matrix4)transform boundsOnly:(BOOL)boundsOnly creditObject:(id)creditObject hits:(NSMutableSet *)hits;
- (void) depthTest:(Point2)testPt inBox:(Box2)bounds transform:(Matrix4)transform creditObject:(id)creditObject bestObject:(id *)bestObject bestDepth:(float *)bestDepth;

- (NSString *) write;

// Display
- (NSString *) browsingDescription;
- (NSString *) iconName;
- (NSString *) inspectorClassName;

// Accessors
- (NSArray *)ancestors;
- (LDrawContainer *) enclosingDirective;
- (LDrawFile *) enclosingFile;
- (LDrawModel *) enclosingModel;
- (LDrawStep *) enclosingStep;
- (BOOL) isSelected;

- (void) setEnclosingDirective:(LDrawContainer *)newParent;
- (void) setSelected:(BOOL)flag;

// protocol Inspectable
- (void) lockForEditing;
- (void) unlockEditor;

// Utilities
- (BOOL) containsReferenceTo:(NSString *)name;
- (void) flattenIntoLines:(NSMutableArray *)lines
				triangles:(NSMutableArray *)triangles
		   quadrilaterals:(NSMutableArray *)quadrilaterals
					other:(NSMutableArray *)everythingElse
			 currentColor:(LDrawColor *)parentColor
		 currentTransform:(Matrix4)transform
		  normalTransform:(Matrix3)normalTransform
				recursive:(BOOL)recursive;
- (BOOL) isAncestorInList:(NSArray *)containers;
- (void) noteNeedsDisplay;
- (void) optimizeOpenGL;
- (void) optimizeVertexes;
- (void) registerUndoActions:(NSUndoManager *)undoManager;

// These methods should really be "protected" methods for sub-classes to use when acting like observables.
// Obj-C doesn't give us compiler-level support to stop externals from calling them.

- (void) sendMessageToObservers:(MessageT) msg;					// Send a specific message to all observers.
- (void) invalCache:(CacheFlagsT) flags;						// Invalidate cache bits - this notifies observers as needed.  Flags are the bits to invalidate, not the net effect.
- (CacheFlagsT) revalCache:(CacheFlagsT) flags;						// Revalidate flags - no notifications are sent, but internals are updated.  Returns which flags _were_ dirty.

@end
