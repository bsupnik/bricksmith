//==============================================================================
//
// File:		LDrawLSynth.m
//
// Purpose:		Support for synthesizing bendable parts and LSynth generated parts.
//
//==============================================================================

#import "LDrawLSynth.h"
#import "LSynthConfiguration.h"
#import "LDrawPart.h"
#import "LDrawUtilities.h"

@implementation LDrawLSynth

//========== init ==============================================================
//
// Purpose:		Creates a new container with absolutely nothing in it, but
//				ready to receive objects.
//
//==============================================================================
- (id) init
{
    self = [super init];

    if (self) {
        synthesizedParts = [[NSMutableArray alloc] init];
//        lsynthType       = [[NSString alloc] init];
//        color            = [[LDrawColor alloc] init];
//        originalColor    = [[LDrawColor alloc] init];
//        [self setLsynthClass:-1];
//        deferSynthesis   = NO;

        // !!!! experiments in getting drag and drop working w.r.t. deleteDirective
//        NSNotificationCenter	*notificationCenter 	= [NSNotificationCenter defaultCenter];
//        [notificationCenter addObserver:self
//                               selector:@selector(directiveDidChangeNotification:)
//                                   name:LDrawDirectiveDidChangeNotification
//                                 object:nil ];

    }

    return self;
}//end init


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Draw the synthesized part.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor
{
    NSArray         *constraints      = [self subdirectives];
    LDrawDirective  *currentDirective = nil;

    if(self->hidden == NO)
    {
        // Draw each constraint, if:
        if ([self isSelected] == YES ||            // We're selected
                self->subdirectiveSelected != NO ||  // A subdirective (constraint) is selected
                self->lsynthClass == LSYNTH_BAND      // We're a Band, so show constraints regardless
                ) {
            for(currentDirective in constraints)
            {
                [currentDirective draw:optionsMask viewScale:scaleFactor parentColor:parentColor];
            }
        }

        // Draw any synthesized parts as well
        for(currentDirective in synthesizedParts)
        {
            [currentDirective draw:optionsMask viewScale:scaleFactor parentColor:color];
        }
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
    if(self->hidden == NO)
    {
        NSArray     *steps              = [self subdirectives]; // i.e. constraints
        LDrawPart   *currentDirective   = nil;
        NSUInteger  counter             = 0;


        // Hit test the constraints first since this will be the quicker test
        for(counter = 0; counter < [steps count]; counter++)
        {
            currentDirective = [steps objectAtIndex:counter];
            [currentDirective hitTest:pickRay
                            transform:transform
                            viewScale:scaleFactor
                           boundsOnly:boundsOnly
                         creditObject:currentDirective
                                 hits:hits];
        }

        // Now do the synthesized pieces.  We take the credit.  Thangyouverehmuch.
        for (LDrawPart *part in synthesizedParts) {
            [part hitTest:pickRay
                transform:transform
                viewScale:scaleFactor
               boundsOnly:boundsOnly
             creditObject:self
                     hits:hits];
        }
    }
}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:

//========== boxTest:transform:viewScale:boundsOnly:creditObject:hits: =======
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
    NSArray     *commands			= [self subdirectives];
    NSUInteger  commandCount        = [commands count];
    LDrawPart   *currentDirective   = nil;
    NSUInteger  counter             = 0;

    for(counter = 0; counter < commandCount; counter++)
    {
        currentDirective = [commands objectAtIndex:counter];
        if ([currentDirective boxTest:bounds transform:transform boundsOnly:boundsOnly creditObject:self hits:hits]) {
            if(creditObject != nil) {
                return TRUE;
            }
        };
    }

    for (LDrawPart *part in synthesizedParts) {
        if ([part boxTest:bounds transform:transform boundsOnly:boundsOnly creditObject:self hits:hits]) {
            if(creditObject != nil) {
                return TRUE;
            }
        };
    }

    return FALSE;
}//end boxTest:transform:viewScale:boundsOnly:creditObject:hits:

//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
//
// Purpose:		depthTest finds the closest primitive (in screen space)
//				overlapping a given point, as well as its device coordinate
//				depth.
//         FROM TEXTURE
//==============================================================================
- (void)	depthTest:(Point2) testPt
                inBox:(Box2)bounds
            transform:(Matrix4)transform
         creditObject:(id)creditObject
           bestObject:(id *)bestObject
            bestDepth:(float *)bestDepth
{
    NSArray     *commands			= [self subdirectives];
    NSUInteger  commandCount        = [commands count];
    LDrawPart   *currentDirective   = nil;
    NSUInteger  counter             = 0;

    for(counter = 0; counter < commandCount; counter++)
    {
        currentDirective = [commands objectAtIndex:counter];
        [currentDirective depthTest:testPt inBox:bounds transform:transform creditObject:creditObject bestObject:bestObject bestDepth:bestDepth];
    }

    // Now do the synthesized pieces.  We take the credit.
    for (LDrawPart *part in synthesizedParts) {
        [part depthTest:testPt
                  inBox:bounds
              transform:transform
           creditObject:self
             bestObject:bestObject
              bestDepth:bestDepth];
    }

}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:



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
    return self->lsynthType;

}//end browsingDescription

//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
    return @"LSynthPart";

}//end iconName

#pragma mark ACCESSORS

//========== setLsynthClass: ====================================================
//
//  Purpose:		Sets the class of the Synthesized part, Pneumatic tube, or Technic
//                  chain etc.
//
//==============================================================================
- (void) setLsynthClass:(int)class
{
    self->lsynthClass = class;
}//end setLsynthClass:

//========== lsynthClass: ====================================================
//
//  Purpose:		Return the class of the Synthesized part.
//
//==============================================================================

- (int) lsynthClass
{
    return self->lsynthClass;
}//end lsynthClass:

//========== setLsynthType: ====================================================
//
//  Purpose:		Sets the type of the Synthesized part, band, chain or part
//
//==============================================================================
- (void) setLsynthType:(NSString *)type
{
    self->lsynthType = type;
}//end setLsynthType:

//========== lsynthClass: ====================================================
//
//  Purpose:		Return the type of the Synthesized part.
//
//============================================================================
- (NSString *) lsynthType
{
    return self->lsynthType;
}//end

//========== setHidden: ========================================================
//
// Purpose:		Sets whether this part will be drawn, or whether it will be
//				skipped during drawing. This setting only affects drawing;
//				hidden parts will always be written out. Also, note that
//				hiddenness is a temporary state; it is not saved and restored.
//
//==============================================================================
- (void) setHidden:(BOOL) flag
{
    if(self->hidden != flag)
    {
        self->hidden = flag;
        [[self enclosingDirective] setVertexesNeedRebuilding];
        [self invalCache:(CacheFlagBounds|DisplayList)];
    }

}//end setHidden:

//========== isHidden ==========================================================
//
// Purpose:		Returns whether this element will be drawn or not.
//
//==============================================================================
- (BOOL) isHidden
{
    return self->hidden;

}//end isHidden

//========== transformComponents ===============================================
//
// Purpose:		Returns the individual components of the transformation matrix
//			    applied to this part.
//
//==============================================================================
- (TransformComponents) transformComponents
{
    Matrix4				transformation	= [self transformationMatrix];
    TransformComponents	components		= IdentityComponents;

    //This is a pretty darn neat little function. I wish I could say I wrote it.
    // It will extract all the user-friendly components out of this nasty matrix.
    Matrix4DecomposeTransformation( transformation, &components );

    return components;

}//end transformComponents

//========== setSelected: ======================================================
//
// Purpose:		Custom (de)selection action.  We want to make our part transparent
//              when selected.
//
//==============================================================================
- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];
    //[self colorSynthesizedPartsTranslucent:flag];
    //[self sendMessageToObservers:MessageObservedChanged];
}//end setSelected:

