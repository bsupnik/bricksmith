//
//  LDrawBDPAllocator.m
//  Bricksmith
//
//  Created by bsupnik on 11/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "LDrawBDPAllocator.h"

struct LDrawBDP *		LDrawBDPCreate();
void					LDrawBDPDestroy(struct LDrawBDP * pool);
void *					LDrawBDPAllocate(struct LDrawBDP * pool, size_t sz);

struct	BDPPage;

struct	BDPPageHeader {
	struct BDPPage *	next;
	char *				cur;
	char *				end;
};


#define BDP_PAGE_SIZE 4096
#define BDP_PAYLOAD_SIZE (BDP_PAGE_SIZE - sizeof(struct BDPPageHeader))

struct	BDPPage {
	struct BDPPageHeader	header;
	char					data[BDP_PAYLOAD_SIZE];
};

struct	LDrawBDP {
	struct BDPPage *	first;
	struct BDPPage *	cur;
};

static struct	BDPPage *	get_new_page()
{	
	struct	BDPPage * ptr = (struct	BDPPage *) malloc(sizeof(struct	BDPPage));
	ptr->header.cur = ptr->data;
	ptr->header.end = ptr->data + BDP_PAYLOAD_SIZE;
	return ptr;
}

struct LDrawBDP *		LDrawBDPCreate()
{
	struct LDrawBDP * ret = (struct LDrawBDP *) malloc(sizeof(struct LDrawBDP));
	ret->first = ret->cur = get_new_page();
	ret->first->header.next = NULL;
	return ret;
}

void					LDrawBDPDestroy(struct LDrawBDP * pool)
{
	while(pool->first)
	{
		struct BDPPage * k = pool->first;
		pool->first = pool->first->header.next;
		free(k);
	}
	free(pool);
}

void *					LDrawBDPAllocate(struct LDrawBDP * pool, size_t sz)
{
	struct BDPPage * page = pool->cur;
	if((page->header.end - page->header.cur) >= sz)
	{
		void * ret = page->header.cur;
		page->header.cur += sz;
		return ret;
	}
	else if(sz > BDP_PAYLOAD_SIZE)
	{
		char * raw_buf = (char *) malloc(sizeof(struct BDPPageHeader) + sz);
		struct BDPPageHeader * h = (struct BDPPageHeader *) raw_buf;
		h->next = pool->first;
		h->cur = h->end = raw_buf + sizeof(struct BDPPageHeader) + sz;
		pool->first = (struct BDPPage *) h;		
		return raw_buf + sizeof(struct BDPPageHeader);
	}
	else
	{
		assert(sz <= BDP_PAYLOAD_SIZE);
		struct BDPPage * np = get_new_page();
		page->header.next = np;
		np->header.next = NULL;

		void * ret = np->header.cur;
		np->header.cur += sz;
		pool->cur = np;
		return ret;

	}
}
