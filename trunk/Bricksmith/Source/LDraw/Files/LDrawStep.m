//==============================================================================
//
// File:		LDrawStep.h
//
// Purpose:		Represents a collection of Lego bricks which compose a single 
//				step when constructing a model.
//
//				A step, of course, corresponds to a step in a set of Lego set 
//				instructions.
//
//				The subdirectives which make up a step are a list of 
//				LDrawDirectives including parts, primitives, and meta-commands.
//
//				Steps may have rotations associated with them. A step rotation 
//				defines the viewing angle at which the step is intended to be 
//				displayed (for instance, upside-down). However, since steps are 
//				drawn in a pipeline, they can't actually draw their own 
//				rotations. It is the responsibility of the controller object to 
//				enforce the rotation defined by the step. In Bricksmith, step 
//				rotations are only honored when the model is being drawn in Step 
//				Display mode. 
//
//				The step rotation functionality was originally defined by MLCad.
//
//  Created by Allen Smith on 2/20/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawStep.h"

#if USE_BLOCKS
#import <dispatch/dispatch.h>
#endif

#import "LDrawKeywords.h"
#import "LDrawModel.h"
#import "LDrawUtilities.h"
#import "StringCategory.h"


@implementation LDrawStep

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- emptyStep -----------------------------------------------[static]--
//
// Purpose:		Creates a new step ready to be edited, with nothing inside it.
//
//------------------------------------------------------------------------------
+ (id) emptyStep
{
	LDrawStep *newStep = [[LDrawStep alloc] init];
	
	return [newStep autorelease];
	
}//end emptyStep


//---------- emptyStepWithFlavor: ------------------------------------[static]--
//
// Purpose:		Creates a new step ready to be edited, and prespecifies that 
//				only directives of the flavorType will be added.
//
//------------------------------------------------------------------------------
+ (id) emptyStepWithFlavor:(LDrawStepFlavorT) flavorType
{
	LDrawStep *newStep = [LDrawStep emptyStep];
	[newStep setStepFlavor:flavorType];
	
	return newStep;
	
}//end emptyStepWithFlavor:


#pragma mark -

//========== init ==============================================================
//
// Purpose:		Creates a new step ready to be edited, with nothing inside it.
//
//==============================================================================
- (id) init
{
	[super init];
	
	stepRotationType	= LDrawStepRotationNone;
	rotationAngle		= ZeroPoint3;
	stepFlavor			= LDrawStepAnyDirectives;
	
	return self;
	
}//end init


//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Parses a step beginning at the specified line of LDraw code.
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
			 inRange:(NSRange)range
		 parentGroup:(dispatch_group_t)parentGroup
{
	NSString        *currentLine        = nil;
	Class           CommandClass        = Nil;
	NSRange         commandRange        = range;
	id              *directives         = calloc(range.length, sizeof(LDrawDirective*));
	NSUInteger      lineIndex           = 0;
	NSUInteger      insertIndex         = 0;
		
	self = [super initWithLines:lines inRange:range parentGroup:parentGroup];
	
#if USE_BLOCKS
	dispatch_queue_t    queue               = NULL;	
	dispatch_group_t    stepDispatchGroup   = NULL;
	
	// Create a group for the multithreaded parsing of the step contents.
	queue               = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);	
	stepDispatchGroup   = dispatch_group_create();
	
	// Prevent the owning group from completing until the step is finished 
	// asynchronously parsing its contents. 
	if(parentGroup != NULL)
	{
		dispatch_group_enter(parentGroup);
	}
