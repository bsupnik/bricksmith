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
#import "StringCategory.h"
#import "LDrawKeywords.h"
#import "LDrawApplication.h"

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
        self->synthType  = [[NSString alloc] init];
        color            = [[LDrawColor alloc] init];
//        originalColor    = [[LDrawColor alloc] init];
//        [self setLsynthClass:-1];
//        deferSynthesis   = NO;



    }

    return self;
}//end init


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== initWithLines:inRange:parentGroup: ================================
//
// Purpose:		Initializes the synthesized part with the supplied range of lines
//
// LSynth format is
//
// 0 SYNTH BEGIN <SYNTH_TYPE> <COLOR_CODE>
// 0 SYNTH SHOW
// 1 <CONSTRAINT PART>
// ...
//
//
// <OPTIONALLY:>
// 0 SYNTH SYNTHESIZED BEGIN
// 1 <SYNTHESIZED PART SPEC>
// ...
// 0 SYNTH SYNTHESIZED END
// 0 SYNTH END
//
//==============================================================================
- (id) initWithLines:(NSArray *)lines
             inRange:(NSRange)range
         parentGroup:(dispatch_group_t)parentGroup
{
        NSLog(@"========================================================================\n");



    NSString          *blockLog            = @"";
    NSString          *currentLine         = nil;
    Class              CommandClass        = Nil;
    NSRange            commandRange        = range;
    NSUInteger         lineIndex           = 0;
    LSynthParserStateT parserState         = PARSER_READY;

    self = [super initWithLines:lines inRange:range parentGroup:parentGroup];

    //[self setPostsNotifications:NO];

    if(self)
    {

        blockLog = [blockLog stringByAppendingString:@"\n---------------------------------------------------------------------------\n"];
        blockLog = [blockLog stringByAppendingString:@"Parsing LSynth block:\n"];
        blockLog = [blockLog stringByAppendingString:[[lines subarrayWithRange:range] componentsJoinedByString:@"\n"]];
        blockLog = [blockLog stringByAppendingString:@"\n"];

        currentLine = [lines objectAtIndex:range.location];

        // 0 SYNTH BEGIN <SYNTH_TYPE> <COLOR>

        NSArray *fields = [currentLine componentsSeparatedByString:@" "];
        NSString *type = [fields objectAtIndex:3];
        [self setLsynthType:[fields objectAtIndex:3]];
        [self setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:(LDrawColorT) [[fields objectAtIndex:4] integerValue]]];

        // Determine the class - hose or band
        // TODO: make lsynthconfiguration have class methods to do this
        //[self setLsynthClass:[LSynthConfiguration classForType:lsynthType]];
        if ([[[[NSApp delegate] lsynthConfiguration] getQuickRefHoses] containsObject:type]) {
            [self setLsynthClass:LSYNTH_HOSE];
        }
        else {
            [self setLsynthClass:LSYNTH_BAND];
        }

        // Parse out the END command
        if(range.length > 0) {
            currentLine = [lines objectAtIndex:(NSMaxRange(range) - 1)];

            if([[self class] lineIsLSynthTerminator:currentLine]) {
                range.length -= 1;
            }
        }

        //---------- synthed stuff -----------------------------------------

        lineIndex = range.location + 1;
        while(lineIndex < NSMaxRange(range))
        {
            currentLine = [lines objectAtIndex:lineIndex];
            if([currentLine length] > 0)
            {
                // determine parser state
                NSString    *strippedLine   = nil;
                NSString    *field          = [LDrawUtilities readNextField:currentLine remainder:&strippedLine];
                NSArray     *fields         = [currentLine componentsSeparatedByString:@" "];

                //NSString *rowType = [[fields objectAtIndex:0] integerValue];
                //NSString *synthIndicator = [fields objectAtIndex:1];

//                if (rowType == LSYNTH_ROW_DIRECTIVE) {
//                    if ([synthIndicator isEqualToString:@"SYNTH"]) {
//                        if ([fields objectAtIndex:1]) {
//
//                        }
//                    }
//                }

                if ([field isEqualToString:@"0"]) {
                    field = [LDrawUtilities readNextField:strippedLine remainder:&strippedLine];
                    if ([field isEqualToString:@"SYNTH"]) {
                        field = [LDrawUtilities readNextField:strippedLine remainder:&strippedLine];
                        if ([field isEqualToString:@"SHOW"] || [field isEqualToString:@"HIDE"]) {
                            parserState = 0;
                            blockLog = [blockLog stringByAppendingString:@"Switching to constraint definition mode.\n"];
                        }
                        else if ([field isEqualToString:@"SYNTHESIZED"]) {
                            field = [LDrawUtilities readNextField:strippedLine remainder:&strippedLine];
                            if ([field isEqualToString:@"BEGIN"]) {
                                parserState = 1;
                            }
                            else if ([field isEqualToString:@"END"]) {
                                parserState = -1;
                            }
                        }
                        else if ([field isEqualToString:@"INSIDE"] ||
                                [field isEqualToString:@"OUTSIDE"]) {
//                            // basically store it as a comment?
//                            LDrawLSynthDirection *direction = [[LDrawLSynthDirection alloc] init];
//                            [direction setStringValue:field];
//                            [self addDirective:direction];
//                            [direction setEnclosingDirective:self];
//                            //[direction addObserver:self];
//
                        }
                    }
                }

                        // read parts into the correct array
                else if ([field isEqualToString:@"1"]) {

                    CommandClass = [LDrawUtilities classForDirectiveBeginningWithLine:currentLine];
                    commandRange = [CommandClass rangeOfDirectiveBeginningAtIndex:lineIndex
                                                                          inLines:lines
                                                                         maxIndex:NSMaxRange(range) - 1];

                    LDrawDirective *newDirective = [[CommandClass alloc] initWithLines:lines inRange:commandRange parentGroup:parentGroup];
                    [newDirective setEnclosingDirective:self];
                    [newDirective addObserver:self];

                    // constraint
                    if (parserState == 0) {
                        blockLog = [blockLog stringByAppendingString:@"Adding constraint.\n"];
                        //[constraints addObject:newDirective];

                        [self addDirective:newDirective];
                    }

                            // synthesised part
                    else if (parserState == 1) {
                        [synthesizedParts addObject:newDirective];
                    }
                    else {
                        // TODO: deal with these better.  Should be lossless, the user knows what they're doing
                        // poss. use LDrawLSynthDirective?
                        NSLog(@"Discarding invalid part in LSynth");
                    }
                }
                lineIndex += 1;
            }
        }
        blockLog = [blockLog stringByAppendingFormat:@"Constraint count: %iu\n", [[self subdirectives] count]];

    }

    // If we've read in synthesized parts or don't have any constraints then don't initially synthesize
    if ([synthesizedParts count] == 0 && [[self allEnclosedElements] count] > 0) {
        [self synthesize];
    }

    //[self setPostsNotifications:YES];