//========== setSubdirectiveSelected: =========================================
//
// Purpose:		Set the flag denoting whether a subdirective is selected
//              Also colors the synthesized parts translucent
//
//==============================================================================
- (void) setSubdirectiveSelected:(BOOL)flag
{
    self->subdirectiveSelected = flag;
    [self colorSynthesizedPartsTranslucent:flag];
}


#pragma mark <LDrawColorable> protocol methods

//========== setLDrawColor: ====================================================
//
// Purpose:		Sets the color of the synthesized tube.  This may be temporarily
//              overridden for certain operations but WILL be the one saved out.
//
//==============================================================================
- (void) setLDrawColor:(LDrawColor *)newColor
{
    // Store the color
    [newColor retain];
    [self->color release];
    self->color = newColor;

    //[self colorSynthesizedPartsTranslucent:[self isSelected]];
}//end setLDrawColor:

//========== LDrawColor ========================================================
//
// Purpose:		Returns the LDraw color code of the receiver.
//
//==============================================================================
-(LDrawColor *) LDrawColor
{
    return color;
}//end LDrawColor

#pragma mark -
#pragma mark UTILITY FUNCTIONS
#pragma mark -

//========== synthesizeWithGroup: ==============================================
//
// Purpose:	Synthesizes the part using LSynth
//
//==============================================================================
-(void)synthesize
{
    NSString *input = @"";
    Class CommandClass = Nil;

    // Path to lsynth
    NSString *lsynthPath = [[NSBundle mainBundle] pathForResource:@"lsynthcp" ofType:nil];

    LDrawColorT code = self->subdirectiveSelected ? LDrawClear : [[self LDrawColor] colorCode] ;
    input = [input stringByAppendingFormat:@"0 SYNTH BEGIN %@ %d\n", lsynthType, code];
    input = [input stringByAppendingFormat:@"0 SYNTH %@\n", @"SHOW"]; // TODO: honour visibility?
    for (LDrawPart *part in [self subdirectives]) {
        input = [input stringByAppendingFormat:@"%@\n", [part write]];
    }
    input = [input stringByAppendingString:@"0 SYNTH END\n"];
    input = [input stringByAppendingString:@"0 STEP\n"];

    NSTask *task = [[NSTask alloc] init];
    NSPipe *inPipe = nil;
    NSPipe *outPipe = nil;
    NSPipe *errorPipe = nil;
    NSFileHandle *inFile;
    NSFileHandle *outFile;

    inPipe = [NSPipe new];
    outPipe = [NSPipe new];
    errorPipe = [NSPipe new];

    [task setStandardInput:inPipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errorPipe];
    [task setLaunchPath:lsynthPath];
    [task setArguments:@[@"-"]]; // Our built-in LSynth accepts STDIN/STDOUT with this argument

    inFile = [inPipe fileHandleForWriting];
    outFile = [outPipe fileHandleForReading];

    [inPipe release];
    [outPipe release];
    [errorPipe release];

    // Launch the task
    [task launch];

    // Write the LSynth part to LSynth's STDIN
    [inFile writeData: [input dataUsingEncoding: NSASCIIStringEncoding]];
    [inFile closeFile];

    // Read the synthesized file back in from LSynth's STDOUT
    NSMutableData *data = [[NSMutableData alloc] init];
    NSData *readData;

    while ((readData = [outFile availableData])
            && [readData length]) {
        [data appendData: readData];
    }

    NSString *lsynthOutput;
    lsynthOutput = [[NSString alloc]
            initWithData: data
                encoding: NSASCIIStringEncoding];

    [task release];
    [data release];
    [lsynthOutput autorelease];

    // Split the output into lines
    NSMutableArray *stringsArray = [NSMutableArray arrayWithArray:[lsynthOutput
            componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];

    // Process the synthesized parts
    BOOL extract = NO;

    for (NSString *line in stringsArray) {
        NSRange startRange = [line rangeOfString:@"0 SYNTH SYNTHESIZED BEGIN"];
        NSRange partRange = [line rangeOfString:@"1"];

        if (extract == YES && partRange.length > 0 && partRange.location == 0) {
            CommandClass = [LDrawUtilities classForDirectiveBeginningWithLine:line];
            LDrawDirective *newDirective = [[CommandClass alloc] initWithLines:@[line]
                                                                       inRange:NSMakeRange(0, 1)
                                                                   parentGroup:nil];
            [synthesizedParts addObject:newDirective];
            [newDirective release];
        } else if (extract == NO && startRange.length > 0)  {
            extract = YES;
        }
    }
}

//========== moveBy: ===========================================================
//
// Purpose:		Passes a movement request down to its subdirectives
//
// Optimisation: move all synthesized elements as well to save a resynth
//
//==============================================================================
- (void) moveBy:(Vector3)moveVector
{
    // lock synthesis while we move our constraints
    //self->deferSynthesis = YES;

    // pass on the nudge to drawable subdirectives
    for (LDrawDirective * constraint in [self subdirectives]) {
        //if ([constraint conformsToProtocol:@protocol(LDrawDrawableElement)]) {
            [(LDrawPart *)constraint moveBy:moveVector];
        //}
    }

    // reenable synthesis and resynthesize
    //self->deferSynthesis = NO;
    [synthesizedParts removeAllObjects];
    [self synthesize];
    [self colorSynthesizedPartsTranslucent:[self isSelected]];

}//end moveBy:

//========== colorSynthesizedPartsTranslucent: =================================
//
// Purpose:		Make synthesized parts transparent so that we can better see
//              constraints.
//
//==============================================================================
- (void)colorSynthesizedPartsTranslucent:(BOOL)yesNo
{
    NSLog(@"Would have colorSynthesizedPartsTranslucent");
//    LDrawColor *theColor;
//    if (yesNo == YES) {
//        theColor = [color fullCopyWithZone:nil];
//        GLfloat rgba[4];
//        [theColor getColorRGBA:rgba];
//        rgba[3] = 0.2; // Adjust the alpha.  TODO: make this globally configurable
//        [theColor setColorRGBA:rgba];
//    }
//    else {
//        theColor = color;
//    }
//
//    for (LDrawPart *part in self->synthesizedParts) {
//        [part setLDrawColor:theColor];
//    }
}  //end colorSynthesizedPartsTranslucent:

//========== transformationMatrix ==============================================
//
// Purpose:		Returns a two-dimensional (row matrix) representation of the
//				part's transformation matrix.
//
//																+-       -+
//				+-                           -+        +-     -+| a d g 0 |
//				|a d g 0 b e h c f i 0 x y z 1|  -->   |x y z 1|| b e h 0 |
//				+-                           -+        +-     -+| c f i 0 |
//																| x y z 1 |
//																+-       -+
//					  OpenGL Matrix Format                 LDraw Matrix
//				(flat column-major of transpose)              Format
//
//==============================================================================
- (Matrix4) transformationMatrix
{
    return Matrix4CreateFromGLMatrix4(glTransformation);

}//end transformationMatrix


//========== cleanupAfterDrop ====================================================
//
// Purpose:		Called as part of a drag and drop operation to allow us to resynthesize
//              if constraints have changed.
//
//==============================================================================
-(void)cleanupAfterDrop
{
    NSLog(@"dragDropDonateCleanup");
    [synthesizedParts removeAllObjects];
    [self synthesize];
    //[self sendMessageToObservers:MessageObservedChanged];
    //[self invalCache:CacheFlagBounds|DisplayList];
}

#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== receiveMessage ====================================================
//
// Purpose:		The things we observe call this when something one-time and
//				eventful happens - we can respond if desired.
//
//==============================================================================
- (void) receiveMessage:(MessageT) msg who:(id<LDrawObservable>) observable
{
    if (msg == MessageObservedChanged) {
            [synthesizedParts removeAllObjects];
            [self synthesize];
//            [self colorSynthesizedPartsTranslucent:([self isSelected] || self->subdirectiveSelected == YES)];
    }
}

#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Like sleeping.  But, like, for ever.
//
//==============================================================================
- (void) dealloc
{
    [color release];

    [super dealloc];

}//end dealloc



@end