#endif	

	// Parse out the STEP command
	if(range.length > 0)
	{
		currentLine = [lines objectAtIndex:(NSMaxRange(range) - 1)];
		
		// See if the line is a step delimiter. If the delimiter doesn't exist, 
		// it's implied (such as in a 1-step model). Otherwise, it marks the end 
		// of the step. 
		if([[self class] lineIsStepTerminator:currentLine])
		{
			// Nothing more to parse. Stop.
			range.length -= 1;
		}
		else if([[self class] lineIsRotationStepTerminator:currentLine])
		{
			// Parse the rotation step.
			if([self parseRotationStepFromLine:currentLine] == NO)
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad rotstep syntax" userInfo:nil];
			
			range.length -= 1;
		}
	}
	
	// Convert each non-step-delimiter line into a directive, and add it to this 
	// step. 
	lineIndex = range.location;
	while(lineIndex < NSMaxRange(range))
	{
		currentLine = [lines objectAtIndex:lineIndex];
		if([currentLine length] > 0)
		{
			CommandClass = [LDrawUtilities classForDirectiveBeginningWithLine:currentLine];
			commandRange = [CommandClass rangeOfDirectiveBeginningAtIndex:lineIndex
																  inLines:lines
																 maxIndex:NSMaxRange(range) - 1];
#if USE_BLOCKS
			// Parse (multithreaded)
			dispatch_group_async(stepDispatchGroup, queue,
			^{
#endif
				// Parse but disallow multithreading for subparsing. LDraw 
				// objects be be deeply recursive, which means we would pile 
				// up a lot of dispatch_group_wait calls, resulting in so 
				// many threads we run out of stack space. 
				LDrawDirective *newDirective = [[CommandClass alloc] initWithLines:lines inRange:commandRange parentGroup:parentGroup];
				
				// Store non-retaining, but *thread-safe* container 
				// (NSMutableArray is NOT). Since it doesn't retain, we mustn't 
				// autorelease newDirective. 
				directives[insertIndex] = newDirective;
#if USE_BLOCKS
			});
#endif
			lineIndex     = NSMaxRange(commandRange);
			insertIndex += 1;
		}
		else
		{
			lineIndex += 1;
		}

	}
	
#if USE_BLOCKS
	dispatch_group_notify(stepDispatchGroup, queue,
	^{
#endif
		NSUInteger      counter             = 0;
		LDrawDirective  *currentDirective   = nil;

		// Add the accumulated directives *in order*
		for(counter = 0; counter < insertIndex; counter++)
		{
			currentDirective = directives[counter];
			
			[self addDirective:currentDirective];
			[currentDirective release];
		}
		free(directives);
		
#if USE_BLOCKS
		// Now that the step is complete, we can release our lock on the 
		// parent group and allow it to finish. 
		if(parentGroup != NULL)
		{
			dispatch_group_leave(parentGroup);
		}
	});
	dispatch_release(stepDispatchGroup);
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
- (id)initWithCoder:(NSCoder *)decoder
{
	const uint8_t *temporary = NULL; //pointer to a temporary buffer returned by the decoder.

	self = [super initWithCoder:decoder];
	
	temporary = [decoder decodeBytesForKey:@"rotationAngle" returnedLength:NULL];
	memcpy(&rotationAngle, temporary, sizeof(Tuple3));
	
	stepRotationType = [decoder decodeIntForKey:@"stepRotationType"];
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeBytes:(void *)&rotationAngle length:sizeof(Tuple3)	forKey:@"rotationAngle"];
	[encoder encodeInt:stepRotationType									forKey:@"stepRotationType"];

}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawStep	*copied	= (LDrawStep *)[super copyWithZone:zone];
	
	[copied setStepFlavor:self->stepFlavor];
	[copied setStepRotationType:self->stepRotationType];
	[copied setRotationAngle:self->rotationAngle];
	
	return copied;
	
}//end copyWithZone:


#pragma mark -

