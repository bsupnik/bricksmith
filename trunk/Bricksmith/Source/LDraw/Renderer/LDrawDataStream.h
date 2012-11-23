//
//  LDrawDataStream.h
//  Bricksmith
//
//  Created by bsupnik on 11/18/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


struct	LDrawDataStream;

struct LDrawDataStream *	LDrawDataStreamCreate(int buffer_size);
void						LDrawDataStreamDestroy(struct LDrawDataStream * str);

void *						LDrawDataStreamMap(struct LDrawDataStream * str,int size_desired);
void *						LDrawDataStreamUnmap(struct LDrawDataStream * str);


