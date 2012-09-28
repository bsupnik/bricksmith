/*
 *  LDrawFastSet.h
 *  Bricksmith
 *
 *  Created by bsupnik on 9/15/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

/*
	LDrawFastSet - THEORY OF OPERATION
	
	Here's the problem: the overhead of NS collections is relatively high, and attaching a 
	mutable set to each directive to keep track of who is observing it basically doubles
	the number of NS containers and load time.
	
	Buuuuut - in nearly every important case, the nubmer of objects in a container is 1.
	So the fast set structure optimizes away the NS mutable set for the simple cases where
	we don't need a real set.
	
	ENCODING
	
	The fast set is a pair of pointers with the following encoding rules:
	
	p1		p2		meaning
	NULL	NULL	The set is empty.
	id1		NULL	The set contains one object, refered to via id1.
	id1		id2		The set contains two objects, referred to via id1 and id2.
	NULL	id2		The set contains at least 3 objects, contained in an NSMutableSet stored in id2.
	
*/

typedef struct {

	union {
		struct {			
			void *			p1;
			void *			p2;
		} ptr;
		struct {
			void *			flag;
			NSMutableSet *	mutable_set;
		} obj;
	};
	
} LDrawFastSet;




#define MESSAGE_FOR_SET(this,ns_type,__msg) \
	do {																					\
		if(this.ptr.p1)																		\
		{																					\
			id<ns_type> p1 = this.ptr.p1;													\
			id<ns_type> p2 = this.ptr.p2;													\
			if(p1)	[p1 __msg];																\
			if(p2 && LDrawFastSetContains(this, p2))										\
				[p2 __msg];																	\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				NSSet * orig = [NSSet setWithSet:this.obj.mutable_set];						\
				for (NSValue * o in orig)													\
				{																			\
					id<ns_type> oo = [o pointerValue];										\
					if(LDrawFastSetContains(this,oo))										\
					{																		\
						[oo __msg];															\
					}																		\
				}																			\
			}																				\
		}																					\
	} while(0)

#define LDrawFastSetContains(this, p) \
	((this.obj.flag == NULL && this.obj.mutable_set != nil) ?								\
		([this.obj.mutable_set containsObject:[NSValue valueWithPointer:p]] ? 1 : 0) :		\
		((this.ptr.p1 == p || this.ptr.p2 == p) ? 1 : 0))

#define LDrawFastSetInit(this) \
	do {																					\
		this.ptr.p1 = this.ptr.p2 = NULL;													\
	} while(0)
	

#define LDrawFastSetDealloc(this) \
	do {\
		if(this.obj.flag == NULL && this.obj.mutable_set != nil)							\
		[this.obj.mutable_set release];														\
	} while(0) 

#define LDrawFastSetInsert(this,p) \
	do {\
		if(this.ptr.p1)																		\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				if(p != this.ptr.p1 && p != this.ptr.p2)									\
				{																			\
					NSMutableSet * new_set = [[NSMutableSet alloc] initWithCapacity:3];		\
					[new_set addObject:[NSValue valueWithPointer:this.ptr.p1]];				\
					[new_set addObject:[NSValue valueWithPointer:this.ptr.p2]];				\
					[new_set addObject:[NSValue valueWithPointer:p]];						\
					this.obj.flag = NULL;													\
					this.obj.mutable_set = new_set;											\
				}																			\
			}																				\
			else																			\
			{																				\
				if(p != this.ptr.p1)														\
					this.ptr.p2 = p;														\
			}																				\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				[this.obj.mutable_set addObject:[NSValue valueWithPointer:p]];				\
			}																				\
			else																			\
			{																				\
				this.ptr.p1 = p;															\
			}																				\
		}																					\
	} while(0)


#define LDrawFastSetRemove(this, p) \
	do {																					\
		if(this.obj.flag == NULL && this.obj.mutable_set != nil)							\
		{																					\
			NSValue * me = [NSValue valueWithPointer:p];									\
			assert([this.obj.mutable_set containsObject:me]);								\
			[this.obj.mutable_set removeObject:me];											\
			assert([this.obj.mutable_set count] >= 2);										\
			if([this.obj.mutable_set count] == 2)											\
			{																				\
				void ** ptr = &this.ptr.p1;													\
				NSMutableSet * dead = this.obj.mutable_set;									\
				for(NSValue * o in dead)													\
				{																			\
					*ptr = [o pointerValue];												\
					++ptr;																	\
				}																			\
				[dead release];																\
			}																				\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p1 == p)															\
			{																				\
				this.ptr.p1 = this.ptr.p2;													\
				this.ptr.p2 = NULL;															\
			}																				\
			else if(this.ptr.p2 == p)														\
			{																				\
				this.ptr.p2 = NULL;															\
			}																				\
			else {																			\
				assert(!"Removal of an unknown object.");									\
			}																				\
		}																					\
	} while(0)




