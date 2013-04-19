//==============================================================================
//
//  RelatedParts.m
//  Bricksmith
//
//  Created by bsupnik on 2/24/13.
//  Copyright 2013. All rights reserved.
//
//==============================================================================

#if WANT_RELATED_PARTS

#import "RelatedParts.h"
#import "LDrawUtilities.h"
#import "StringCategory.h"
#import "PartLibrary.h"


//---------- sort_by_part_description ------------------------------------------
//
// Purpose:		This is a comparison function to sort an array of part names
//				(e.g. 3001.dat) by their descriptions (e.g. Brick 1 x 4, etc.)
//
//------------------------------------------------------------------------------
static NSInteger sort_by_part_description(id a, id b, void * ref)
{
	PartLibrary * pl = (PartLibrary *) ref;
	NSString * aa = a;
	NSString * bb = b;
	
	NSString * da = [pl descriptionForPartName:aa];
	NSString * db = [pl descriptionForPartName:bb];
	
	return [da compare:db];
	
}//end sort_by_part_description


//---------- sort_by_child_name ------------------------------------------------
//
// Purpose:		This is a comparison function that sorts an array of related
//				parts by the child name.
//
//------------------------------------------------------------------------------
static NSInteger sort_by_child_name(id a, id b, void * ref)
{
	RelatedPart * aa = a;
	RelatedPart * bb = b;
	
	return [[aa childName] compare:[bb childName]];
	
}//end sort_by_child_name


//---------- sort_by_role ------------------------------------------------------
//
// Purpose:		This is a comparison function that sorts an array of related
//				parts by the part's role.
//
//------------------------------------------------------------------------------
static NSInteger sort_by_role(id a, id b, void * ref)
{
	RelatedPart * aa = a;
	RelatedPart * bb = b;
	
	return [[aa role] compare:[bb role]];	
}//end sort_by_role


@implementation RelatedPart


//========== initWithParent:offset:relation:childLine: =========================
//
// Purpose:		Init a single parent-child relation.  The relation name, parent,
//				and offset are passed in because they have been previously read;
//				the child line is a "1" record from an LDR file minus the "1"
//				identifier, which has been pulled off already.
//
//==============================================================================
- (id)			initWithParent:(NSString *) parentName
						offset:(GLfloat *) offset
					  relation:(NSString *) relation
					 childLine:(NSString *) line
{
	NSCharacterSet	*whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];

	NSString	*parsedField = nil;
	NSString	*orig=line;
	self = [super init];
	
	@try {
		// Skip color
		parsedField = [LDrawUtilities readNextField:line remainder:&line];

		// Matrix XYZ
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[12] = [parsedField floatValue] - offset[0];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[13] = [parsedField floatValue] - offset[1];
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		transform[14] = [parsedField floatValue] - offset[2];
		
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

		self->child = [[line stringByTrimmingCharactersInSet:whitespaceCharacterSet] retain];
		
		self->childName = [[[PartLibrary sharedPartLibrary] descriptionForPartName:self->child] retain];
		
		self->role = [relation retain];
		
		self->parent = [parentName retain];
	}
	@catch (NSException * e) {
		NSLog(@"a related part line '%@' was fatally invalid", orig);
		NSLog(@" raised exception %@", [e name]);
		[self release];
		self = nil;
	
	}
	return self;
}//end initWithParent:offset:relation:childLine:


//========== dealloc ===========================================================
//
// Purpose:		Beam me out, Scotty!
//
//==============================================================================
- (void) dealloc
{
	[parent release];
	[child release];
	[childName release];
	[role release];
	[super dealloc];
}//end dealloc


//========== dump ==============================================================
//
// Purpose:		Print out a debug view of this relation for diagnostics.
//
//==============================================================================
- (void) dump
{
	NSLog(@"\t%s\t%s(%s)\t%s		%f,%f,%f		%f %f %f | %f %f %f | %f %f %f\n",
		[self->parent UTF8String], [self->child UTF8String], [self->childName UTF8String], [self->role UTF8String],
		self->transform[12],self->transform[13],self->transform[14],

		self->transform[0],self->transform[4],self->transform[8],
		self->transform[1],self->transform[5],self->transform[9],
		self->transform[2],self->transform[6],self->transform[10]);		
		
}//end dump


//========== parent ============================================================
//
// Purpose:		Return the file name (reference name) of the parent part for the
//				relationship.
//
//==============================================================================
- (NSString*)	parent
{
	return parent;
	
}//end parent


