//
//  LDrawBDPAllocator.h
//  Bricksmith
//
//  Created by bsupnik on 11/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*

	LDrawBDP - A Big Dumb Pool of memory - THEORY OF OPERATION
	
	The BDP allocator is a non-thread-safe high-speed allocator 
	with peculiar semantics:
	
	- Memory allocations are not explicitly freed by app code.  Instead all
	  allocations persist until the pool itself is destroyed.
	  
	This special rule has some implications:
	
	- Allocations are very fast and efficient even for small allocations,
	  because there is no book-keeping for individual blocks.

	- Consecutive allocations have good locality because the pool 
	  subdivides larger blocks, rather than scavanging free memory.
	  Consecutive allocations are consecutive in memory _most_ of 
	  the time.  (This makes linked lists significantly less expensive
	  to traverse.)
	  
	- Overall consumption is higher both due to pool large-chunk 
	  allocations, the no-free policy, and wasted space in the larger
	  chunks.
	  
	The BDP allocator is useful in cases where we need to piece 
	together data structures for a specific task and can dump the
	whole pool when done.
	
	

 */

// Pools are referred to via an opaque struct ptr.
struct	LDrawBDP;

// Allocate a new pool.
struct LDrawBDP *		LDrawBDPCreate();

// Destroy the pool, freeing all memory allocated from the pool, as well as
// the pool itself.
void					LDrawBDPDestroy(struct LDrawBDP * pool);

// Allocate a new memory block from the pool.
void *					LDrawBDPAllocate(struct LDrawBDP * pool, size_t sz);
