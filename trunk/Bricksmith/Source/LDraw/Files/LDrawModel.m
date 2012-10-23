//==============================================================================
//
// File:		LDrawModel.h
//
// Purpose:		Represents a collection of Lego bricks that form a single model.
//
//				Bricksmith imposes an arbitrary requirement that a model be 
//				composed of a series of steps. Each model must have at least one 
//				step in it, and only LDrawSteps can be put into the model's 
//				subdirective array. Each LDraw model contains at least one step 
//				even if it contains no 0 STEP commands, since the final step in 
//				the model is not required to have step marker. 
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawModel.h"

#import <string.h>

#import "ColorLibrary.h"
#import "LDrawColor.h"
#import "LDrawConditionalLine.h"
#import "LDrawFile.h"
#import "LDrawKeywords.h"
#import "LDrawLine.h"
#import "LDrawQuadrilateral.h"
#import "LDrawStep.h"
#import "LDrawTriangle.h"
#import "LDrawUtilities.h"
#import "LDrawVertexes.h"
#import "StringCategory.h"


@implementation LDrawModel


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- model ---------------------------------------------------[static]--
//
// Purpose:		Creates a new model ready to be edited.
//
//------------------------------------------------------------------------------
+ (id) model
{
	LDrawModel *newModel = [[[self class] alloc] init];
	
	//Then fill it up with useful initial attributes
	[newModel setModelDescription:NSLocalizedString(@"UntitledModel", nil)];
	[newModel setFileName:@""];
	
	[newModel setAuthor:[LDrawUtilities defaultAuthor]];
	
	//Need to create a blank step.
	[newModel addStep];
	[newModel optimizePrimitiveStructure]; // initialize the vertex container

	return [newModel autorelease];
	
}//end model


//========== init ==============================================================
//
// Purpose:		Creates a new, completely blank model file.
//
//==============================================================================
- (id) init
{
	self = [super init];
	
	self->vertexes      = nil; // not created until -optimizeOpenGL
	self->colorLibrary  = [[ColorLibrary alloc] init];
	self->cachedBounds = InvalidBox;
	[self setModelDescription:@""];
	[self setFileName:@""];
	[self setAuthor:@""];
	
	[self setStepDisplay:NO];
	
	return self;
	
}//end init


//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Creates a new model file based on the lines from a file.
//				These lines of strings should only describe one model, not 
//				multiple ones.
//
//				This method divides the model into steps. A step may be ended 
//				by: 
//					* a 0 STEP line
//					* a 0 ROTSTEP line
//					* the end of the file
//
//				A STEP or ROTSTEP command is part of the step they end, so they 
//				are the last line IN the step. 
//
//				The final step marker is optional. Thus a file that has no step 
//				markers still has one step. 
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSUInteger		contentStartIndex	= 0;
	NSRange			stepRange			= range;
	NSUInteger		maxLineIndex		= 0;
	NSUInteger      insertIndex			= 0;
	id *			substeps			= NULL;
	
	//Start with a nice blank model.
	self = [super initWithLines:lines inRange:range parentGroup:parentGroup];
	self->cachedBounds = InvalidBox;

	substeps = calloc(range.length, sizeof(LDrawDirective*));
	
	//Try and get the header out of the file. If it's there, the lines returned 
	// will not contain it.
	contentStartIndex   = [self parseHeaderFromLines:lines beginningAtIndex:range.location];
	maxLineIndex        = NSMaxRange(range) - 1;

	dispatch_group_t	modelDispatchGroup = NULL;
#if USE_BLOCKS
	modelDispatchGroup = dispatch_group_create();
	dispatch_queue_t	queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	if(parentGroup != NULL)
		dispatch_group_enter(parentGroup);
#endif
	// Parse out steps. Each time we run into a new 0 STEP command, we finish 
	// the current step. 
	do
	{
		stepRange   = [LDrawStep rangeOfDirectiveBeginningAtIndex:contentStartIndex inLines:lines maxIndex:maxLineIndex];
#if USE_BLOCKS
		dispatch_group_async(modelDispatchGroup,queue,
		^{
#endif
			LDrawStep * newStep     = [[LDrawStep alloc] initWithLines:lines inRange:stepRange parentGroup:modelDispatchGroup];
			substeps[insertIndex] = newStep;
#if USE_BLOCKS
		});
#endif
		++insertIndex;

		contentStartIndex = NSMaxRange(stepRange);
		
	}
	while(contentStartIndex < NSMaxRange(range));
		
#if USE_BLOCKS
	dispatch_group_notify(modelDispatchGroup,queue,
	^{
#endif
		NSUInteger      counter				= 0;
		for(counter = 0; counter < insertIndex; counter++)
		{
			LDrawStep * step = substeps[counter];
			
			[self addStep:step];
			[step release];
		}

		free(substeps);
			
		// Degenerate case: utterly empty file. Create one empty step, because it is 
		// illegal to have a 0-step model in Bricksmith. 
		if([[self steps] count] == 0)
		{
			[self addStep];
		}
#if USE_BLOCKS
		if(parentGroup != NULL)
			dispatch_group_leave(parentGroup);
	});
	dispatch_release(modelDispatchGroup);	
#endif	
	return self;
	
}//end initWithLines:inRange:


//========== initWithCoder: ====================================================
//
// Purpose:		Reads a representation of this object from the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (id) initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	self->cachedBounds = InvalidBox;
	
	modelDescription	= [[decoder decodeObjectForKey:@"modelDescription"] retain];
	fileName			= [[decoder decodeObjectForKey:@"fileName"] retain];
	author				= [[decoder decodeObjectForKey:@"author"] retain];
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeObject:modelDescription	forKey:@"modelDescription"];
	[encoder encodeObject:fileName			forKey:@"fileName"];
	[encoder encodeObject:author			forKey:@"author"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawModel *copied = (LDrawModel *)[super copyWithZone:zone];
	copied->cachedBounds = cachedBounds;
	
	[copied setModelDescription:[self modelDescription]];
	[copied setFileName:[self fileName]];
	[copied setAuthor:[self author]];
	
	[copied setStepDisplay:[self stepDisplay]];
	[copied setMaximumStepIndexForStepDisplay:[self maximumStepIndexForStepDisplay]];
	
	//I don't think we care about the cached bounds.
	
	return copied;
	
}//end copyWithZone:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Simply draw all the steps; they will worry about drawing all 
//				their constituents.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	NSArray     *steps              = [self subdirectives];
	NSUInteger  maxIndex            = [self maxStepIndexToOutput];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	// Draw all the steps in the model
	for(counter = 0; counter <= maxIndex; counter++)
	{
		currentDirective = [steps objectAtIndex:counter];
		[currentDirective draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	}
	
	// Draw primitives
	[self->vertexes draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	
	// Draw Drag-and-Drop pieces if we've got 'em.
	if(self->draggingDirectives != nil)
		[self->draggingDirectives draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
		
}//end draw:viewScale:parentColor:


//========== debugDrawboundingBox ==============================================
//
// Purpose:		Draw a translucent visualization of our bounding box to test
//				bounding box caching.
//
//==============================================================================
- (void) debugDrawboundingBox
{
	NSArray     *steps              = [self subdirectives];
	NSUInteger  maxIndex            = [self maxStepIndexToOutput];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	// Draw all the steps in the model
	for(counter = 0; counter <= maxIndex; counter++)
	{
		currentDirective = [steps objectAtIndex:counter];
		[currentDirective debugDrawboundingBox];
	}
	
	[super debugDrawboundingBox];
}//end debugDrawboundingBox


//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Hit-test the geometry.
//
//==============================================================================
- (void) hitTest:(Ray3)pickRay
	   transform:(Matrix4)transform
	   viewScale:(float)scaleFactor
	  boundsOnly:(BOOL)boundsOnly
	creditObject:(id)creditObject
			hits:(NSMutableDictionary *)hits
{
	NSArray     *steps              = [self subdirectives];
	NSUInteger  maxIndex            = [self maxStepIndexToOutput];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	// Draw all the steps in the model
	for(counter = 0; counter <= maxIndex; counter++)
	{
		currentDirective = [steps objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
}


//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
//
// Purpose:		Check for intersections with screen-space geometry.
//
//==============================================================================
- (BOOL)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	if(!VolumeCanIntersectBox(
						[self boundingBox3],
						transform,
						bounds))
	{
		return FALSE;
	}

	NSArray     *steps              = [self subdirectives];
	NSUInteger  maxIndex            = [self maxStepIndexToOutput];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;

	// Draw all the steps in the model
	for(counter = 0; counter <= maxIndex; counter++)
	{
		currentDirective = [steps objectAtIndex:counter];
		if([currentDirective boxTest:bounds transform:transform boundsOnly:boundsOnly creditObject:creditObject hits:hits])
			if(creditObject != nil)
				return TRUE;
	}
	return FALSE;
}//end boxTest:transform:boundsOnly:creditObject:hits:


//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
//
// Purpose:		depthTest finds the closest primitive (in screen space) 
//				overlapping a given point, as well as its device coordinate
//				depth.
//
//==============================================================================
- (void)	depthTest:(Point2) pt 
				inBox:(Box2)bounds 
			transform:(Matrix4)transform 
		 creditObject:(id)creditObject 
		   bestObject:(id *)bestObject 
			bestDepth:(float *)bestDepth
{
	if(!VolumeCanIntersectPoint([self boundingBox3], transform, bounds, *bestDepth)) 
		return;

	NSArray     *steps              = [self subdirectives];
	NSUInteger  maxIndex            = [self maxStepIndexToOutput];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;

	// Draw all the steps in the model
	for(counter = 0; counter <= maxIndex; counter++)
	{
		currentDirective = [steps objectAtIndex:counter];
		[currentDirective depthTest:pt inBox:bounds transform:transform creditObject:creditObject bestObject:bestObject bestDepth:bestDepth];
	}
}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


//========== write =============================================================
//
// Purpose:		Writes out the MPD submodel, wrapped in the MPD file commands.
//
//==============================================================================
- (NSString *) write
{
	NSString        *CRLF           = [NSString CRLF]; //we need a DOS line-end marker, because 
														//LDraw is predominantly DOS-based.
	NSMutableString *written        = [NSMutableString string];
	NSArray         *steps          = [self subdirectives];
	NSUInteger      numberSteps     = [steps count];
	LDrawStep       *currentStep    = nil;
	NSString        *stepOutput     = nil;
	NSUInteger      counter         = 0;
	
	//Write out the file header in all of its irritating glory.
	[written appendFormat:@"0 %@%@", [self modelDescription], CRLF];
	[written appendFormat:@"0 %@ %@%@", LDRAW_HEADER_NAME, [self fileName], CRLF];
	[written appendFormat:@"0 %@ %@%@", LDRAW_HEADER_AUTHOR, [self author], CRLF];		
	
	//Write out all the steps in the file.
	for(counter = 0; counter < numberSteps; counter++)
	{
		currentStep = [steps objectAtIndex:counter];
		
		// Omit the 0 STEP command for 1-step models, which probably aren't 
		// being built with steps in mind anyway. 
		if(numberSteps == 1)
			stepOutput = [currentStep writeWithStepCommand:NO];
		else
			stepOutput = [currentStep write];
		
		[written appendFormat:@"%@%@", stepOutput, CRLF];
	}
	
	//Now remove that last CRLF.
	[written deleteCharactersInRange:NSMakeRange([written length] - [CRLF length], [CRLF length])];
	
	return written;

}//end write


#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) browsingDescription
{
	return [self modelDescription];
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"Document";
	
}//end iconName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== boundingBox3 ======================================================
//
// Purpose:		Returns the minimum and maximum points of the box which 
//				perfectly contains this object.
//
//				We optimize this calculation on models whose dimensions are 
//				known to be constant--parts from the library, for instance.
//
//==============================================================================
- (Box3) boundingBox3
{
	Box3 totalBounds	= InvalidBox;
	Box3 draggingBounds	= InvalidBox;

	if([self revalCache:CacheFlagBounds] == CacheFlagBounds)
	{
		cachedBounds = InvalidBox;
		
		NSArray     *steps              = [self subdirectives];
		NSUInteger  maxIndex            = [self maxStepIndexToOutput];
		LDrawStep   *currentDirective   = nil;
		NSUInteger  counter             = 0;
		// Draw all the steps in the model
		for(counter = 0; counter <= maxIndex; counter++)
		{
			currentDirective = [steps objectAtIndex:counter];
			cachedBounds = V3UnionBox(cachedBounds, [currentDirective boundingBox3]);
		}
	}
	totalBounds = cachedBounds;

	// If drag-and-drop objects are present, add them into the bounds.
	if(self->draggingDirectives != nil)
	{
		draggingBounds	= [LDrawUtilities boundingBox3ForDirectives:[self->draggingDirectives subdirectives]];
		totalBounds		= V3UnionBox(draggingBounds, totalBounds);
	}
	
	return totalBounds;
		
}//end boundingBox3


//========== category ==========================================================
//
// Purpose:		Returns the category to which this model belongs. This is 
//				determined from the description field, which is the first line 
//				of the file for non-MPD documents. For instance:
//
//				0 Brick  2 x  4
//
//				This part would be in the category "Brick", and has the 
//				description "Brick  2 x  4".
//
//==============================================================================
- (NSString *) category
{
	NSString	*category	= nil;
	NSRange		 firstSpace;	//range of the category string in the first line.
	
	//The category name is the first word in the description.
	firstSpace = [(self->modelDescription) rangeOfString:@" "];
	if(firstSpace.location != NSNotFound)
		category = [modelDescription substringToIndex:firstSpace.location];
	else
		category = [NSString stringWithString:modelDescription];
	
	//Clean category name of any weird notational marks
	if([category hasPrefix:@"_"] || [category hasPrefix:@"~"])
		category = [category substringFromIndex:1];
		
	return category;
	
}//end category


//========== colorLibrary ======================================================
//
// Purpose:		Returns the color library object which accumulates the !COLOURS 
//				defined locally within the model. 
//
// Notes:		According to the LDraw color spec, local colors having scoping: 
//				they become active at the point of definition and fall out of 
//				scope at the end of the model. As a convenience in Bricksmith, 
//				the color library will still contain all the local model colors 
//				after a draw is complete--the library will not be purged just 
//				for scoping's sake. It may be purged at the beginning of 
//				drawing, however. 
//
//==============================================================================
- (ColorLibrary *) colorLibrary
{
	return self->colorLibrary;
	
}//end colorLibrary


//========== draggingDirectives ================================================
//
// Purpose:		Returns the objects that are currently being displayed as part 
//			    of drag-and-drop. 
//
//==============================================================================
- (NSArray *) draggingDirectives
{
	return [self->draggingDirectives subdirectives];
	
}//end draggingDirectives


//========== enclosingFile =====================================================
//
// Purpose:		Returns the file in which this model is stored.
//
//==============================================================================
- (LDrawFile *) enclosingFile
{
	return (LDrawFile *)[self enclosingDirective];
	
}//end enclosingFile


//========== modelDescription ==================================================
//
// Purpose:		Returns the model description, which is the first line of the 
//				model. (i.e., Brick 2 x 4)
//
//==============================================================================
- (NSString *)modelDescription
{
	return modelDescription;
	
}//end modelDescription


//========== fileName ==========================================================
//
// Purpose:		Returns the name the model is ostensibly saved under in the 
//				file system.
//
//==============================================================================
- (NSString *)fileName
{
	return fileName;
	
}//end fileName


//========== author ============================================================
//
// Purpose:		Returns the person who created the document.
//
//==============================================================================
- (NSString *)author
{
	return author;
	
}//end author


//========== maximumStepIndexDisplayed =========================================
//
// Purpose:		Returns the index of the last step which will be drawn. The 
//				value only has meaning if the model is in step-display mode. 
//
//==============================================================================
- (NSUInteger) maximumStepIndexForStepDisplay
{
	return self->currentStepDisplayed;
	
}//end maximumStepIndexDisplayed


//========== rotationAngleForStepAtIndex: ======================================
//
// Purpose:		Returns the viewing angle which should be used when displaying 
//				the given step in Step Display mode. 
//
// Notes:		Rotations are NOT built up in a stack. One would think End 
//				Rotation removes an item from the stack, but actually it 
//				restores the default view. Each step rotation completely 
//				replaces the previous rotation, although computing the new value 
//				may require consulting the value about to be replaced. 
//
//				The actual rotation to use is whatever we get by calculating all 
//				the rotations up to and including the specified step. 
//
//				Neither the step, the model, nor any other data-level class is 
//				responsible for enforcing this angle when drawing. It is up to 
//				the document to enforce or ignore the step rotation angle. In 
//				Bricksmith, the document only sets the step rotation when in 
//				Step Display mode, when the step being viewed is changed. 
//
//==============================================================================
- (Tuple3) rotationAngleForStepAtIndex:(NSUInteger)stepNumber
{
	NSArray             *steps              = [self steps];
	LDrawStep           *currentStep        = nil;
	LDrawStepRotationT  rotationType        = LDrawStepRotationNone;
	Tuple3              stepRotationAngle   = ZeroPoint3;
	Tuple3              previousRotation    = ZeroPoint3;
	Tuple3              newRotation         = ZeroPoint3;
	Tuple3              totalRotation       = ZeroPoint3;
	Matrix4             rotationMatrix      = IdentityMatrix4;
	NSUInteger          counter             = 0;
	
	// Start with the default 3D angle onto the stack. If no rotation is ever 
	// specified, that is the one we use. 
	newRotation		= [LDrawUtilities angleForViewOrientation:ViewOrientation3D];
	totalRotation	= newRotation;
	
	// Build the rotation stack
	for(counter = 0; counter <= stepNumber && counter < [steps count]; counter++)
	{
		currentStep			= [steps objectAtIndex:counter];
		rotationType		= [currentStep stepRotationType];
		stepRotationAngle	= [currentStep rotationAngle];
		
		switch(rotationType)
		{
			case LDrawStepRotationNone:
				// Nothing to do here. This means "use whatever was on the stack 
				// last." 
				newRotation = totalRotation;
				break;
		
			case LDrawStepRotationRelative:
				
				// Start with the default 3D rotation
				previousRotation	= [LDrawUtilities angleForViewOrientation:ViewOrientation3D];

				// Add the new value to it.
				rotationMatrix	= Matrix4Rotate(IdentityMatrix4, stepRotationAngle);
				rotationMatrix	= Matrix4Rotate(rotationMatrix,  previousRotation);
				newRotation		= Matrix4DecomposeXYZRotation(rotationMatrix);
				
				// convert from radians to degrees
				newRotation.x	= degrees(newRotation.x);
				newRotation.y	= degrees(newRotation.y);
				newRotation.z	= degrees(newRotation.z);
				break;
				
			case LDrawStepRotationAbsolute:
				
				// Use the step's angle directly
				newRotation		= stepRotationAngle;
				break;
				
			case LDrawStepRotationAdditive:
				
				// Peek at the previous rotation on the stack
				previousRotation = totalRotation;
				
				// Add the new value to it.
				rotationMatrix	= Matrix4Rotate(IdentityMatrix4, stepRotationAngle);
				rotationMatrix	= Matrix4Rotate(rotationMatrix,  previousRotation);
				newRotation		= Matrix4DecomposeXYZRotation(rotationMatrix);
				
				// convert from radians to degrees
				newRotation.x	= degrees(newRotation.x);
				newRotation.y	= degrees(newRotation.y);
				newRotation.z	= degrees(newRotation.z);
				break;
				
			case LDrawStepRotationEnd:
			
				// This means end all rotations and restore the default angle. 
				// It's not a stack. Bizarre. 
				newRotation		= [LDrawUtilities angleForViewOrientation:ViewOrientation3D];
				break;
		}
		
		// Replace the cumulative rotation with the newly-computed one
		totalRotation	= newRotation;
	}
	
	// Return the final calculated angle. This is the absolute rotation to which 
	// we are to set the view. 
	
	return totalRotation;

}//end rotationAngleForStepAtIndex:


//========== stepDisplay =======================================================
//
// Purpose:		Returns YES if the receiver only displays the steps through 
//				the index of the currentStepDisplayed instance variable.
//
//==============================================================================
- (BOOL) stepDisplay
{
	return self->stepDisplayActive;
	
}//end stepDisplay


//========== steps =============================================================
//
// Purpose:		Returns the steps which constitute this model.
//
//==============================================================================
- (NSArray *) steps
{
	return [self subdirectives];
	
}//end steps


//========== vertexes ==========================================================
//
// Purpose:		Returns the optimization object for representing the model's 
//				primitives (which aren't capable of drawing themselves). 
//
//==============================================================================
- (LDrawVertexes *) vertexes
{
	return self->vertexes;
}


//========== visibleStep =======================================================
//
// Purpose:		Returns the last step which would be drawn if this model were 
//				drawn right now.
//
//==============================================================================
- (LDrawStep *) visibleStep
{
	NSArray		*steps		= [self steps];
	LDrawStep	*lastStep	= nil;
	
	if([self stepDisplay] == YES)
		lastStep = [steps objectAtIndex:[self maxStepIndexToOutput]];
	else
		lastStep = [steps lastObject];
	
	return lastStep;
	
}//end visibleStep


#pragma mark -

//========== setDraggingDirectives: ============================================
//
// Purpose:		Sets the parts which are being manipulated in the model via 
//			    drag-and-drop. 
//
//==============================================================================
- (void) setDraggingDirectives:(NSArray *)directives
{
	LDrawStep       *dragStep           = nil;
	LDrawDirective  *currentDirective   = nil;
	NSUInteger      counter             = 0;
	
	// Remove primitives from the previous dragging directives from the 
	// optimized vertexes 
	if(self->draggingDirectives)
	{
		NSMutableArray  *lines              = [NSMutableArray array];
		NSMutableArray  *triangles          = [NSMutableArray array];
		NSMutableArray  *quadrilaterals     = [NSMutableArray array];
		
		[self->draggingDirectives flattenIntoLines:lines
										 triangles:triangles
									quadrilaterals:quadrilaterals
											 other:nil
									  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
								  currentTransform:IdentityMatrix4
								   normalTransform:IdentityMatrix3
										 recursive:NO];

		for(LDrawLine *directive in lines)
			[self->vertexes removeLine:directive];

		for(LDrawTriangle *directive in triangles)
			[self->vertexes removeTriangle:directive];

		for(LDrawQuadrilateral *directive in quadrilaterals)
			[self->vertexes removeQuadrilateral:directive];
	}
	
	// When we get sent nil directives, nil out the drag step.
	if(directives != nil)
	{
		dragStep	= [LDrawStep emptyStep];
		
		// The law of Bricksmith is that all parts in a model must be enclosed in a 
		// step. Resistance is futile.
		for(counter = 0; counter < [directives count]; counter++)
		{
			currentDirective = [directives objectAtIndex:counter];
			[dragStep addDirective:currentDirective];
		}
		
		// Tell the element that it lives in us now. This is important for 
		// submodel references being dragged; without it, they have no way of 
		// resolving their part reference, and thus can't draw during their 
		// drag. 
		[dragStep setEnclosingDirective:self];
		
		
		//---------- Optimize primitives ---------------------------------------
		
		NSMutableArray  *lines              = [NSMutableArray array];
		NSMutableArray  *triangles          = [NSMutableArray array];
		NSMutableArray  *quadrilaterals     = [NSMutableArray array];
		
		[dragStep flattenIntoLines:lines
						 triangles:triangles
					quadrilaterals:quadrilaterals
							 other:nil
					  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
				  currentTransform:IdentityMatrix4
				   normalTransform:IdentityMatrix3
						 recursive:NO];
		
		for(LDrawLine *directive in lines)
			[self->vertexes addLine:directive];
		
		for(LDrawTriangle *directive in triangles)
			[self->vertexes addTriangle:directive];
		
		for(LDrawQuadrilateral *directive in quadrilaterals)
			[self->vertexes addQuadrilateral:directive];
	}
	
	[dragStep retain];
	[self->draggingDirectives release];
	
	self->draggingDirectives = dragStep;
	
	[self optimizeVertexes];
	
}//end setDraggingDirectives:


//========== setModelDescription: ==============================================
//
// Purpose:		Sets a new model description.
//
//==============================================================================
- (void) setModelDescription:(NSString *)newDescription
{
	[newDescription retain];
	[modelDescription release];
	
	modelDescription = newDescription;
	
}//end setModelDescription:


//========== setFileName: ======================================================
//
// Purpose:		Sets the name the model is ostensibly saved under in the 
//				file system. This may take on a rather different meaning in 
//				multi-part documents. It also has no real connection with the 
//				actual filesystem name.
//
//==============================================================================
- (void) setFileName:(NSString *)newName
{
	[newName retain];
	[fileName release];
	
	fileName = newName;
	
}//end setFileName:


//========== setAuthor: ========================================================
//
// Purpose:		Changes the name of the person who created the model.
//
//==============================================================================
- (void) setAuthor:(NSString *)newAuthor
{
    // LLW - Don't allow author to be set to nil, as this causes funky
    // behavior in the inspector
    if (newAuthor == nil)
        newAuthor = @"";
	[newAuthor retain];
	[author release];
	
	author = newAuthor;
	
}//end setAuthor:


//========== setMaximumStepIndexForStepDisplay: ================================
//
// Purpose:		Sets the index of the last step drawn. If the model is not 
//				currently in step-display mode, this call will NOT cause it to 
//				enter step display. 
//
//==============================================================================
- (void) setMaximumStepIndexForStepDisplay:(NSUInteger)stepIndex
{
	//Need to check and make sure this step number is not overflowing the bounds.
	NSInteger maximumIndex = [[self steps] count]-1;
	
	if(stepIndex > maximumIndex || stepIndex < 0)
		[NSException raise:NSRangeException format:@"index (%ld) beyond maximum step index %ld", (long)stepIndex, (long)maximumIndex];
	else
	{
		[self invalCache:CacheFlagBounds];	
		self->currentStepDisplayed = stepIndex;
	}
	
}//end setMaximumStepIndexForStepDisplay:


//========== setStepDisplay ====================================================
//
// Purpose:		Sets whether the receiver only displays the steps through 
//				the index of the currentStepDisplayed instance variable.
//
//==============================================================================
- (void) setStepDisplay:(BOOL)flag
{
	[self invalCache:CacheFlagBounds];	
	self->stepDisplayActive = flag;
	
}//end setStepDisplay:


//========== setVertexesNeedRebuilding =========================================
//
// Purpose:		Marks all the optimizations of this vertex collection as needing 
//				rebuilding. 
//
//==============================================================================
- (void) setVertexesNeedRebuilding
{
	[self->vertexes setVertexesNeedRebuilding];
}


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== addStep ===========================================================
//
// Purpose:		Creates a new blank step at the end of the model. Returns the 
//				new step created.
//
//==============================================================================
- (LDrawStep *) addStep
{
	LDrawStep *newStep = [LDrawStep emptyStep];
	
	[self addDirective:newStep]; //adds the step and tells it who it belongs to.
	
	return newStep;
	
}//end addStep


//========== addStep: ==========================================================
//
// Purpose:		Adds newStep at the end of the model.
//
//==============================================================================
- (void) addStep:(LDrawStep *)newStep
{
	[self addDirective:newStep];
	
}//end addStep:


//========== makeStepVisible: ==================================================
//
// Purpose:		Guarantees that the given step is visible in this model.
//
//==============================================================================
- (void) makeStepVisible:(LDrawStep *)step
{
	NSUInteger stepIndex = [self indexOfDirective:step];
	
	// If we're in step display, but below this step, make it visible.
	if(		stepIndex != NSNotFound
		&&	stepIndex > [self maxStepIndexToOutput])
	{
		[self setMaximumStepIndexForStepDisplay:stepIndex];
	}
	// Otherwise, we see everything, so by definition this step is visible.
	
}//end makeStepVisible


//========== removeDirectiveAtIndex: ===========================================
//
// Purpose:		Removes one directive from our container.  We override this
//				to find out our directive index _before_ the removal so we can
//				keep our current step in sync!
//
//==============================================================================
- (void) removeDirectiveAtIndex:(NSInteger)idx
{
	[self invalCache:CacheFlagBounds];
	if(idx <= currentStepDisplayed && currentStepDisplayed > 0)
		--currentStepDisplayed;
	
	[super removeDirectiveAtIndex:idx];
}


- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index;
{
	[self invalCache:CacheFlagBounds];
	[super insertDirective:directive atIndex:index];
}	

#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== didAddDirective: ==================================================
//
// Purpose:		One of the model's children has added a new directive which the 
//				model is responsible for drawing. 
//
//==============================================================================
- (void) didAddDirective:(LDrawDirective *)directive
{
	[vertexes addDirective:directive];
}


//========== didRemoveDirective: ===============================================
//
// Purpose:		One of the model's children has added a new directive which the 
//				model is responsible for drawing. 
//
//==============================================================================
- (void) didRemoveDirective:(LDrawDirective *)directive
{
	[vertexes removeDirective:directive];
}

#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== maxStepIndexToOutput ==============================================
//
// Purpose:		Returns the index of the last step which should be displayed.
//
// Notes:		This is always supposed to return an index >= 0, simply because 
//				it is illegal for a model to have no steps in Bricksmith. 
//
//==============================================================================
- (NSUInteger) maxStepIndexToOutput
{
	NSArray     *steps  = [self subdirectives];
	NSUInteger  maxStep = 0;
	
	// If step display is active, we want to display only as far as the 
	// specified step, or the maximum step if the one specified exceeds the 
	// number of steps. 
	if(self->stepDisplayActive == YES)
	{
		maxStep = MIN( [steps count] -1 , //subtract one to get last step index in model.
					   self->currentStepDisplayed);
	}
	else
	{
		maxStep = [steps count] - 1;
	}
	
	return maxStep;
	
}//end maxStepIndexToOutput


//========== numberElements ====================================================
//
// Purpose:		Returns the number of elements found in this model. Currently 
//				this does not recurse into MPD submodels which have been 
//				included.
//
//==============================================================================
- (NSUInteger) numberElements
{
	NSArray     *steps          = [self steps];
	LDrawStep   *currentStep    = nil;
	NSUInteger  numberElements  = 0;
	NSUInteger  counter         = 0;
	
	for(counter = 0; counter < [steps count]; counter++)
	{
		currentStep     = [steps objectAtIndex:counter];
		numberElements  += [[currentStep subdirectives] count];
	}
	
	return numberElements;
	
}//end numberElements


//========== optimizeOpenGL ====================================================
//
// Purpose:		Collect members into optimized OpenGL containers.
//
// Notes:		This method is NOT thread safe.
//
//==============================================================================
- (void) optimizeOpenGL
{
	// Allow primitives to be visible when displaying the model itself.
	[self optimizeVertexes];
	
	[super optimizeOpenGL];
}


//========== optimizePrimitiveStructure ========================================
//
// Purpose:		Finds all the primitives which are direct children of the model 
//				and records them in an optimizable vertex object. 
//
//==============================================================================
- (void) optimizePrimitiveStructure
{
	// Collect all primitives into a single object which can draw them without 
	// using immediate mode. 
	if(self->vertexes == nil)
	{
		// We must create the vertex object HERE, because it is not thread-safe 
		// and will ordinarily be written to when adding and removing 
		// directives. Since the initial parse is multithreaded, we cannot allow 
		// this object to be used until the model has been fully parsed. 
		self->vertexes = [[LDrawVertexes alloc] init];
		[vertexes setAcceptsNonPrimitives:NO]; // we are responsible for drawing non-primitive objects
		
		NSMutableArray  *lines              = [NSMutableArray array];
		NSMutableArray  *triangles          = [NSMutableArray array];
		NSMutableArray  *quadrilaterals     = [NSMutableArray array];
		
		[self flattenIntoLines:lines
					 triangles:triangles
				quadrilaterals:quadrilaterals
						 other:nil // ONLY collect primitives; all other elements will be drawn in the normal draw recursion
				  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
			  currentTransform:IdentityMatrix4
			   normalTransform:IdentityMatrix3
					 recursive:NO];
		
		[vertexes setLines:lines triangles:triangles quadrilaterals:quadrilaterals other:nil];
	}
}//end optimizePrimitiveStructure


//========== optimizeStructure =================================================
//
// Purpose:		Arranges the directives in such a way that the file will be 
//				drawn faster. This method should *never* be called on files 
//				which the user has created himself, since it reorganizes the 
//				file contents. It is intended only for parts read from the part  
//				library.
//
//				To optimize, we flatten all the primitives referenced by a part 
//				into a non-nested structure, then separate all the directives 
//				out by the type: all triangles go in a step, all quadrilaterals 
//				go in their own step, etc. 
//
//				Then when drawing, we need not call glBegin() each time. The 
//				result is a speed increase of over 1000%. 
//
//				1000%. That is not a typo.
//
//==============================================================================
- (void) optimizeStructure
{
	NSArray         *steps              = [self subdirectives];
	
	NSMutableArray  *lines              = [NSMutableArray array];
	NSMutableArray  *triangles          = [NSMutableArray array];
	NSMutableArray  *quadrilaterals     = [NSMutableArray array];
	NSMutableArray  *everythingElse     = [NSMutableArray array];
	
	LDrawStep       *linesStep          = [LDrawStep emptyStepWithFlavor:LDrawStepLines];
	LDrawStep       *trianglesStep      = [LDrawStep emptyStepWithFlavor:LDrawStepTriangles];
	LDrawStep       *quadrilateralsStep = [LDrawStep emptyStepWithFlavor:LDrawStepQuadrilaterals];
	LDrawStep       *everythingElseStep = [LDrawStep emptyStepWithFlavor:LDrawStepAnyDirectives];
	
	NSUInteger      directiveCount      = 0;
	NSInteger       counter             = 0;
	
	// Traverse the entire hiearchy of part references and sort out each 
	// primitive type into a flat list. This allows staggering speed increases. 
	//
	// If we were to only sort without flattening, we would get a 100% speed 
	// increase. But flattening and sorting yields over 1000%. 
	[self flattenIntoLines:lines
				 triangles:triangles
			quadrilaterals:quadrilaterals
					 other:everythingElse
			  currentColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
		  currentTransform:IdentityMatrix4
		   normalTransform:IdentityMatrix3
				 recursive:YES];
		  
	// Now that we have everything separated, remove the main step (it's the one 
	// that has the entire model in it) and . 
	directiveCount = [steps count];
	for(counter = (directiveCount - 1); counter >= 0; counter--)
	{
		[self removeDirectiveAtIndex:counter];
	}
	
	// Replace the original directives with the categorized steps we've created 
	if([lines count] > 0)
	{
		for(id directive in lines)
		{
			[linesStep addDirective:directive];
		}
		[self addDirective:linesStep];
	}

	if([triangles count] > 0)
	{
		for(id directive in triangles)
		{
			[trianglesStep addDirective:directive];
		}
		[self addDirective:trianglesStep];
	}
	if([quadrilaterals count] > 0)
	{
		for(id directive in quadrilaterals)
		{
			[quadrilateralsStep addDirective:directive];
		}
		[self addDirective:quadrilateralsStep];
	}
	if([everythingElse count] > 0 || [[self subdirectives] count] == 0)
	{								// Make sure there is at least one step in the model!
		for(id directive in everythingElse)
		{
			[everythingElseStep addDirective:directive];
		}
		[self addDirective:everythingElseStep];
	}
		
}//end optimizeStructure


//========== optimizeVertexes ==================================================
//
// Purpose:		Makes sure the vertexes (collected in 
//				-optimizePrimitiveStructure) are displayable. This is called in 
//				response to changing the vertexes, so all existing optimizations 
//				must be destroyed. 
//
//==============================================================================
- (void) optimizeVertexes
{
	[super optimizeVertexes];

	// Allow primitives to be visible when displaying the model itself.
	LDrawColor *parentColor = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor];
	
	if([vertexes isOptimizedForColor:parentColor])
	{
		// The vertexes have already been optimized for any referencing colors. 
		// Just rebuild the existing color optimizations. 
		[self->vertexes rebuildAllOptimizations];
	}
	else
	{
		// Newly-created, empty vertexes. Make a list to display the model itself. 
		[self->vertexes optimizeOpenGLWithParentColor:parentColor];
	}
}//end optimizeVertexes


//========== parseHeaderFromLines:beginningAtIndex: ============================
//
// Purpose:		Given lines from an LDraw document, fill in the model header 
//				info. It should be of the following format:
//
//				0 7140 X-Wing Fighter
//				0 Name: main.ldr
//				0 Author: Tim Courtney <tim@zacktron.com>
//				0 LDraw.org Official Model Repository
//				0 http://www.ldraw.org/repository/official/
//
//				Note, however, that this information is *not* required, so it 
//				may not be there. Consequently, the code below is a nightmarish
//				unmaintainable mess.
//
//				Returns the line index of the first non-header line.
//
//==============================================================================
- (NSUInteger) parseHeaderFromLines:(NSArray *)lines
				   beginningAtIndex:(NSUInteger)index
{
	NSString	*currentLine		= nil;
	NSUInteger	counter 			= 0;
	BOOL		lineValidForHeader	= NO;
	NSUInteger	firstNonHeaderIndex = index;
	NSString	*payload			= nil;
	
	@try
	{
		//First line. Should be a description of the model.
		currentLine = [lines objectAtIndex:index];
		if([self line:currentLine isValidForHeader:@"" info:&payload])
		{
			[self setModelDescription:payload];
			firstNonHeaderIndex++;
		}
		
		//There are at least three more lines in a valid header.
		// Read the first four lines, and try to get the model info out of 
		// them.
		lineValidForHeader	= YES;
		for(counter = firstNonHeaderIndex; counter < firstNonHeaderIndex + 3 && lineValidForHeader == YES; counter++)
		{
			currentLine         = [lines objectAtIndex:counter];
			lineValidForHeader  = NO; // assume not, then disprove
			payload				= nil;
			
			//Second line. Should be file name.
			if([self line:currentLine isValidForHeader:LDRAW_HEADER_NAME info:&payload])
			{
				[self setFileName:payload];
				lineValidForHeader = YES;
			}
			//Third line. Should be author name.
			else if([self line:currentLine isValidForHeader:LDRAW_HEADER_AUTHOR info:&payload])
			{
				[self setAuthor:payload];
				lineValidForHeader = YES;
			}
			//Fourth line. MLCad used it as a nonstandard way of indicating 
			//official status. Since it was nonstandard, nobody used it. 
			else if([self line:currentLine isValidForHeader:@"" info:&payload])
			{
				if(		[payload isEqualToString:@"LDraw.org Official Model Repository"]
				   ||	[payload isEqualToString:@"Unofficial Model"] )
				{
					// Bricksmith followed MLCad spewing out this garbage for 
					// years. It is unnecessary. Now I am just stripping it out 
					// of any file I encounter. 
					lineValidForHeader = YES;
				}
			}
			
			if(lineValidForHeader == YES)
			{
				firstNonHeaderIndex++;
			}
		}
	}	
	@catch(NSException *exception)
	{
		//Ran out of lines in the file. Oh well. We got what we got.
	}
		
	return firstNonHeaderIndex;
	
}//end parseHeaderFromLines


//========== line:isValidForHeader: ============================================
//
// Purpose:		Determines if the given line of LDraw is formatted to be the 
//				the specified field in a model header.
//
//==============================================================================
- (BOOL)		line:(NSString *)line
	isValidForHeader:(NSString *)headerKey
				info:(NSString**)infoPtr
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isValid	= NO;
	
	parsedField = [LDrawUtilities readNextField:  line
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		if([headerKey length] > 0)
		{
			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
			isValid = [parsedField isEqualToString:headerKey];
		}
		else
		{
			isValid = YES;
		}

		
		if(isValid)
		{
			if(infoPtr)
				*infoPtr = [workingLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		}
	}
	
	return isValid;
	
}//end line:isValidForHeader:


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setAuthor:[self author]];
	[[undoManager prepareWithInvocationTarget:self] setFileName:[self fileName]];
	[[undoManager prepareWithInvocationTarget:self] setModelDescription:[self modelDescription]];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAttributesModel", nil)];
	
}//end registerUndoActions:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		So I go to the pet store to buy a dog. And this guy sells me 
//				this puppy with three heads. Where in the world did he find a 
//				freak like that? So I says, "buddy, I want a normal dog." And 
//				the guy says, "Mister, where you're going, this dog *is* normal.
//				Weird.
//
//==============================================================================
- (void) dealloc
{
	[modelDescription	release];
	[fileName			release];
	[author				release];
	
	[vertexes			release];
	[colorLibrary		release];
	
	[super dealloc];
	
}//end dealloc


@end