//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
//
// Purpose:		Returns the range from the beginning to the end of the step.
//
//------------------------------------------------------------------------------
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
									 inLines:(NSArray *)lines
									maxIndex:(NSUInteger)maxIndex
{
	NSString    *currentLine    = nil;
	NSUInteger  counter         = 0;
	NSRange     testRange       = NSMakeRange(index, maxIndex - index + 1);
	NSInteger	stepLength		= 0;
	NSRange		stepRange;
	
	// Find the last line in the step. Steps either end with the step delimiter, 
	// or they simply go all the way to the end of the file. 
	// Convert each non-step-delimiter line into a directive, and add it to this 
	// step. 
	for(counter = testRange.location; counter < NSMaxRange(testRange); counter++)
	{
		currentLine = [lines objectAtIndex:counter];
		stepLength++;
		
		// See if the line is a step delimiter. If the delimiter doesn't exist, 
		// it's implied (such as in a 1-step model). Otherwise, it marks the end 
		// of the step. 
		if(		[[self class] lineIsStepTerminator:currentLine]
		   ||	[[self class] lineIsRotationStepTerminator:currentLine] )
		{
			// Nothing more to parse. Stop.
			break;
		}
	}
	
	stepRange = NSMakeRange(index, stepLength);
	
	return stepRange;
	
}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Draw all the commands in the step.
//
//				Certain steps are marked as having been optimized for fast 
//				drawing. Such steps consist entirely of one kind of directive, 
//				so we need call glBegin only once for the entire step.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	NSArray         *commandsInStep     = [self subdirectives];
	LDrawDirective  *currentDirective   = nil;
	
	//Draw each element in the step.
	for(currentDirective in commandsInStep)
	{
		[currentDirective draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
	}

}//end draw:viewScale:parentColor:


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
	NSArray     *commandsInStep     = [self subdirectives];
	NSUInteger  commandCount        = [commandsInStep count];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	
	// Draw all the steps in the model
	for(counter = 0; counter < commandCount; counter++)
	{
		currentDirective = [commandsInStep objectAtIndex:counter];
		[currentDirective hitTest:pickRay transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}
}


//========== boxTest:transform:viewScale:boundsOnly:creditObject:hits: =======
//
// Purpose:		Check for intersections with screen-space geometry.
//
//==============================================================================
- (void)    boxTest:(Box2)bounds
		  transform:(Matrix4)transform 
		  viewScale:(float)scaleFactor 
		 boundsOnly:(BOOL)boundsOnly 
	   creditObject:(id)creditObject 
	           hits:(NSMutableSet *)hits
{
	NSArray     *commandsInStep     = [self subdirectives];
	NSUInteger  commandCount        = [commandsInStep count];
	LDrawStep   *currentDirective   = nil;
	NSUInteger  counter             = 0;
	NSValue *	creditValue = creditObject ? [NSValue valueWithPointer:creditObject] : nil;
	
	
	// Draw all the steps in the model
	for(counter = 0; counter < commandCount; counter++)
	{
		// This early exit is REALLY important for performance.  Basically once we discover that we have hit even a single stud of a large part, it's a total
		// waste of time to (1) geometrically test the rest of the part (any in is all in) and (2) thrash the life out of our NSSet with a ton of duplicate 
		// insertions. So...
		//
		/// If there is a credit object passed in (meaning we are below a directive that will be atomically all-in selected, like a part or submodel)
		// and we have already selected it, just stop.  That means some time through our past for-loop we got our part, so we can quit testing.
		//
		// We do this optimization in a few places: model iteration, step sub-iteration, and the vertex buffer has this too.  
		if(creditObject && [hits containsObject:creditValue])
			return;
	
		currentDirective = [commandsInStep objectAtIndex:counter];
		[currentDirective boxTest:bounds transform:transform viewScale:scaleFactor boundsOnly:boundsOnly creditObject:creditObject hits:hits];
	}

}


//========== write =============================================================
//
// Purpose:		Write out all the commands in the step, prefaced by the line 
//				0 STEP
//
//==============================================================================
- (NSString *) write
{
	return [self writeWithStepCommand:YES];
	
}//end write