//========== child =============================================================
//
// Purpose:		Return the file name (reference name) of the chid part for the
//				relationship.
//
//==============================================================================
- (NSString*)	child
{
	return child;
	
}//end child


//========== childName =========================================================
//
// Purpose:		Return the child name for a given relationship.  This is the
//				human-readable description of the child part.
//
//==============================================================================
- (NSString*)	childName
{
	return childName;
	
}//end childName


//========== role ==============================================================
//
// Purpose:		Return the role name for the related part.
//
//==============================================================================
- (NSString*)	role
{
	return role;

}//end role


//========== calcChildPosition: ================================================
//
// Purpose:		Calculate the net position for a child given this relationship
//				and a given parent's position.
//
//==============================================================================
- (TransformComponents)	calcChildPosition:(TransformComponents)parentPosition
{
	TransformComponents ret;
	Matrix4	parentMatrix = Matrix4CreateTransformation(&parentPosition);
	Matrix4	childMatrix = Matrix4CreateFromGLMatrix4(self->transform);
	Matrix4 effective_position = Matrix4Multiply(childMatrix,parentMatrix);
	Matrix4DecomposeTransformation(effective_position, &ret);
	return ret;
	
}//end calcChildPosition:


@end


@implementation RelatedParts

static RelatedParts * SharedRelatedParts = nil;


//---------- sharedRelatedParts --------------------------------------[static]--
//
// Purpose:		Returns the singleton of the related parts; parts are loaded 
//				from an LDR file stored in our bundle.
//
//------------------------------------------------------------------------------
+ (RelatedParts*)sharedRelatedParts
{
	if(SharedRelatedParts == nil)
	{
	
		NSBundle * mainBundle	= [NSBundle mainBundle];
		NSString * path	= [mainBundle pathForResource:@"related.ldr" ofType:nil];
	
		SharedRelatedParts = [[RelatedParts alloc] initWithFilePath:path];
	}
	
	return SharedRelatedParts;
	
}//end sharedRelatedParts


//========== initWithFilePath: =================================================
//
// Purpose:		Create our new related-parts DB, loading related parts from
//				an LDR file.
//
//==============================================================================
- (id)			initWithFilePath:(NSString *)filePath
{
	NSUInteger			i;
	NSUInteger			count;
	NSString *			fileContents	= nil;
	NSString *			parsedField		= nil;

	NSCharacterSet	*whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];

	NSArray *			lines			= nil;
	NSMutableArray *	arr				= nil;

	self = [super init];
	fileContents	= [LDrawUtilities stringFromFile:filePath];
	lines			= [fileContents separateByLine];			
	count			= [lines count];
	arr				= [[NSMutableArray alloc] initWithCapacity:count];

	NSMutableArray * parents = [NSMutableArray arrayWithCapacity:5];
	GLfloat offset[3] = { 0, 0, 0 };
	NSString * relName = nil;
	
	for(i = 0; i < count; ++i)
	{
		NSString * line = [lines objectAtIndex:i];
		NSString * orig_line = line;
		
		parsedField = [LDrawUtilities readNextField:line remainder:&line];
		
		if([parsedField compare:@"0"] == NSOrderedSame)
		{
			// meta command - do we know what it is?
			parsedField = [LDrawUtilities readNextField:line remainder:&line];
			if([parsedField compare:@"!PARENT"] == NSOrderedSame)
			{
				relName = nil;
				parents = [NSMutableArray arrayWithCapacity:5];
				offset[0] = offset[1] = offset[2] = 0.0f;
			}
			else if([parsedField compare:@"!CHILD"] == NSOrderedSame)
			{
				relName = [line stringByTrimmingCharactersInSet:whitespaceCharacterSet];			
			}
			else
				printf("Unparsable META command: %s\n", [orig_line UTF8String]);
			
		}
		else if([parsedField compare:@"1"] == NSOrderedSame)
		{
			if(relName == nil)
			{
				// skip color
				parsedField = [LDrawUtilities readNextField:line remainder:&line];

				// Grab offset
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				offset[0] = [parsedField floatValue];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				offset[1] = [parsedField floatValue];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				offset[2] = [parsedField floatValue];
				
				// skip matrix

				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];

				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];

				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				parsedField = [LDrawUtilities readNextField:line remainder:&line];
				

				NSString * parentName = [line stringByTrimmingCharactersInSet:whitespaceCharacterSet];
				[parents addObject:parentName];

			}
			else
			{
				NSInteger num_parents = [parents count];
				NSInteger pidx;
				for(pidx = 0; pidx < num_parents; ++pidx)
				{
					NSString * pname = [parents objectAtIndex:pidx];
					RelatedPart * p = [[RelatedPart alloc] initWithParent:pname offset:offset relation:relName childLine:line];
					[arr addObject:p];
					[p release];
					
				}
			}
		}
		else
			printf("Unparsable line: %s\n", [orig_line UTF8String]);
	}
	
	self->relatedParts = arr;
	return self;

}//end initWithFilePath:


//========== dealloc ===========================================================
//
// Purpose:		My name is John D. Alec, but you can call me Mr. Alec.
//
//==============================================================================
- (void) dealloc
{
	[self->relatedParts release];

	[super dealloc];

}//end dealloc


//========== getChildPartList: =================================================
//
// Purpose:		Given a parent part file name, return a sorted array of child
//				parts that have some relationship to the parent.  
//
// Notes:		Children are returned as NSString's with the filename.
//
//==============================================================================
- (NSArray*)	getChildPartList:(NSString *)parent
{
	NSUInteger i;
	NSUInteger count = [self->relatedParts count];
	NSMutableSet * kids = [NSMutableSet setWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		RelatedPart * p = [self->relatedParts objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		{
			[kids addObject:[p child]];
		}
	}

	NSArray * kids_sorted = [kids allObjects];
	return [kids_sorted sortedArrayUsingFunction:sort_by_part_description context:[PartLibrary sharedPartLibrary]];

}//end getChildPartList:


//========== getChildPartList: =================================================
//
// Purpose:		Given a parent part file name, return a sorted array of roles
//				between this part and all of its children.
//
// Notes:		Roles are returned as NSStrings.
//
//==============================================================================
- (NSArray*)	getChildRoleList:(NSString *)parent
{
	NSUInteger i;
	NSUInteger count = [self->relatedParts count];
	NSMutableSet * kids = [NSMutableSet setWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		RelatedPart * p = [self->relatedParts objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		{
			[kids addObject:[p role]];
		}
	}
	
	NSArray * kids_sorted = [kids allObjects];
	return [kids_sorted sortedArrayUsingSelector:@selector(compare:)];
	
}//end getChildRoleList:


//========== getRelatedPartList:withRole: ======================================
//
// Purpose:		Given a parent part and a particular role, return a sorted
//				array of specific RelatedPart objects - all of the releations
//				for this parent matching this role.  
//
// Notes:		The returned array contains RelatedPart objects and are sorted
//				by the description of the child part.
//
//==============================================================================
- (NSArray*)	getRelatedPartList:(NSString*) parent withRole:(NSString*) role
{
	NSUInteger i;
	NSUInteger count = [self->relatedParts count];
	NSMutableArray * kids = [NSMutableArray arrayWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		RelatedPart * p = [self->relatedParts objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		if ([role compare:[p role]] == NSOrderedSame)
		{
			[kids addObject:p];
		}
	}
	[kids sortUsingFunction:sort_by_child_name context:NULL];
	return kids;
	
}//end getRelatedPartList:withRole:


//========== getRelatedPartList:withChild: =====================================
//
// Purpose:		Given a parent part and a particular child file name, return a
//				sorted array of specific RelatedPart objects - all of the
//				releations for this parent matching this child.
//
// Notes:		The returned array contains RelatedPart objects and are sorted
//				by the role.
//
//==============================================================================
- (NSArray*)	getRelatedPartList:(NSString*) parent withChild:(NSString*) child
{
	NSUInteger i;
	NSUInteger count = [self->relatedParts count];
	NSMutableArray * kids = [NSMutableArray arrayWithCapacity:10];
	
	for(i = 0; i < count; ++i)
	{
		RelatedPart * p = [self->relatedParts objectAtIndex:i];
		if ([parent compare:[p parent]] == NSOrderedSame)
		if ([child compare:[p child]] == NSOrderedSame)
		{
			[kids addObject:p];
		}
	}
	
	[kids sortUsingFunction:sort_by_role context:NULL];
	return kids;
	
}//end getRelatedPartList:withChild:


//========== dump ==============================================================
//
// Purpose:		Print the entire related-parts DB.
//
//==============================================================================
- (void) dump
{
	NSUInteger i, count;
	count = [self->relatedParts count];
	for(i = 0; i < count; ++i)
	{
		RelatedPart * p = [self->relatedParts objectAtIndex:i];
		[p dump];
	}
}//end dump

@end

#endif /* WANT_RELATED_PARTS */
