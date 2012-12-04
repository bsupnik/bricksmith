//
//  LDrawBDPAllocator.m
//  Bricksmith
//
//  Created by bsupnik on 11/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawBDPAllocator.h"

/* 
	BDP implementation: the pool consists of one or more large "pages" of memory, consisting of
	a header and payload.  The header keeps track of how much of the page has been given out.
	The pool is a linked list of pages.
	
	Most pages will be the 'standard' size, used for small sub-allocations.  If the client 
	requests a large allocation, we make a custom page to contain that one allocation and
	string it into the pool list.  This is slightly less efficient than the system allocator
	but lets client code not have to worry about maximum page size.
	
	Allocations are first fit: when we run out of space, we open a new page and we do not worry
	about wasted space.  So it is important that the typical allocation be much smaller than the 
	page size.  
	
	The page size should be at least 1 VM page.
*/


struct	BDPPage;

struct	BDPPageHeader {
	struct BDPPage *	next;		// Ptr to next page in pool.
	char *				cur;		// Ptr to first free byte in payload to allocate.
	char *				end;		// Ptr to end of this page's payload - we could eliminate that if we hard code fixed size pages.
};

#define BDP_PAGE_SIZE 4096			// Tune this based on real app use someday?  

#define BDP_PAYLOAD_SIZE (BDP_PAGE_SIZE - sizeof(struct BDPPageHeader))

struct	BDPPage {
	struct BDPPageHeader	header;
	char					data[BDP_PAYLOAD_SIZE];
};

struct	LDrawBDP {
	struct BDPPage *	first;		// Head of the linked list of pages, 
	struct BDPPage *	cur;		// Tail - the current "open" page to grab data from.
};



/////////////////////////////////////////////////////////////////////////////////////////////////////////


//========== get_new_page ========================================================
//
// Purpose:		Prepare a single standard-size empty page for use in the pool.
//
//================================================================================
static struct	BDPPage *	get_new_page()
{	
	struct	BDPPage * ptr = (struct	BDPPage *) malloc(sizeof(struct	BDPPage));
	ptr->header.cur = ptr->data;
	ptr->header.end = ptr->data + BDP_PAYLOAD_SIZE;
	return ptr;
}


//========== LDrawBDPCreate ======================================================
//
// Purpose:		Create a new BDP pool.
//
// Notes:		The pool is created with one empty page ready for use.
//
//================================================================================
struct LDrawBDP *		LDrawBDPCreate()
{
	struct LDrawBDP * ret = (struct LDrawBDP *) malloc(sizeof(struct LDrawBDP));
	ret->first = ret->cur = get_new_page();
	ret->first->header.next = NULL;
	return ret;
}//end LDrawBDPCreate


//========== LDrawBDPDestroy =====================================================
//
// Purpose:		Destroy a pool.
//
// Notes:		This deallocates all memory allocated from the pool.
//
//================================================================================
void					LDrawBDPDestroy(struct LDrawBDP * pool)
{
	while(pool->first)
	{
		struct BDPPage * k = pool->first;
		pool->first = pool->first->header.next;
		free(k);
	}
	free(pool);
}//end LDrawBDPDestroy


//========== LDrawBDPAllocate ====================================================
//
// Purpose:		Allocate a fixed amount of memory from the pool.
//
// Notes:		This routine will create a new page if the current page is full,
//				or allocate a custom huge-sized page if the amount of memory 
//				requested is large.
//
//================================================================================
void *					LDrawBDPAllocate(struct LDrawBDP * pool, size_t sz)
{
	struct BDPPage * page = pool->cur;
	if((page->header.end - page->header.cur) >= sz)
	{
		// Quick case: room in the current pool.
		void * ret = page->header.cur;
		page->header.cur += sz;
		return ret;
	}
	else if(sz > BDP_PAYLOAD_SIZE)
	{
		// Oversized case - we make a custom-sized page for this one allocation
		// and pop it on the head of the list - the tail stays open - maybe
		// it still has space.
		char * raw_buf = (char *) malloc(sizeof(struct BDPPageHeader) + sz);
		struct BDPPageHeader * h = (struct BDPPageHeader *) raw_buf;
		h->next = pool->first;
		h->cur = h->end = raw_buf + sizeof(struct BDPPageHeader) + sz;
		pool->first = (struct BDPPage *) h;		
		return raw_buf + sizeof(struct BDPPageHeader);
	}
	else
	{
		// Allocate a new page and we're ready to go.
		assert(sz <= BDP_PAYLOAD_SIZE);
		struct BDPPage * np = get_new_page();
		page->header.next = np;
		np->header.next = NULL;

		void * ret = np->header.cur;
		np->header.cur += sz;
		pool->cur = np;
		return ret;
	}
}//end LDrawBDPAllocate