//========== writeWithStepCommand: =============================================
//
// Purpose:		Write out all the commands in the step. The output will be 
//				postfaced by the line 0 STEP if explicitStep is true. 
//				The reason this method exists is that we do not want to write 
//				the step command for the last step in the file. That step 
//				is inferred rather than explicit.
//
// Note:		flag is ignored if this is a rotation step. In that case, you 
//				get the step command no matter what.  
//
//==============================================================================
- (NSString *) writeWithStepCommand:(BOOL)flag
{
	NSMutableString *written        = [NSMutableString string];
	NSString        *CRLF           = [NSString CRLF];
	Tuple3          angleZYX        = [self rotationAngleZYX];
	
	NSArray         *commandsInStep = [self subdirectives];
	LDrawDirective  *currentCommand = nil;
	NSUInteger      numberCommands  = [commandsInStep count];
	NSUInteger      counter         = 0;
	
	// Write all the step's subdirectives
	for(counter = 0; counter < numberCommands; counter++)
	{
		currentCommand = [commandsInStep objectAtIndex:counter];
		[written appendFormat:@"%@%@", [currentCommand write], CRLF];
	}
	
	// End with 0 STEP or 0 ROTSTEP
	if(		flag == YES
		||	self->stepRotationType != LDrawStepRotationNone )
	{
		switch(self->stepRotationType)
		{
			case LDrawStepRotationNone:
				[written appendFormat:@"0 %@", LDRAW_STEP_TERMINATOR];
				break;
			
			case LDrawStepRotationRelative:
				[written appendFormat:@"0 %@ %.3f %.3f %.3f %@",LDRAW_ROTATION_STEP_TERMINATOR,
																angleZYX.x, 
																angleZYX.y, 
																angleZYX.z, 
																LDRAW_ROTATION_RELATIVE ];
				break;
			
			case LDrawStepRotationAbsolute:
				[written appendFormat:@"0 %@ %.3f %.3f %.3f %@",LDRAW_ROTATION_STEP_TERMINATOR,
																angleZYX.x, 
																angleZYX.y, 
																angleZYX.z, 
																LDRAW_ROTATION_ABSOLUTE ];
				break;
			
			case LDrawStepRotationAdditive:
				[written appendFormat:@"0 %@ %.3f %.3f %.3f %@",LDRAW_ROTATION_STEP_TERMINATOR,
																angleZYX.x, 
																angleZYX.y, 
																angleZYX.z, 
																LDRAW_ROTATION_ADDITIVE ];
				break;
			
			case LDrawStepRotationEnd:
				[written appendFormat:@"0 %@ %@", LDRAW_ROTATION_STEP_TERMINATOR, LDRAW_ROTATION_END];
				break;
		}
	}
	
	//Now remove that last CRLF, if it's there.
	if([written hasSuffix:CRLF])
	{
		NSRange lastNewline = NSMakeRange([written length] - [CRLF length], [CRLF length]);
		[written deleteCharactersInRange:lastNewline];
	}
	
	return written;
	
}//end writeWithStepCommand:


#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *)browsingDescription
{
	LDrawModel  *enclosingModel = [self enclosingModel];
	NSString    *description    = nil;
	
	//If there is no parent model, just display the word step. This situtation 
	// would be highly irregular.
	if(enclosingModel == nil)
		description = NSLocalizedString(@"Step", nil);
	
	else{
		//Return the step number.
		NSArray     *modelSteps = [enclosingModel steps];
		NSUInteger  stepIndex   = [modelSteps indexOfObjectIdenticalTo:self];
		
		description = [NSString stringWithFormat:
							NSLocalizedString(@"StepDisplayWithNumber", nil),
							(long)stepIndex + 1] ;
	}
	
	return description;
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	NSString	*iconName	= nil;

	switch(self->stepRotationType)
	{
		case LDrawStepRotationNone:
			// no image.
			break;
	
		case LDrawStepRotationEnd:
			iconName = @"RotationStepEnd";
			break;
			
		default:
			iconName = @"RotationStep";
			break;
	}
	
	return iconName;
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionStep";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== enclosingModel ====================================================
//
// Purpose:		Returns the model of which this step is a part.
//
//==============================================================================
- (LDrawModel *) enclosingModel
{
	return (LDrawModel *)[self enclosingDirective];
}//end enclosingModel


//========== rotationAngle =====================================================
//
// Purpose:		Returns the xyz angle in degrees of the rotation. The value must 
//				be interpreted according to the step rotation type. 
//
//==============================================================================
- (Tuple3) rotationAngle
{
	return self->rotationAngle;

}//end rotationAngle


//========== rotationAngleZYX ==================================================
//
// Purpose:		Returns the zyx angle in degrees of the rotation.
//
// Notes:		Of of Bricksmith's matrix math functions expect angles to be in 
//				x-y-z order, so this value is not useful internally. However, 
//				the ROTSTEP directive (and the rest of MLCad) uses a z-y-x 
//				angle, so we have to save to the file in this format.
//
//==============================================================================
- (Tuple3) rotationAngleZYX
{
	//---------- Convert XYZ to ZYX --------------------------------------------
	
	// Translate our internal XYZ angle to ZYX by creating a rotation matrix and 
	// decomposing it in a different order. 

	Matrix4	rotationMatrix	= Matrix4Rotate(IdentityMatrix4, self->rotationAngle);
	Tuple3	angleZYX		= Matrix4DecomposeZYXRotation(rotationMatrix);
	
	// convert from radians to degrees
	angleZYX.x	= degrees(angleZYX.x);
	angleZYX.y	= degrees(angleZYX.y);
	angleZYX.z	= degrees(angleZYX.z);
	
	
	//---------- Fix weird float values ----------------------------------------
	
	// Sometimes these get decomposed with a -180 rotation, which is the same as 
	// a 180 rotation. Fix it for display purposes. 
	if(FloatsApproximatelyEqual(angleZYX.x, -180.0))
		angleZYX.x = 180;
	
	if(FloatsApproximatelyEqual(angleZYX.y, -180.0))
		angleZYX.y = 180;
	
	if(FloatsApproximatelyEqual(angleZYX.z, -180.0))
		angleZYX.z = 180;

	// Sometimes we wind up with a -0 rotation, which ought to be plain old 0. 
	// Fix it for display purposes. 
	if(FloatsApproximatelyEqual(angleZYX.x, -0.0))
		angleZYX.x = 0;
	
	if(FloatsApproximatelyEqual(angleZYX.y, -0.0))
		angleZYX.y = 0;
	
	if(FloatsApproximatelyEqual(angleZYX.z, -0.0))
		angleZYX.z = 0;
	
	return angleZYX;
	
}//end rotationAngleZYX


//========== stepFlavor ========================================================
//
// Purpose:		Returns the kind of step this is (optimized parts group like 
//				directives into a single step). 
//
//==============================================================================
- (LDrawStepFlavorT) stepFlavor
{
	return self->stepFlavor;
	
}//end stepFlavor


//========== stepRotationType ==================================================
//
// Purpose:		Returns what kind of rotation is attached to this step.
//
//==============================================================================
- (LDrawStepRotationT) stepRotationType
{
	return self->stepRotationType;
	
}//end stepRotationType


#pragma mark -

//========== setModel: =========================================================
//
// Purpose:		Sets a reference to the model of which this step is a part.
//				Called automatically by -addStep:
//
//==============================================================================
- (void) setModel:(LDrawModel *)enclosingModel
{
	[self setEnclosingDirective:enclosingModel];
	
}//end setModel:


//========== setRotationAngle: =================================================
//
// Purpose:		Sets the xyz angle (in degrees) of the receiver's rotation. The 
//				meaning of the value is determined by the step rotation type. 
//
// Notes:		The angle stored in the LDraw file is in zyx order, so it is 
//				unsuitable for feeding directly to this method. 
//
//==============================================================================
- (void) setRotationAngle:(Tuple3)newAngle
{
	self->rotationAngle = newAngle;
	
}//end setRotationAngle:


//========== setRotationAngleZYX: ==============================================
//
// Purpose:		Sets the rotation angle (in degrees) such the the z angle is 
//				applied first, then y, and lastly x. 
//
// Notes:		This is the format in which ROTSTEP angles are saved in the 
//				file, but Bricksmith's matrix functions expect XYZ angles. This 
//				translates the ZYX angle so that it can be used by the rest of 
//				Bricksmith. 
//
//==============================================================================
- (void) setRotationAngleZYX:(Tuple3)newAngleZYX
{
	Matrix4	rotationMatrix	= IdentityMatrix4;
	Tuple3	newAngleXYZ		= ZeroPoint3;
	
	rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(0, 0, newAngleZYX.z));
	rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(0, newAngleZYX.y, 0));
	rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(newAngleZYX.x, 0, 0));
	
	newAngleXYZ = Matrix4DecomposeXYZRotation(rotationMatrix);
	
	// convert from radians to degrees
	newAngleXYZ.x	= degrees(newAngleXYZ.x);
	newAngleXYZ.y	= degrees(newAngleXYZ.y);
	newAngleXYZ.z	= degrees(newAngleXYZ.z);
	
	// Sometimes these get decomposed with a -180 rotation, which is the same as 
	// a 180 rotation. Fix it for display purposes. 
	if(FloatsApproximatelyEqual(newAngleXYZ.x, -180.0))
		newAngleXYZ.x = 180;
	
	if(FloatsApproximatelyEqual(newAngleXYZ.y, -180.0))
		newAngleXYZ.y = 180;
	
	if(FloatsApproximatelyEqual(newAngleXYZ.z, -180.0))
		newAngleXYZ.z = 180;

	[self setRotationAngle:newAngleXYZ];
	
}//end setRotationAngleZYX:


//========== setStepFlavor: ====================================================
//
// Purpose:		Sets the step flavor, which identifies the types of 
//				LDrawDirectives the step contains. Setting the flavor to a 
//				specific directive type will cause the step to draw its 
//				subdirectives inside one set of glBegin()/glEnd(), rather than 
//				starting a new group for each directive encountered.
//
//==============================================================================
- (void) setStepFlavor:(LDrawStepFlavorT)newFlavor
{
	self->stepFlavor = newFlavor;
	
}//end setStepFlavor:


//========== setStepRotationType: ==============================================
//
// Purpose:		Sets the kind of rotation attached to this step.
//
// Notes:		Honoring a step rotation is the responsibility of the object 
//				drawing the model, not the step itself. 
//
//==============================================================================
- (void) setStepRotationType:(LDrawStepRotationT)newValue
{
	self->stepRotationType = newValue;
	
}//end setStepRotationType:


#pragma mark -

//========== insertDirective:atIndex: ==========================================
//
// Purpose:		Inserts the new directive into the step.
//
//==============================================================================
- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index
{
	[super insertDirective:directive atIndex:index];
	
	[[self enclosingModel] didAddDirective:directive];
	
}//end insertDirective:atIndex:


//========== removeDirectiveAtIndex: ===========================================
//
// Purpose:		Removes the directive from the step.
//
//==============================================================================
- (void) removeDirectiveAtIndex:(NSInteger)index
{
	LDrawDirective *directive = [[[self subdirectives] objectAtIndex:index] retain];

	[super removeDirectiveAtIndex:index];
	
	[[self enclosingModel] didRemoveDirective:directive];
	
	[directive release];
	
}//end removeDirectiveAtIndex:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== lineIsStepTerminator: =============================================
//
// Purpose:		Returns if line is a 0 STEP
//
//==============================================================================
+ (BOOL) lineIsStepTerminator:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isStep			= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_STEP_TERMINATOR])
			isStep = YES;
	}
	
	return isStep;
}


