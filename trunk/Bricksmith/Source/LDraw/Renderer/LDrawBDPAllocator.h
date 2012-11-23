//
//  LDrawBDPAllocator.h
//  Bricksmith
//
//  Created by bsupnik on 11/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


struct	LDrawBDP;

struct LDrawBDP *		LDrawBDPCreate();
void					LDrawBDPDestroy(struct LDrawBDP * pool);
void *					LDrawBDPAllocate(struct LDrawBDP * pool, size_t sz);