//    [[NSNotificationCenter defaultCenter]
//            postNotificationName:LDrawDirectiveDidChangeNotification
//                          object:self];

    blockLog = [blockLog stringByAppendingString:@"\n---------------------------------------------------------------------------\n"];
    NSLog(@"%@", blockLog);
    return self;

}//end initWithLines:inRange:

//========== insertDirective:atIndex: ==========================================
//
// Purpose:		Inserts the new directive into the step.
//
//==============================================================================
- (void) insertDirective:(LDrawDirective *)directive atIndex:(NSInteger)index
{
    [directive setEnclosingDirective:self];

    [[self subdirectives] insertObject:directive atIndex:index];
    [directive addObserver:self];

//    [[NSNotificationCenter defaultCenter]
//            postNotificationName:LDrawDirectiveDidChangeNotification
//                          object:self];


    //[self synthesizeWithGroup:nil];


}//end insertDirective:atIndex:

//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
//
// Purpose:		Returns the range from the beginning to the end of the step.
//              i.e. 0 SYNTH END
//
//------------------------------------------------------------------------------
+ (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
                                     inLines:(NSArray *)lines
                                    maxIndex:(NSUInteger)maxIndex
{
    NSLog(@"rangeOfDirectiveBeginningAtIndex");

    NSString	*currentLine	= nil;
    NSUInteger	counter 		= 0;
    NSRange 	testRange		= NSMakeRange(index, maxIndex - index + 1);
    NSInteger	synthLength	    = 0;
    NSRange 	synthRange;

    NSString	*parsedField	= nil;
    NSString	*workingLine	= nil;

    currentLine = [lines objectAtIndex:index];
    parsedField = [LDrawUtilities readNextField:currentLine remainder:&currentLine];

    if([parsedField isEqualToString:@"0"])
    {
        parsedField = [LDrawUtilities readNextField:currentLine remainder:&currentLine];

        if([parsedField isEqualToString:LSYNTH_COMMAND])
        {
            parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
            {
                // 0 SYNTH END
                //
                // Find the last line in the synth definition
                for(counter = testRange.location + 1; counter < NSMaxRange(testRange); counter++)
                {
                    currentLine = [lines objectAtIndex:counter];
                    synthLength += 1;

                    if([self lineIsLSynthTerminator:currentLine])
                    {
                        // Nothing more to parse. Stop.
                        synthLength += 1;
                        break;
                    }
                }
            }

        }
    }

    synthRange = NSMakeRange(index, synthLength);

    return synthRange;
}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:

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

////========== write =============================================================
////
//// Purpose:		Write out all the commands in the step, prefaced by the line
////				0 STEP
////
////==============================================================================
- (NSString *) write
{
    NSLog(@"write lsynth");

    NSMutableString *written        = [NSMutableString string];
    NSString        *CRLF           = [NSString CRLF];
    NSString        *lsynthVisibility = @"SHOW";
    NSArray         *constraints    = [self subdirectives];
    LDrawDirective  *currentCommand = nil;
    NSString		*commandString	= nil;
    NSUInteger      numberCommands  = 0;
    NSUInteger      counter         = 0;

    // Start

    [written appendFormat:@"0 SYNTH BEGIN %@ %d%@", [self lsynthType], (int)[self->color colorCode], CRLF];
    [written appendFormat:@"0 SYNTH %@%@", lsynthVisibility, CRLF];

    numberCommands  = [constraints count];
    for(counter = 0; counter < numberCommands; counter++)
    {
        currentCommand = [constraints objectAtIndex:counter];
        commandString = [currentCommand write];
        [written appendString:commandString];
        [written appendString:CRLF];
    }

    // Write out synthesized parts, if there are any to write out
    // TODO: Make dependent on a preference or as part of an Export command
    if ([self->synthesizedParts count] > 0) {
        [written appendString:@"0 SYNTH SYNTHESIZED BEGIN"];
        [written appendString:CRLF];
        for (LDrawPart *part in self->synthesizedParts) {
            [written appendString:[part write]];
            [written appendString:CRLF];
        }
        [written appendString:@"0 SYNTH SYNTHESIZED END"];
        [written appendString:CRLF];
    }
    // End
    [written appendString:@"0 SYNTH END"];
//	[written appendString:CRLF];

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
//===========================   ===================================================
- (NSString *) browsingDescription
{
    return self->synthType;

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

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

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
    [type retain];
    [self->synthType release];
    self->synthType = type;
}//end setLsynthType:

//========== lsynthClass: ====================================================
//
//  Purpose:		Return the type of the Synthesized part.
//
//============================================================================
- (NSString *) lsynthType
{
    return self->synthType;
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
    [self colorSynthesizedPartsTranslucent:flag];
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

    [self colorSynthesizedPartsTranslucent:[self isSelected]];
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

//========== synthesize ========================================================
//
// Purpose:	Synthesizes the part using LSynth
//
// TODO: multithread/background
//
//==============================================================================
-(void)synthesize
{
    NSString *input = @"";
    Class CommandClass = Nil;

    // Path to lsynth
    NSString *lsynthPath = [[NSBundle mainBundle] pathForResource:@"lsynthcp" ofType:nil];

    // We run LSynth as follows:
    // - Create an LDraw file in memory
    // - Setup the STDIN/OUT pipes and NSTask
    // - Launch task
    // - Write to LSynth's STDIN, read from its STDOUT
    // - Process the output (using LDrawDirective's parser) into synthesized parts

    // Create an LDraw file in memory
    LDrawColorT code = self->subdirectiveSelected ? LDrawClear : [[self LDrawColor] colorCode] ;
    input = [input stringByAppendingFormat:@"0 SYNTH BEGIN %@ %d\n", self->synthType, code];
    input = [input stringByAppendingFormat:@"0 SYNTH %@\n", @"SHOW"]; // TODO: honour visibility?
    for (LDrawPart *part in [self subdirectives]) {
        input = [input stringByAppendingFormat:@"%@\n", [part write]];
    }
    input = [input stringByAppendingString:@"0 SYNTH END\n"];
    input = [input stringByAppendingString:@"0 STEP\n"];

    // Setup the STDIN/OUT pipes and NSTask
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
    LDrawColor *theColor;
    if (yesNo == YES) {
        theColor = [color fullCopyWithZone:nil];
        GLfloat rgba[4];
        [theColor getColorRGBA:rgba];
        rgba[3] = 0.2; // Adjust the alpha.  TODO: make this globally configurable
        [theColor setColorRGBA:rgba];
    }
    else {
        theColor = color;
    }

    for (LDrawPart *part in self->synthesizedParts) {
        [part setLDrawColor:theColor];
    }
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
// Purpose:		Called as part of a drag and drop operation to allow us to
//              re-synthesize if constraints have changed.
//
// TODO: Should be a protocol
//
//==============================================================================
-(void)cleanupAfterDrop
{
    [synthesizedParts removeAllObjects];
    [self synthesize];
}

//========== lineIsLSynthBeginning: ===========================================
//
// Purpose:		Returns if line is a 0 SYNTH START
//
//==============================================================================
+ (BOOL) lineIsLSynthBeginning:(NSString*)line
{
    NSString	*parsedField	= nil;
    NSString	*workingLine	= line;
    BOOL		isStart			= NO;

    parsedField = [LDrawUtilities readNextField:  workingLine
                                      remainder: &workingLine ];
    if([parsedField isEqualToString:@"0"])
    {
        parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];

        if([parsedField isEqualToString:LSYNTH_COMMAND])
        {
//			parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
//			if(		[parsedField isEqualToString:LSYNTH_BEGIN])
//			{
            isStart = YES;
//			}
        }
    }

    return isStart;
}

//========== lineIsLSynthTerminator: ==========================================
//
// Purpose:		Returns if line is a 0 SYNTH END or 0 SYNTH PART (which are single
//              line directives)
//
//==============================================================================
+ (BOOL) lineIsLSynthTerminator:(NSString*)line
{
    NSString	*parsedField	= nil;
    NSString	*workingLine	= line;
    BOOL		isEnd			= NO;

    parsedField = [LDrawUtilities readNextField:  workingLine
                                      remainder: &workingLine ];
    if([parsedField isEqualToString:@"0"])
    {
        parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];

        if([parsedField isEqualToString:LSYNTH_COMMAND])
        {
            parsedField = [LDrawUtilities readNextField:workingLine remainder:&workingLine];
            if([parsedField isEqualToString:LSYNTH_END] || [parsedField isEqualToString:@"PART"]) {
                isEnd = YES;
            }
        }
    }

    return isEnd;
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
            [self colorSynthesizedPartsTranslucent:([self isSelected] || self->subdirectiveSelected == YES)];
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