//========== lineIsRotationStepTerminator: =====================================
//
// Purpose:		Returns if line is a 0 ROTSTEP
//
//==============================================================================
+ (BOOL) lineIsRotationStepTerminator:(NSString*)line
{
	NSString	*parsedField	= nil;
	NSString	*workingLine	= line;
	BOOL		isRotationStep	= NO;
	
	parsedField = [LDrawUtilities readNextField:  workingLine
									  remainder: &workingLine ];
	if([parsedField isEqualToString:@"0"])
	{
		parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
		
		if([parsedField isEqualToString:LDRAW_ROTATION_STEP_TERMINATOR])
			isRotationStep = YES;
	}
	
	return isRotationStep;
}


//========== parseRotationStepFromLine: ========================================
//
// Purpose:		Parses out the rotation step values from the given line.
//
//				Rotation steps can have the following forms:
//
//					0 ROTSTEP angleX angleY angleZ		// implied REL
//					0 ROTSTEP angleX angleY angleZ REL
//					0 ROTSTEP angleX angleY angleZ ABS
//					0 ROTSTEP angleX angleY angleZ ADD
//					0 ROTSTEP END
//
// Notes:		The angle in ROTSTEPs is in z-y-x order, which is backwards from 
//				how Bricksmith expects the world to be. 
//
// Returns:		YES on success.
//
//==============================================================================
- (BOOL) parseRotationStepFromLine:(NSString *)rotstep
{
	NSScanner	*scanner	= [NSScanner scannerWithString:rotstep];
	Tuple3		 angles		= ZeroPoint3;
	BOOL		 success	= YES;
	
	@try
	{
		if([scanner scanString:@"0" intoString:NULL] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];

		if([scanner scanString:LDRAW_ROTATION_STEP_TERMINATOR intoString:NULL] == NO)
			@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];

		// Is it an end rotation?
		if([scanner scanString:LDRAW_ROTATION_END intoString:NULL] == YES)
		{
			[self setStepRotationType:LDrawStepRotationEnd];
		}
		else
		{
			//---------- Angles ------------------------------------------------
			
			if([scanner scanFloat:&(angles.x)] == NO)
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];

			if([scanner scanFloat:&(angles.y)] == NO)
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];

			if([scanner scanFloat:&(angles.z)] == NO)
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];
		
		
			//---------- Rotation Type -----------------------------------------
			
			if( [scanner scanString:LDRAW_ROTATION_ABSOLUTE intoString:NULL] == YES )
				[self setStepRotationType:LDrawStepRotationAbsolute];
			
			else if( [scanner scanString:LDRAW_ROTATION_ADDITIVE intoString:NULL] == YES )
				[self setStepRotationType:LDrawStepRotationAdditive];

			else if( [scanner scanString:LDRAW_ROTATION_RELATIVE intoString:NULL] == YES )
				[self setStepRotationType:LDrawStepRotationRelative];
			
			// if no type is explicitly specified, it is a relative rotation.
			else if( [scanner isAtEnd] == YES )
				[self setStepRotationType:LDrawStepRotationRelative];
			
			// there is some syntax we don't recognize. Abort parsing attempt.
			else
				@throw [NSException exceptionWithName:@"BricksmithParseException" reason:@"Bad ROTSTEP syntax" userInfo:nil];
				
			// Set the parsed angles if we successfully got the type.
			[self setRotationAngleZYX:angles];
		}
	}
	@catch(NSException *exception)
	{
		success = NO;
	}
	
	return success;
	
}//end parseRotationStepFromLine:


//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setRotationAngle:[self rotationAngle]];
	[[undoManager prepareWithInvocationTarget:self] setStepRotationType:[self stepRotationType]];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAttributesStep", nil)];
	
}//end registerUndoActions:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The Fat Lady has sung.
//
//==============================================================================
- (void) dealloc
{
	[super dealloc];
	
}//end dealloc


@end
