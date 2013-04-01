//
//  RelatedParts.h
//  Bricksmith
//
//  Created by bsupnik on 2/24/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MatrixMath.h"

@interface RelatedPart : NSObject
{
	NSString		*parent;
	NSString		*child;
	NSString		*childName;
	NSString		*role;
	GLfloat			transform[16];
}

- (id)			initWithLine:(NSString *) line;
- (void)		dump;

- (NSString*)	parent;
- (NSString*)	child;
- (NSString*)	childName;
- (NSString*)	role;
- (TransformComponents)	calcChildPosition:(TransformComponents)parentPosition;

@end

@interface RelatedParts : NSObject 
{
	NSArray *		relatedParts;

}

+ (RelatedParts*)sharedRelatedParts;
- (id)			initWithFilePath:(NSString *)filePath;
- (void)		dump;

// First level search: given a parent, these return an array of strings
// all valid roles or children.
- (NSArray*)	getChildPartList:(NSString *)parent;
- (NSArray*)	getChildRoleList:(NSString *)parent;

// Second level search: given the parent and one of the role or child,
// get the completions.  (There can be more than one, e.g. for a red wheels and "left tire"
// we expect to get the big and small tires).  
// The array is na array of complete RelatedPart objects.
- (NSArray*)	getSuggestionList:(NSString*) parent withRole:(NSString*) role;
- (NSArray*)	getSuggestionList:(NSString*) parent withChild:(NSString*) role;

@end
