//
//  Suggestions.m
//  Bricksmith
//
//  Created by bsupnik on 2/24/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import "Suggestions.h"
#import "LDrawUtilities.h"
#import "StringCategory.h"
#import "PartLibrary.h"

@implementation PartSuggestion

- (id)			initWithLine:(NSString *) line
{
	NSCharacterSet	*whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];

	NSString	*parsedField = nil;
	NSString	*orig=line;
	self = [super init];
	
	
	// parent child role xform
	@try {
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		self->parent = [parsedField retain];

		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		self->child = [parsedField retain];

		// Matrix XYZ
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[12] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[13] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[14] = [parsedField floatValue];
		
		// Matrix rotation 3x3.  LDraw format is transpose of what we are
		// used to from OpenGL.
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[0] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[4] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[8] = [parsedField floatValue];

		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[1] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[5] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[9] = [parsedField floatValue];

		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[2] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[6] = [parsedField floatValue];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[10] = [parsedField floatValue];
		
		transform[3]  = 0.0f;
		transform[7]  = 0.0f;
		transform[11] = 0.0f;		
		transform[15] = 1.0f;

		self->role = [[line stringByTrimmingCharactersInSet:whitespaceCharacterSet] retain];
		
		self->childName = [[[PartLibrary sharedPartLibrary] descriptionForPartName:self->child] retain];

	}
	@catch (NSException * e) {
		NSLog(@"a suggestion line '%@' was fatally invalid", orig);
		NSLog(@" raised exception %@", [e name]);
		[self release];
		self = nil;
	
	}
	return self;
}

- (void) dealloc
{
	[parent release];
	[child release];
	[childName release];
	[role release];
	[super dealloc];
}

- (void) dump
{
	NSLog(@"\t%s\t%s(%s)\t%s		%f,%f,%f		%f %f %f | %f %f %f | %f %f %f\n",
		[self->parent UTF8String], [self->child UTF8String], [self->childName UTF8String], [self->role UTF8String],
		self->transform[12],self->transform[13],self->transform[14],

		self->transform[0],self->transform[4],self->transform[8],
		self->transform[1],self->transform[5],self->transform[9],
		self->transform[2],self->transform[6],self->transform[10]);		
}

- (NSString*)	parent
{
	return parent;
}

- (NSString*)	child
{
	return child;
}

- (NSString*)	childName
{
	return childName;
}

- (NSString*)	role
{
	return role;
}

- (TransformComponents)	calcChildPosition:(TransformComponents)parentPosition
{
	TransformComponents ret;
	Matrix4	parentMatrix = Matrix4CreateTransformation(&parentPosition);
	Matrix4	childMatrix = Matrix4CreateFromGLMatrix4(self->transform);
	Matrix4 effective_position = Matrix4Multiply(childMatrix,parentMatrix);
	Matrix4DecomposeTransformation(effective_position, &ret);
	return ret;
}

@end


@implementation Suggestions

static Suggestions * SharedSuggestions = nil;

+ (Suggestions*)sharedSuggestions
{
	if(SharedSuggestions == nil)
	{
		SharedSuggestions = [[Suggestions alloc] initWithFilePath:@"/Users/bsupnik/Desktop/suggestions.txt"];
	}
	
	return SharedSuggestions;
}

- (id)			initWithFilePath:(NSString *)filePath
{
	NSUInteger			i;
	NSUInteger			count;
	NSString *			fileContents	= nil;
	NSArray *			lines			= nil;
	NSMutableArray *	arr				= nil;

	self = [super init];
	fileContents	= [LDrawUtilities stringFromFile:filePath];
	lines			= [fileContents separateByLine];			
	count			= [lines count];
	arr				= [[NSMutableArray alloc] initWithCapacity:count];

	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [[PartSuggestion alloc] initWithLine:[lines objectAtIndex:i]];
		[arr addObject:p];
		[p release];
	}
	self->suggestions = arr;
	return self;
}

- (void) dealloc
{
	[self->suggestions release];

	[super dealloc];
}

- (NSArray*)	getChildPartList:(NSString *)parent
{
	NSUInteger i;
	NSUInteger count = [self->suggestions count];
	NSMutableSet * kids = [NSMutableSet setWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [self->suggestions objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		{
			[kids addObject:[p child]];
		}
	}
	return [kids allObjects];
}

- (NSArray*)	getChildRoleList:(NSString *)parent
{
	NSUInteger i;
	NSUInteger count = [self->suggestions count];
	NSMutableSet * kids = [NSMutableSet setWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [self->suggestions objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		{
			[kids addObject:[p role]];
		}
	}
	return [kids allObjects];
}

// Second level search: given the parent and one of the role or child,
// get the completions.  (There can be more than one, e.g. for a red wheels and "left tire"
// we expect to get the big and small tires).  
// The array is na array of complete PartSuggestion objects.
- (NSArray*)	getSuggestionList:(NSString*) parent withRole:(NSString*) role
{
	NSUInteger i;
	NSUInteger count = [self->suggestions count];
	NSMutableArray * kids = [NSMutableArray arrayWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [self->suggestions objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		if ([role compare:[p role]] == NSOrderedSame)
		{
			[kids addObject:p];
		}
	}
	return kids;
}

- (NSArray*)	getSuggestionList:(NSString*) parent withChild:(NSString*) child
{
	NSUInteger i;
	NSUInteger count = [self->suggestions count];
	NSMutableArray * kids = [NSMutableArray arrayWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [self->suggestions objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		if ([child compare:[p child]] == NSOrderedSame)
		{
			[kids addObject:p];
		}
	}
	return kids;
}

- (void) dump
{
	NSUInteger i, count;
	count = [self->suggestions count];
	for(i = 0; i < count; ++i)
	{
		PartSuggestion * p = [self->suggestions objectAtIndex:i];
		[p dump];
	}
}

@end
