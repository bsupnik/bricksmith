//==============================================================================
//
// File:		LDrawDocument.m
//
// Purpose:		Document controller for an LDraw document.
//
//				Opens the document and manages its editor and viewer. This is 
//				the central class of the application's user interface.
//
// Threading:	The LDrawFile encapsulated in this class is a shared resource. 
//				We must take care not to edit it while it is being drawn in 
//				another thread. As such, all the calls in the "Undoable 
//				Activities" section are bracketed with the appropriate locking
//				calls. (ANY edit of the document should be undoable.)
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument.h"

#import "LDrawFile.h"
#import "LDrawModel.h"
#import "LDrawMPDModel.h"
#import "LDrawStep.h"

#import "LDrawColor.h"
#import "LDrawComment.h"
#import "LDrawConditionalLine.h"
#import "LDrawDirective.h"
#import "LDrawDrawableElement.h"
#import "LDrawLine.h"
#import "LDrawPart.h"
#import "LDrawQuadrilateral.h"
#import "LDrawTriangle.h"
#import "LDrawLSynth.h"

#import <AMSProgressBar/AMSProgressBar.h>

#import "DimensionsPanel.h"
#import "DocumentToolbarController.h"
#import "ExtendedScrollView.h"
#import "ExtendedSplitView.h"
#import "IconTextCell.h"
#import "Inspector.h"
#import "LDrawApplication.h"
#import "LDrawColorPanel.h"
#import "LDrawDocumentWindow.h"
#import "LDrawFileOutlineView.h"
#import "LDrawGLView.h"
#import "LDrawUtilities.h"
#import "MacLDraw.h"
#import "MinifigureDialogController.h"
#import "MovePanel.h"
#import "PartBrowserDataSource.h"
#import "PartBrowserPanelController.h"
#import "PartReport.h"
#import "ModelManager.h"
#import "PieceCountPanel.h"
#import "RotationPanelController.h"
#import "ScrollViewCategory.h"
#import "StringUtilities.h"
#import "UserDefaultsCategory.h"
#import "ViewportArranger.h"
#import "WindowCategory.h"
#import "LSynthConfiguration.h"
#import "LDrawDragHandle.h"
#import "LDrawContainer.h"
#import "LDrawLSynthDirective.h"


@implementation LDrawDocument

//========== init ==============================================================
//
// Purpose:		Sets up a new untitled document.
//
//==============================================================================
- (id) init
{
    self = [super init];
    if (self)
	{
		[self setDocumentContents:[LDrawFile file]];
		[self setGridSpacingMode:gridModeMedium];
    }
	markedSelection = NULL;
    return self;
	
}//end init


#pragma mark -
#pragma mark DOCUMENT
#pragma mark -

//========== windowNibName =====================================================
//
// Purpose:		Returns the name of the Nib file used to display this document.
//
//==============================================================================
- (NSString *) windowNibName
{
    // If you need to use a subclass of NSWindowController or if your document 
	// supports multiple NSWindowControllers, you should remove this method and 
	// override -makeWindowControllers instead.
    return @"LDrawDocument";
	
}//end windowNibName


//========== windowControllerDidLoadNib: =======================================
//
// Purpose:		awakeFromNib for document-based programs.
//
//==============================================================================
- (void) windowControllerDidLoadNib:(NSWindowController *) aController
{
	NSNotificationCenter	*notificationCenter 	= [NSNotificationCenter defaultCenter];
	NSUserDefaults			*userDefaults			= [NSUserDefaults standardUserDefaults];
	NSWindow				*window 				= [aController window];
	NSToolbar				*toolbar				= nil;
	NSString				*savedSizeString		= nil;
	NSInteger				drawerState 			= 0;
	NSUInteger				counter 				= 0;
	NSNumberFormatter		*coordinateFormatter	= [[NSNumberFormatter alloc] init];

    [super windowControllerDidLoadNib:aController];
	
    // Create and populate the Model->LSynth menus
    [self populateLSynthModelMenus];

	// Create the toolbar.
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"LDrawDocumentToolbar"] autorelease];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setDelegate:self->toolbarController];
	[window setToolbar:toolbar];
	
	
	// Set our size to whatever it was last time. (We don't do the whole frame 
	// because we want the origin to be nicely staggered as documents open; that 
	// normally happens automatically.)
	savedSizeString = [userDefaults objectForKey:DOCUMENT_WINDOW_SIZE];
	if(savedSizeString != nil)
	{
		NSSize	size	= NSSizeFromString(savedSizeString);
		[window resizeToSize:size animate:NO];
	}
	
	
	//Set up the window state based on what is found in preferences.
	drawerState = [userDefaults integerForKey:PART_BROWSER_DRAWER_STATE];
	if(		drawerState == NSDrawerOpenState
	   &&	[userDefaults boolForKey:PART_BROWSER_STYLE_KEY] == PartBrowserShowAsDrawer)
	{
		[partBrowserDrawer open];
		[self->partsBrowser scrollSelectedCategoryToCenter];
	}
	
	
	// File Contents Outline setup
	[fileContentsOutline setDoubleAction:@selector(showInspector:)];
	[fileContentsOutline setVerticalMotionCanBeginDrag:YES];
	[fileContentsOutline registerForDraggedTypes:[NSArray arrayWithObject:LDrawDirectivePboardType]];
	
	
	// We have to do the splitview saving manually. C'mon Apple, get with it!
	// Note: They did in Leopard. These calls will use the system function 
	//		 there. 
	[fileContentsSplitView	setAutosaveName:@"fileContentsSplitView"];
	[viewportArranger		setAutosaveName:@"HorizontalLDrawSplitview2.1"];
	[self updateViewportAutosaveNamesAndRestore:YES];
	
	// Mouse hover coordinates
	[coordinateFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[coordinateFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[coordinateFormatter setMaximumFractionDigits:0];
	[coordinateFormatter setMinimumFractionDigits:0];
	
	[self->coordinateFieldX setFormatter:coordinateFormatter];
	[self->coordinateFieldY setFormatter:coordinateFormatter];
	[self->coordinateFieldZ setFormatter:coordinateFormatter];
	
	
	// update scope step display controls
	[self setStepDisplay:NO];
	
	//Display our model.
	[self loadDataIntoDocumentUI];
	
	// Set opening zoom percentages
	LDrawGLView	*mainViewport = [self main3DViewport];
	{
		NSArray     *allViewports       = [self all3DViewports];
		LDrawGLView *currentViewport    = nil;
		
		for(counter = 0; counter < [allViewports count]; counter++)
		{
			currentViewport = [allViewports objectAtIndex:counter];
			
			// For brand new viewports which are not yet displaying a model, set 
			// the default zoom factor. 
			if(currentViewport == mainViewport)
			{
				[currentViewport setZoomPercentage:100];
			}
			else
			{
				[currentViewport setZoomPercentage:75];
			}

			// Scrolling to center doesn't seem to work at restoration time, so 
			// do it again here. 
			[currentViewport scrollCenterToModelPoint:ZeroPoint3];

			// For views which are displaying a model, we'll fit the model onscreen
			// (This has no effect for empty models)
			CGFloat unfitZoom	= [currentViewport zoomPercentage];
			CGFloat fitZoom 	= 0.0;

			[currentViewport zoomToFit:nil];
			fitZoom = [currentViewport zoomPercentage];

			// Back out a wee bit so the user has some room to work with his model
			if(unfitZoom != fitZoom)
			{
				[currentViewport setZoomPercentage:(fitZoom * 0.9)];
			}
 		}
	}
	[[self foremostWindow] makeFirstResponder:mainViewport]; //so we can move it immediately.
	
	//Notifications we want.
	[notificationCenter addObserver:self
						   selector:@selector(syntaxColorChanged:)
							   name:LDrawSyntaxColorsDidChangeNotification
							 object:nil ];
	
	[notificationCenter addObserver:self
						   selector:@selector(partChanged:)
							   name:LDrawDirectiveDidChangeNotification
							 object:nil ];
	
	[notificationCenter addObserver:self
						   selector:@selector(activeModelChanged:)
							   name:LDrawFileActiveModelDidChangeNotification
							 object:[self documentContents] ];
							 
	[notificationCenter addObserver:self
						   selector:@selector(libraryReloaded:)
							   name:LDrawPartLibraryReloaded
							object:nil];
	
	
	//---------- Cleanup for legacy systems ------------------------------------
	// Ewww!
	
	// (none currently necessary!)

	// Release memory
	[coordinateFormatter release];
	
}//end windowControllerDidLoadNib:


#pragma mark -
#pragma mark Reading

//========== readFromURL:ofType:error: =========================================
//
// Purpose:		Reads the file off of disk. We are overriding this NSDocument 
//				method to grab the path; the actual data-collection is done 
//				elsewhere.
//
//==============================================================================
- (BOOL) readFromURL:(NSURL *)absoluteURL
			  ofType:(NSString *)typeName
			   error:(NSError **)outError
{
	AMSProgressPanel    *progressPanel  = [AMSProgressPanel progressPanel];
	NSString            *openMessage    = nil;
	BOOL                success         = NO;
	
	openMessage = [NSString stringWithFormat:	NSLocalizedString(@"OpeningFileX", nil), 
		[self displayName] ];
	
	//This might take a while. Show that we're doing something!
	[progressPanel setMessage:openMessage];
	[progressPanel setIndeterminate:YES];
	[progressPanel showProgressPanel];

	//do the actual loading.
	success = [super readFromURL:absoluteURL ofType:typeName error:outError];
	
	[progressPanel close];
	
	if(success == YES)
	{
		// Track the path. I'm not sure what a non-file URL means, and I'm basically 
		// hoping we never encounter one. 
		if([absoluteURL isFileURL] == YES)
		{
			[[self documentContents] setPath:[absoluteURL path]];
			[[ModelManager sharedModelManager] documentSignIn:[absoluteURL path] withFile:documentContents];
		}
		else
			[[self documentContents] setPath:nil];

		//Postflight: find missing and moved parts.
		[self doMissingPiecesCheck:self];
		[self doMovedPiecesCheck:self];
		[self doMissingModelnameExtensionCheck:self];
		
		// Now that all the parts are at their final name, we can optimize.
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		
		CFAbsoluteTime  startTime       = CFAbsoluteTimeGetCurrent();
		CFTimeInterval  optimizeTime    = 0;
		
		[[self documentContents] optimizeOpenGL];
		
		optimizeTime = CFAbsoluteTimeGetCurrent() - startTime;
		NSLog(@"optimize time = %f", optimizeTime);
	}
	
	return success;
	
}//end readFromFile:ofType:


//========== showWindows =======================================================
//
// Purpose:		Overrides NSDocument method to fix a bug whereby the window is 
//				not main once opened. This bug is some sort of odd interplay 
//				with the progress panel; if you don't show the progress panel, 
//				the bug goes away. 
//
//==============================================================================
- (void) showWindows
{
	[super showWindows];
	[[self windowForSheet] makeKeyAndOrderFront:self]; // manually force what is normally automatic behavior.
}


//========== revertToContentsOfURL:ofType:error: ===============================
//
// Purpose:		Called by NSDocument when it reverts the document to its most 
//				recently saved state.
//
//==============================================================================
- (BOOL) revertToContentsOfURL:(NSURL *)absoluteURL
						ofType:(NSString *)typeName
						 error:(NSError **)outError
{
	BOOL success = NO;
	
	//Causes loadDataRepresentation:ofType: to be invoked.
	success = [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError];
	if(success == YES)
	{
		//Display the new document contents. 
		//		(Alas. This doesn't happen automatically.)
		[self loadDataIntoDocumentUI];
	}
	
	return success;
	
}//end revertToSavedFromFile:ofType:


//========== readFromData:ofType:error: ========================================
//
// Purpose:		Read a logical document structure from data. This is the "open" 
//				method.
//
//==============================================================================
- (BOOL) readFromData:(NSData *)data
			   ofType:(NSString *)typeName
				error:(NSError **)outError
{
	NSString    *fileContents   = [LDrawUtilities stringFromFileData:data];
	LDrawFile   *newFile        = nil;
	BOOL        success         = NO;
	
	//Parse the model.
	// - optimizing models can result in OpenGL calls, so to be ultra-safe we 
	//   set a context and lock on it. We can't use any of the documents GL 
	//   views because the Nib may not have been loaded yet.
	CGLLockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	{
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		
		@try
		{
			CFAbsoluteTime  startTime   = CFAbsoluteTimeGetCurrent();
			CFTimeInterval  parseTime   = 0;
			
			newFile     = [LDrawFile parseFromFileContents:fileContents];
			parseTime   = CFAbsoluteTimeGetCurrent() - startTime;
			
			NSLog(@"parse time = %f", parseTime);
			
			if(newFile != nil)
			{
				[self setDocumentContents:newFile];
				success = YES;
			}
		}
		@catch(NSException * e)
		{
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSFileReadCorruptFileError
										userInfo:nil];
		}
	}
	CGLUnlockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	
    return success;
	
}//end loadDataRepresentation:ofType:


#pragma mark -
#pragma mark Writing


//========== saveToURL:ofType:forSaveOperation:delegate:didSaveSelector:contextInfo:
//
// Purpose:		Saves the file out. We are overriding this NSDocument method to 
//				grab the path; the actual data-collection is done elsewhere.
//
//==============================================================================
- (void)saveToURL:(NSURL *)absoluteURL 
		   ofType:(NSString *)typeName 
 forSaveOperation:(NSSaveOperationType)saveOperation 
		 delegate:(id)delegate 
  didSaveSelector:(SEL)didSaveSelector 
	  contextInfo:(void *)contextInfo
{
	[super saveToURL:absoluteURL 
			  ofType:typeName 
	forSaveOperation:saveOperation 
			delegate:delegate 
	 didSaveSelector:didSaveSelector 
		 contextInfo:contextInfo];

	//track the path.
	if([absoluteURL isFileURL] == YES)
	{
		[[self documentContents] setPath:[absoluteURL path]];
		[[ModelManager sharedModelManager] documentSignIn:[absoluteURL path] withFile:documentContents];
	}
	else
		[[self documentContents] setPath:nil];
}//end saveToURL:ofType:forSaveOperation:delegate:didSaveSelector:contextInfo:


//========== dataOfType:error: =================================================
//
// Purpose:		Converts this document into a data object that can be written 
//				to disk. This is where a document gets saved.
//
//==============================================================================
- (NSData *)dataOfType:(NSString *)typeName
				 error:(NSError **)outError
{
    NSString *modelOutput = [[self documentContents] write];
	
	return [modelOutput dataUsingEncoding:NSUTF8StringEncoding];
	
}//end dataOfType:error:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== documentContents ==================================================
//
// Purpose:		Returns the logical representation of the LDraw file this 
//				document represents.
//
//==============================================================================
- (LDrawFile *) documentContents
{
	return documentContents;
	
}//end documentContents


//========== foremostWindow ====================================================
//
// Purpose:		Returns the main editing window.
//
//==============================================================================
- (NSWindow *) foremostWindow
{
	return [[[self windowControllers] objectAtIndex:0] window];
	
}//end foremostWindow


//========== gridSpacingMode ===================================================
//
// Purpose:		Returns the current granularity of the positioning grid being 
//				used in this document.
//
//==============================================================================
- (gridSpacingModeT) gridSpacingMode
{
	return gridMode;
	
}//end gridSpacingMode


//========== partBrowserDrawer =================================================
//
// Purpose:		Returns the drawer for a part browser attached to the document 
//			    window. Note that the user can set a preference to show the Part 
//			    Browser as a single floating panel rather than a drower on each 
//			    window. 
//
//==============================================================================
- (NSDrawer *) partBrowserDrawer
{
	return self->partBrowserDrawer;

}//end partBrowserDrawer


//========== viewingAngle ======================================================
//
// Purpose:		Returns the modelview rotation for the focused LDrawGLView.
//
//==============================================================================
- (Tuple3) viewingAngle
{
	Tuple3	angle	= [self->mostRecentLDrawView viewingAngle];
	
	return angle;
	
}//end viewingAngle


#pragma mark -


//========== setActiveModel: ===================================================
//
// Purpose:		Changes the current active (displayed) submodel, preserving as 
//				much of the viewing state as is appropriate. 
//
// Notes:		You should call this rather than setting the active model 
//				directly on the LDrawFile. 
//
//==============================================================================
- (void) setActiveModel:(LDrawMPDModel *)newActiveModel
{
	LDrawMPDModel	*oldActiveModel		= [[self documentContents] activeModel];
	BOOL			stepDisplayMode		= [oldActiveModel stepDisplay];
	
	if(newActiveModel != oldActiveModel)
	{
		// Allow the old model to draw in its entirety if it is referenced by the 
		// new model. 
		[oldActiveModel setStepDisplay:NO];
		
		// Set the new model and make sure its step display state matches the 
		// previous step display state. 
		[[self documentContents] setActiveModel:newActiveModel];
		[self setStepDisplay:stepDisplayMode];;
		
		//A notification will be generated that updates the models menu.
	}
}//end setActiveModel:


//========== setCurrentStep: ===================================================
//
// Purpose:		Sets the current maximum step displayed in step display mode and 
//				updates the UI. 
//
// Notes:		This does not activate step display if it isn't on.
//				This also does not do anything if the step is not changing.
//
// Parameters:	requestedStep	- the 0-relative step number. Does not do 
//								  bounds-checking. 
//
//==============================================================================
- (void) setCurrentStep:(NSInteger)requestedStepIndex
{
	LDrawMPDModel	*activeModel		= [[self documentContents] activeModel];
	NSInteger		currentStepIndex	= [activeModel maximumStepIndexForStepDisplay];
	LDrawStep		*requestedStep		= [[activeModel steps] objectAtIndex:requestedStepIndex];
	
	if(currentStepIndex != requestedStepIndex)
	{
		[activeModel setMaximumStepIndexForStepDisplay:requestedStepIndex];
		
		// Update UI
		
		[self->stepField setIntegerValue:(requestedStepIndex + 1)]; // make 1-relative
		
		if([activeModel stepDisplay] == YES)
		{
			// Set the viewer to the step's rotation
			// Note: This is pretty annoying if you are trying to build your 
			//		 model and flip between steps. So I'm going to try 
			//		 restricting it to only happen when the step demands that 
			//		 the viewing angle change. 
			if([requestedStep stepRotationType] != LDrawStepRotationNone)
			{
				[self updateViewingAngleToMatchStep];
			}
				
			[[self documentContents] noteNeedsDisplay];
		}
	}
	
}//end setCurrentStep:


//========== setDocumentContents: ==============================================
//
// Purpose:		Sets the logical representation of the LDraw file this 
//				document represents to newContents. This method should be called 
//				when the document is first created.
//
// Notes:		This method intentionally avoids making the user interface aware 
//				of the new contents. This is because this method is generally 
//				called prior to loading the Nib file. (It also gets called when 
//				reverting.) There is a separate method, -loadDataIntoDocumentUI,
//				to sync the UI.
//
//==============================================================================
- (void) setDocumentContents:(LDrawFile *)newContents
{
	[newContents retain];
	[documentContents release];
	
	// This is going to be an editable container now, so we need to know when it 
	// changes. 
	[newContents setPostsNotifications:YES];
	
	documentContents = newContents;
	
	[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		
}//end setDocumentContents:


//========== setGridSpacingMode: ===============================================
//
// Purpose:		Sets the current granularity of the positioning grid being used 
//				in this document. 
//
//==============================================================================
- (void) setGridSpacingMode:(gridSpacingModeT)newMode
{
	NSArray     *graphicViews   = [self all3DViewports];
	NSUInteger  counter         = 0;
	
	self->gridMode = newMode;
	
	// Update bits of UI
	[self->toolbarController setGridSpacingMode:newMode];
	
	for(counter = 0; counter < [graphicViews count]; counter++)
	{
		[[graphicViews objectAtIndex:counter] setGridSpacingMode:newMode];
	}
	
}//end setGridSpacingMode:


//========== setLastSelectedPart: ==============================================
//
// Purpose:		The document keeps track of the part most recently selected in 
//				the file contents outline. This method is called each time a new 
//				part is selected. The transformation matrix of the previously 
//				selected part is then used when new parts are added.
//
//==============================================================================
- (void) setLastSelectedPart:(LDrawPart *)newPart
{
	[newPart retain];
	[lastSelectedPart release];
	
	lastSelectedPart = newPart;
	
}//end setLastSelectedPart:


//========== setMostRecentLDrawView: ===========================================
//
// Purpose:		Sets the 3D view with which we interacted the most recently. 
//
// Note:		This accessor method is mainly here to provide KVO compliance so 
//				Cocoa will automatically generate the necessary change messages 
//				for binding which observe the most recent view. 
//
//==============================================================================
- (void) setMostRecentLDrawView:(LDrawGLView *)viewIn
{
	self->mostRecentLDrawView = viewIn;
	
}//end setMostRecentLDrawView:


//========== setStepDisplay: ===================================================
//
// Purpose:		Turns step display (like Lego instructions) on or off for the 
//				active model.
//
//==============================================================================
- (void) setStepDisplay:(BOOL)showStepsFlag
{
	LDrawMPDModel	*activeModel	= [[self documentContents] activeModel];
	
	if(showStepsFlag != [activeModel stepDisplay])
	{
		if(showStepsFlag == YES)
		{
			[activeModel setStepDisplay:YES];
			[self setCurrentStep:0];
			
			// Force viewing angle update when turning on step display. 
			// -setCurrentStep only does this if the step has actually changed. 
			[self updateViewingAngleToMatchStep];
		}
		else // turn it off now
		{
			[activeModel setStepDisplay:NO];
		}
		
		[[self documentContents] noteNeedsDisplay];
	}
	
	// Set scope button state no matter what. The scope buttons are really 
	// toggle buttons which call this method; if you click "Steps" and step 
	// display is already on, you want the button to *stay* selected. This makes 
	// sure that happens. 
	[self->viewAllButton   setState:(showStepsFlag == NO)];
	[self->viewStepsButton setState:(showStepsFlag == YES)];
	
	[self->scopeStepControlsContainer setHidden:(showStepsFlag == NO)];
	[self->stepField setIntegerValue:[activeModel maximumStepIndexForStepDisplay] + 1];
	
}//end setStepDisplay:


#pragma mark -
#pragma mark ACTIVITIES
#pragma mark -
//These are *high-level* calls to modify the structure of the model. They call 
// down to appropriate low-level calls (in the "Undoable Activities" section).


//========== moveSelectionBy: ==================================================
//
// Purpose:		Moves all selected (and moveable) directives in the direction 
//				indicated by movementVector.
//
//==============================================================================
- (void) moveSelectionBy:(Vector3) movementVector
{
	NSArray         *selectedObjects    = [self selectedObjects];
	LDrawDirective  *currentObject      = nil;
	NSInteger       counter             = 0;
	
	//find the nudgable items
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
//		if([currentObject isKindOfClass:[LDrawDrawableElement class]])
        if([currentObject conformsToProtocol:@protocol(LDrawMovableDirective)])
			[self moveDirective: (LDrawDrawableElement*)currentObject
					inDirection: movementVector];
	}
	
}//end moveSelectionBy:


//========== nudgeSelectionBy: =================================================
//
// Purpose:		Nudges all selected (and nudgeable) directives in the direction 
//				indicated by nudgeVector, which should be normalized. The exact 
//				amount nudged is dependent on the directives themselves, but we 
//				give them our best estimate based on the grid granularity.
//
//==============================================================================
- (void) nudgeSelectionBy:(Vector3)nudgeVector
{
	NSArray                 *selectedObjects    = [self selectedObjects];
	LDrawDrawableElement    *firstNudgable      = nil;
	id                      currentObject       = nil;
	float                   nudgeMagnitude      = [BricksmithUtilities gridSpacingForMode:self->gridMode];
	NSInteger               counter             = 0;
	
	// We do not normalize the nudge vector - nudge might be set to a multiple of the grid on purpose.
	
	nudgeVector.x *= nudgeMagnitude;
	nudgeVector.y *= nudgeMagnitude;
	nudgeVector.z *= nudgeMagnitude;
	
	//find the first selected item that can actually be moved.
	for(counter = 0; counter < [selectedObjects count] && firstNudgable == nil; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
//		if([currentObject isKindOfClass:[LDrawDrawableElement class]])
//			firstNudgable = currentObject;
        if([currentObject conformsToProtocol:@protocol(LDrawMovableDirective)])
            firstNudgable = currentObject;

	}
	
	if(firstNudgable != nil)
	{
		//compute the absolute movement for the relative nudge. The actual 
		// movement for a nudge is dependent on the axis along which the 
		// nudge is occurring (because Lego follows different vertical and
		// horizontal scales). But we must move all selected parts by the 
		// SAME AMOUNT, otherwise they would get oriented all over the place.
		nudgeVector = [firstNudgable displacementForNudge:nudgeVector];
		
		[self moveSelectionBy:nudgeVector];
	}
}//end nudgeSelectionBy:


//========== rotateSelectionAround: ============================================
//
// Purpose:		Rotates all selected parts in a clockwise direction around the 
//				specified axis. The rotationAxis should be either 
//				+/- i, +/- j or +/- k.
//
//				This method is used by the rotate toolbar methods. It chooses 
//				the actual number of degrees based on the current grid mode.
//
//==============================================================================
- (void) rotateSelectionAround:(Vector3)rotationAxis
{
	NSArray			*selectedObjects	= [self selectedObjects]; //array of LDrawDirectives.
	RotationModeT	 rotationMode		= RotateAroundSelectionCenter;
	Tuple3			 rotation			= {0};
	float			 degreesToRotate	= 0;
	
	//Determine magnitude of nudge.
	switch([self gridSpacingMode])
	{
		case gridModeFine:
			degreesToRotate = GRID_ROTATION_FINE;	//15 degrees
			break;
		case gridModeMedium:
			degreesToRotate = GRID_ROTATION_MEDIUM;	//45 degrees
			break;
		case gridModeCoarse:
			degreesToRotate = GRID_ROTATION_COARSE;	//90 degrees
			break;
	}
	
	//normalize just in case someone didn't get the message!
	rotationAxis = V3Normalize(rotationAxis);
	
	rotation.x = rotationAxis.x * degreesToRotate;
	rotation.y = rotationAxis.y * degreesToRotate;
	rotation.z = rotationAxis.z * degreesToRotate;
	
	
	//Just one part selected; rotate around that part's origin. That is 
	// presumably what the part's author intended to be the rotation point.
	if([selectedObjects count] == 1){
		rotationMode = RotateAroundPartPositions;
	}
	//More than one part selected. We now must make a "best guess" about 
	// what to rotate around. So we will go with the center of the bounding 
	// box of the selection.
	else
		rotationMode = RotateAroundSelectionCenter;
	
	
	[self rotateSelection:rotation mode:rotationMode fixedCenter:NULL];
	
}//end rotateSelectionAround


//========== rotateSelection:mode:fixedCenter: =================================
//
// Purpose:		Rotates the selected parts according to the specified mode.
//
// Parameters:	rotation	= degrees x,y,z to rotate
//				mode		= how to derive the rotation centerpoint
//				fixedCenter	= explicit centerpoint, or NULL if mode not equal to 
//							  RotateAroundFixedPoint
//
//==============================================================================
- (void) rotateSelection:(Tuple3)rotation
					mode:(RotationModeT)mode
			 fixedCenter:(Point3 *)fixedCenter
{
	NSArray     *selectedObjects    = [self selectedObjects]; //array of LDrawDirectives.
	id          currentObject       = nil;
	Box3        selectionBounds     = [LDrawUtilities boundingBox3ForDirectives:selectedObjects];
	Point3      rotationCenter      = {0};
	NSInteger   counter             = 0;
	
	if(mode == RotateAroundSelectionCenter)
	{
		rotationCenter = V3Midpoint(selectionBounds.min, selectionBounds.max);
	}
	else if(mode == RotateAroundFixedPoint)
	{
		if(fixedCenter != NULL)
			rotationCenter = *fixedCenter;
	}
	
	
	//rotate everything that can be rotated. That would be parts and only parts.
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
		if([currentObject isKindOfClass:[LDrawPart class]])
		{
			if(mode == RotateAroundPartPositions)
				rotationCenter = [(LDrawPart*)currentObject position];
		
			[self rotatePart:currentObject
				   byDegrees:rotation
				 aroundPoint:rotationCenter ];
		}
	}
}//end rotateSelection:mode:fixedCenter:


//========== selectDirective:byExtendingSelection: =============================
//
// Purpose:		Selects the specified directive.
//				Pass nil to deselect all.
//
//				If shouldExtend is YES, this method toggles the selection of the 
//				given directive. Otherwise, the given directive is made the 
//				exclusive selection in the document. 
//
//==============================================================================
- (void) selectDirective:(LDrawDirective *) directiveToSelect
	byExtendingSelection:(BOOL) shouldExtend
{
	NSArray     *ancestors      = [directiveToSelect ancestors];
	NSInteger   indexToSelect   = 0;
	NSInteger   counter         = 0;
	
	if(directiveToSelect == nil)
		[fileContentsOutline deselectAll:nil];
	else
	{
		//Expand the hierarchy all the way down to the directive we are about to 
		// select.
		for(counter = 0; counter < [ancestors count]; counter++)
			[fileContentsOutline expandItem:[ancestors objectAtIndex:counter]];
		
		//Now we can safely select the directive. It is guaranteed to be visible, 
		// since we expanded all its ancestors.
		indexToSelect = [fileContentsOutline rowForItem:directiveToSelect];
		
		//If we are doing multiple selection (shift-click), we want to deselect 
		// already-selected parts.
		if(		[[fileContentsOutline selectedRowIndexes] containsIndex:indexToSelect]
			&&	shouldExtend == YES )
		{
			[fileContentsOutline deselectRow:indexToSelect];
		}
		else
		{
			[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect]
							 byExtendingSelection:shouldExtend];
		}
		
		[fileContentsOutline scrollRowToVisible:indexToSelect];
	}
	
}//end selectDirective:byExtendingSelection:

//========== selectDirectives: ================================================
//
// Purpose:		Selects an array of directives.  This function changes the 
//				selection to be these and only these directives, deselecting
//				all others in the process.
//
//				This is used for marquee selection - when changing a lot of
//				selection it's more CPU efficient to change them all at once. 
//
// Notes:		This routine will perform multiple disclosures of items in the
//				hierarchy as needed to make the selection.  It does not attempt
//				to scroll to the selected items, as they could be spread all 
//				over the place.
//
//==============================================================================
- (void) selectDirectives:(NSArray *) directivesToSelect
{
	NSInteger   indexToSelect   = 0;
	NSInteger   counter         = 0;
	NSInteger	d				= 0;
	NSInteger	total			= [directivesToSelect count];
	
	if(total == 0)
		[fileContentsOutline deselectAll:nil];
	else
	{
		for(d = 0; d < total; ++d)
		{
			LDrawDirective * directive = [directivesToSelect objectAtIndex:d];			
			NSArray     *ancestors      = [directive ancestors];

			//Expand the hierarchy all the way down to the directive we are about to 
			// select.
			for(counter = 0; counter < [ancestors count]; counter++)
				[fileContentsOutline expandItem:[ancestors objectAtIndex:counter]];
		}

		NSMutableIndexSet * indices = [NSMutableIndexSet indexSet];
		
		for(d = 0; d < total; ++d)
		{
			LDrawDirective * directive = [directivesToSelect objectAtIndex:d];			
		
			indexToSelect = [fileContentsOutline rowForItem:directive];
		
			if([indices containsIndex:indexToSelect])
			{
				// Allen says don't do "toggle" behavior with shift-marquee select.  
				// If we did want a toggle, we'd enable this.
				//[indices removeIndex:indexToSelect];			
			}
			else
			{
				[indices addIndex:indexToSelect];
			}
		
		}
		[fileContentsOutline selectRowIndexes:indices byExtendingSelection:NO];
	}
	
}//end selectDirectives:

//========== setSelectionToHidden: =============================================
//
// Purpose:		Hides or shows all the hideable selected elements.
//
//==============================================================================
- (void) setSelectionToHidden:(BOOL)hideFlag
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject respondsToSelector:@selector(setHidden:)])
			[self setElement:currentObject toHidden:hideFlag]; //undoable hook.
	}
}//end setSelectionToHidden:


//========== setZoomPercentage: ================================================
//
// Purpose:		Zooms the selected LDraw view to the specified percentage.
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage
{
	[self->mostRecentLDrawView setZoomPercentage:newPercentage];
	
}//end setZoomPercentage:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -
//traditional -(void)action:(id)sender type action methods.
// Generally called directly by User Interface controls.


//========== changeLDrawColor: =================================================
//
// Purpose:		Responds to color-change messages sent down the responder chain 
//				by the LDrawColorPanel. Upon the receipt of this message, the 
//				window should change the color of all the selected objects to 
//				the new color specified in the panel.
//
//==============================================================================
- (void) changeLDrawColor:(id)sender
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	LDrawColor  *newColor           = [sender LDrawColor];
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
	
		if([currentObject conformsToProtocol:@protocol(LDrawColorable)])
			[self setObject:currentObject toColor:newColor];
	}
	if([selectedObjects count] > 0)
		[[self documentContents] noteNeedsDisplay];
		
}//end changeLDrawColor:


//========== insertLDrawPart: ==================================================
//
// Purpose:		We are being prompted to insert a new part into the model.
//
// Parameters:	sender = PartBrowserDataSource generating the insert request.
//
//==============================================================================
- (void) insertLDrawPart:(id)sender
{
	NSString	*partName	= [sender selectedPartName];
	
	//We got a part; let's add it!
	if(partName != nil)
		[self addPartNamed:partName];
	
	// part-insertion may have been generated by a Part Browser panel which was 
	// in the foreground. Now that the part is inserted, we want the editor 
	// window in the foreground. 
	[[self foremostWindow] makeKeyAndOrderFront:sender];
	
}//end insertLDrawPart:


//========== nudge: ============================================================
//
// Purpose:		Called by LDrawGLView when it wants to nudge the selection.
//
//==============================================================================
- (void) nudge:(id)sender
{
	LDrawGLView *glView     = sender;
	Vector3     nudgeVector = [glView nudgeVector];
	
	[self nudgeSelectionBy:nudgeVector];
	
}//end nudge:


//========== panelMoveParts: ===================================================
//
// Purpose:		The move panel wants to move parts.
//
// Parameters:	sender = MovePanel generating the move request.
//
//==============================================================================
- (void) panelMoveParts:(id)sender
{
	Vector3			movement		= [sender movementVector];
	
	[self moveSelectionBy:movement];
	
}//end panelMoveParts


//========== panelRotateParts: =================================================
//
// Purpose:		The rotation panel wants to rotate! It's up to us to interrogate 
//				the rotation panel to figure out how exactly this rotation is 
//				supposed to be done.
//
// Parameters:	sender = RotationPanel generating the rotation request.
//
//==============================================================================
- (void) panelRotateParts:(id)sender
{
	Tuple3			angles			= [sender angles];
	RotationModeT	rotationMode	= [sender rotationMode];
	Point3			centerPoint		= [sender fixedPoint];
	
	//the center may not be valid, but that will get taken care of by the 
	// rotation mode.
	
	[self rotateSelection:angles
					 mode:rotationMode
			  fixedCenter:&centerPoint];
	
}//end panelRotateParts


#pragma mark -

//========== doMissingModelnameExtensionCheck: =================================
//
// Purpose:		Ensures that the names of all submodels in the current model end 
//				in a recognized LDraw extension (.ldr, .dat), renaming models 
//				and updating references as needed. 
//
// Notes:		Previous versions of Bricksmith did not force submodel names to 
//				end in a file extension, and this was a seemingly sensible, 
//				Maclike thing to do. Alas, MLCad will NOT RECOGNIZE submodels 
//				whose names do not have an extension. (Why...?!) Furthermore, 
//				according to the LDraw File Specification, a type 1 MUST point 
//				ot a "valid LDraw filename," which MUST include the extension. 
//				http://www.ldraw.org/Article218.html#lt1 Sigh...
//
//				This action is not undoable. Why would you want to?
//
//==============================================================================
- (void) doMissingModelnameExtensionCheck:(id)sender
{
	NSArray         *submodels          = [[self documentContents] submodels];
	LDrawMPDModel   *currentSubmodel    = nil;
	NSString        *currentName        = nil;
	NSString        *acceptableName     = nil;
	NSInteger       counter             = 0;
	
	// Find submodels with bad names.
	for(counter = 0; counter < [submodels count]; counter++)
	{
		currentSubmodel	= [submodels objectAtIndex:counter];
		currentName		= [currentSubmodel modelName];
		acceptableName	= [LDrawMPDModel ldrawCompliantNameForName:currentName];
		
		// If the model name does not have a valid LDraw file extension, the 
		// LDraw spec says we must give it one. Ugh. 
		if( [acceptableName isEqualToString:currentName] == NO )
		{
			// For files with only one model, we synthesize a name based on the 
			// model description. We can safely do a direct rename of these 
			// files. This also means LDrawMPDModel doesn't have to clean up 
			// every official part we parse from the LDraw folder. 
			if([submodels count] == 1)
			{
				[currentSubmodel setModelName:acceptableName];
			}
			else
			{
				// For MPD documents, we need to do a complex rename.
				[[self documentContents] renameModel:currentSubmodel toName:acceptableName];
			
				// Mark document as modified.
				[self updateChangeCount:NSChangeDone];
			}
		}
	}
	
}//end doMissingModelnameExtensionCheck:


//========== doMissingPiecesCheck: =============================================
//
// Purpose:		Searches the current model for any missing parts, and displays a 
//				warning if there are some.
//
//==============================================================================
- (void) doMissingPiecesCheck:(id)sender
{
	CFAbsoluteTime  startTime       = CFAbsoluteTimeGetCurrent();
	CFTimeInterval  partReportTime    = 0;
	
	// Until we load neighbor files as part of the async-GCD-friendly file load, neighboring files show
	// up here - the part report is the first thing that triggers the lazy load.  So until we fix this,
	// "resolve" time contains the time to figure out what each part points to, and the dominant cost 
	// is loading neighbor files when they are in use.
				
	PartReport		*partReport			= [PartReport partReportForContainer:[self documentContents]];
	NSArray			*missingParts		= [partReport missingParts];

	partReportTime = CFAbsoluteTimeGetCurrent() - startTime;
	NSLog(@"resolve time = %f", partReportTime);

	NSArray			*missingNames		= nil;
	NSMutableString	*informativeString	= nil;
	
	if([missingParts count] > 0)
	{
		//Build a string listing all the missing parts.
		missingNames = [missingParts valueForKey:@"displayName"]; // I love Cocoa.
		
		informativeString = [NSMutableString stringWithString:NSLocalizedString(@"MissingPiecesInformative", nil)];
		[informativeString appendString:@"\n\n"];
		[informativeString appendString:[missingNames componentsJoinedByString:@"\n"]];
		
		//Alert! Alert!
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert     setMessageText:NSLocalizedString(@"MissingPiecesMessage", nil)];
		[alert setInformativeText:informativeString];
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		[alert runModal];
		
		[alert release];
	}
	
}//end doMissingPiecesCheck:


//========== doMovedPiecesCheck: ===============================================
//
// Purpose:		Searches the current model for any ~Moved parts, and displays a 
//				warning if there are some.
//
//==============================================================================
- (void) doMovedPiecesCheck:(id)sender
{
	PartReport	*partReport     = [PartReport partReportForContainer:[self documentContents]];
	NSArray     *movedParts     = [partReport movedParts];
	NSInteger   buttonReturned  = 0;
	NSInteger   counter         = 0;
	
	if([movedParts count] > 0)
	{
		//Alert! Alert! What should we do?
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert     setMessageText:NSLocalizedString(@"MovedPiecesMessage", nil)];
		[alert setInformativeText:NSLocalizedString(@"MovedPiecesInformative", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"CancelButtonName", nil)];
		
		buttonReturned = [alert runModal];
		
		//They want us to update the ~Moved parts.
		if(buttonReturned == NSAlertFirstButtonReturn)
		{
			for(counter = 0; counter < [movedParts count]; counter++)
			{
				[LDrawUtilities updateNameForMovedPart:[movedParts objectAtIndex:counter]];
			}
			
			//mark document as modified.
			[self updateChangeCount:NSChangeDone];
		}
		
		[alert release];
	}
	
}//end doMovedPiecesCheck:


#pragma mark -
#pragma mark Scope Bar

//========== viewAll: ==========================================================
//
// Purpose:		Turn off Step Display.
//
//==============================================================================
- (IBAction) viewAll:(id)sender
{
	// Call the simple method. This also takes care of button state for us.
	[self setStepDisplay:NO];
	
}//end viewAll:


//========== viewSteps: ========================================================
//
// Purpose:		Turn on Step Display.
//
//==============================================================================
- (IBAction) viewSteps:(id)sender
{
	// Call the simple method. This also takes care of button state for us.
	[self setStepDisplay:YES];

}//end viewSteps:


//========== stepFieldChanged: =================================================
//
// Purpose:		This allows you to type in a specific step and go to it.
//
//==============================================================================
- (IBAction) stepFieldChanged:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       numberSteps     = [[activeModel steps] count];
	NSInteger       requestedStep   = [sender integerValue]; // 1-relative
	NSInteger       actualStep      = 0; // 1-relative
	
	// The user's number may have been out of range.
	actualStep = CLAMP(requestedStep, 1, numberSteps);
	
	[self setCurrentStep:(actualStep - 1)]; // convert to 0-relative
	
	// If we had to clamp, that is a user error. Tell him.
	if(actualStep != requestedStep)
		NSBeep();
		
}//end stepFieldChanged:


//========== stepNavigatorClicked: =============================================
//
// Purpose:		The step navigator is a segmented control that presents a back 
//				and forward button. 
//
//==============================================================================
- (IBAction) stepNavigatorClicked:(id)sender
{
	// Back == 0; Forward == 1
	if([sender selectedSegment] == 0)
		[self backOneStep:sender];
	else
		[self advanceOneStep:sender];
	
}//end stepNavigatorClicked:


#pragma mark -
#pragma mark File Menu

//========== exportSteps: ======================================================
//
// Purpose:		Presents a save dialog allowing the user to export his model 
//				as a series of files, one for each progressive step.
//
//==============================================================================
- (IBAction) exportSteps:(id)sender
{
	NSSavePanel *exportPanel	= [NSSavePanel savePanel];
	NSString	*activeName		= [[[self documentContents] activeModel] modelName];
	NSString	*nameFormat		= NSLocalizedString(@"ExportedStepsFolderFormat", nil);
	
	[exportPanel setDirectoryURL:nil];
	[exportPanel setNameFieldStringValue:[NSString stringWithFormat:nameFormat, activeName]];
	
	[exportPanel beginSheetModalForWindow:[self windowForSheet]
						completionHandler:
	 ^(NSInteger returnCode)
	 {
		 // Do the save
		 
		 NSFileManager	 *fileManager		 = [[[NSFileManager alloc] init] autorelease];
		 NSURL			 *saveURL			 = nil;
		 NSString		 *saveName			 = nil;
		 NSString		 *modelName 		 = nil;
		 NSString		 *folderName		 = nil;
		 NSString		 *modelnameFormat	 = NSLocalizedString(@"ExportedStepsFolderFormat", nil);
		 NSString		 *filenameFormat	 = NSLocalizedString(@"ExportedStepsFileFormat", nil);
		 NSString		 *fileString		 = nil;
		 NSData 		 *fileOutputData	 = nil;
		 NSString		 *outputName		 = nil;
		 NSString		 *outputPath		 = nil;
		 
		 LDrawFile		 *fileCopy			 = nil;
		 
		 NSInteger		 modelCounter		 = 0;
		 NSInteger		 counter			 = 0;
		 
		 if(returnCode == NSOKButton)
		 {
			 saveURL	= [exportPanel URL];
			 saveName	= ([saveURL isFileURL] ? [saveURL path] : nil);
			 
			 // If we got this far, we need to replace any prexisting file.
			 if([fileManager fileExistsAtPath:saveName isDirectory:NULL])
				 [fileManager removeItemAtPath:saveName error:NULL];
			 
			 [fileManager createDirectoryAtPath:saveName withIntermediateDirectories:YES attributes:nil error:NULL];
			 
			 //Output all the steps for all the submodels.
			 for(modelCounter = 0; modelCounter < [[[self documentContents] submodels] count]; modelCounter++)
			 {
				 fileCopy = [[self documentContents] copy];
				 
				 //Move the target model to the top of the file. That way L3P will know to
				 // render it!
				 LDrawMPDModel *currentModel = [[fileCopy submodels] objectAtIndex:modelCounter];
				 [currentModel retain];
				 [fileCopy removeDirective:currentModel];
				 [fileCopy insertDirective:currentModel atIndex:0];
				 [fileCopy setActiveModel:currentModel];
				 [currentModel release];
				 
				 //Make a new folder for the model's steps.
				 modelName	= [NSString stringWithFormat:modelnameFormat, [currentModel modelName]];
				 folderName	= [saveName stringByAppendingPathComponent:modelName];
				 
				 [fileManager createDirectoryAtPath:folderName withIntermediateDirectories:YES attributes:nil error:NULL];
				 
				 //Write out each step!
				 for(counter = [[currentModel steps] count]-1; counter >= 0; counter--)
				 {
					 fileString		= [fileCopy write];
					 fileOutputData	= [fileString dataUsingEncoding:NSUTF8StringEncoding];
					 
					 outputName = [NSString stringWithFormat: filenameFormat,
								   [currentModel modelName],
								   (long)counter+1 ];
					 outputPath = [folderName stringByAppendingPathComponent:outputName];
					 [fileManager createFileAtPath:outputPath
										  contents:fileOutputData
										attributes:nil ];
					 
					 //Remove the step we just wrote, so that the next cycle won't
					 // include it. We can safely do this because we are working with
					 // a copy of the file!
					 [currentModel removeDirectiveAtIndex:counter];
				 }
				 
				 
				 [fileCopy release];
				 
			 }
			 
		 }
	 }];

}//end exportSteps:


//========== revealInFinder: ===================================================
//
// Purpose:             Open a Finder window with the current file selected.
//
//==============================================================================
- (IBAction) revealInFinder:(id)sender
{
    // Cribbed directly from
    // http://stackoverflow.com/questions/7652928/launch-osx-finder-window-with-specific-files-selected
    NSArray *fileURLs = [NSArray arrayWithObjects:[self fileURL], nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    
}//end revealInFinder:

#pragma mark -
#pragma mark Edit Menu

//========== cut: ==============================================================
//
// Purpose:		Respond to an Edit->Cut action.
//
//==============================================================================
- (IBAction) cut:(id)sender {

	NSUndoManager	*undoManager		= [self undoManager];

	[self copy:sender];
	[self delete:sender]; //that was easy.

	[undoManager setActionName:NSLocalizedString(@"", nil)];
	
}//end cut:


//========== copy: =============================================================
//
// Purpose:		Respond to an Edit->Copy action.
//
//==============================================================================
- (IBAction) copy:(id)sender {

	NSPasteboard	*pasteboard			= [NSPasteboard generalPasteboard];
	NSArray			*selectedObjects	= [self selectedObjects];
	
	[self writeDirectives:selectedObjects
			 toPasteboard:pasteboard];
	
}//end copy:


//========== paste: ============================================================
//
// Purpose:		Respond to an Edit->Paste action, pasting the contents off the 
//				standard copy/paste pasteboard.
//
//==============================================================================
- (IBAction) paste:(id)sender
{
	NSPasteboard	*pasteboard			= [NSPasteboard generalPasteboard];
	NSUndoManager	*undoManager		= [self undoManager];
	
	[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"", nil)];
	
}//end paste:


//========== delete: ===========================================================
//
// Purpose:		A delete request has arrived from somplace--it could be the 
//				menus, the window, the outline view, etc. Our job is to delete
//				the current selection now.
//
// Notes:		This method conveniently has the same name as one in NSText; 
//				that allows us to use the same menu item for both textual and 
//				part delete.
//
//==============================================================================
- (IBAction) delete:(id)sender
{
	NSArray         *selectedObjects    = [self selectedObjects];
	LDrawDirective  *currentObject      = nil;
	NSInteger       counter;
	
	//We'll just try to delete everything. Count backwards so that if a 
	// deletion fails, it's the thing at the top rather than the bottom that 
	// remains.
	for(counter = [selectedObjects count]-1; counter >= 0; counter--)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([self canDeleteDirective:currentObject displayErrors:YES] == YES)
		{	//above method will display an error if the directive can't be deleted.
			[self deleteDirective:currentObject];
		}
	}
	
	[fileContentsOutline deselectAll:sender];
	[[self documentContents] noteNeedsDisplay];
}//end delete:


//========== selectAll: ========================================================
//
// Purpose:		Selects all the visible LDraw elements in the active model. This 
//				does not select the steps or model--only the contained elements 
//				themselves. Hidden elements are also ignored.
//
//==============================================================================
- (IBAction) selectAll:(id)sender
{
	LDrawModel  *activeModel    = [[self documentContents] activeModel];
	NSArray     *elements       = [activeModel allEnclosedElements];
	id          currentElement  = nil;
	NSInteger   counter         = 0;
	
	//Deselect all first.
	[self selectDirective:nil byExtendingSelection:NO];
	
	//Select everything now.
	for(counter = 0; counter < [elements count]; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		if(		[currentElement respondsToSelector:@selector(isHidden)] == NO
			||	[currentElement isHidden] == NO)
		{
			[self selectDirective:currentElement byExtendingSelection:YES];
		}
	}
}//end selectAll:


//========== duplicate: ========================================================
//
// Purpose:		Makes a copy of the selected object.
//
//==============================================================================
- (IBAction) duplicate:(id)sender
{
	// To take advantage of all the exceptionally cool copy/paste code we 
	// already have, -duplicate: simply "copies" the selection onto a private 
	// pasteboard then "pastes" it right back in. This avoids destroying the 
	// general pasteboard, but allows us some fabulous code reuse. (In case you 
	// haven't noticed, I'm proud of this!) 
	NSPasteboard	*pasteboard			= [NSPasteboard pasteboardWithName:@"BricksmithDuplicationPboard"];
	NSArray			*selectedObjects	= [self selectedObjects];
	NSUndoManager	*undoManager		= [self undoManager];
	
	[self writeDirectives:selectedObjects toPasteboard:pasteboard];
	[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];

	[undoManager setActionName:NSLocalizedString(@"UndoDuplicate", nil)];
	
}//end duplicate:


//========== orderFrontMovePanel: ==============================================
//
// Purpose:		Opens the advanced rotation panel that provides fine part 
//				rotation controls.
//
//==============================================================================
- (IBAction) orderFrontMovePanel:(id)sender
{
	MovePanel *panel = [MovePanel movePanel];
	
	[panel makeKeyAndOrderFront:self];

}//end orderFrontMovePanel:


//========== orderFrontRotationPanel: ==========================================
//
// Purpose:		Opens the advanced rotation panel that provides fine part 
//				rotation controls.
//
//==============================================================================
- (IBAction) orderFrontRotationPanel:(id)sender
{
	RotationPanelController *rotateController = [RotationPanelController rotationPanel];
	
	[[rotateController window] makeKeyAndOrderFront:self];

}//end openRotationPanel:


#pragma mark -

//========== quickRotateClicked: ===============================================
//
// Purpose:		One of the quick rotation shortcuts was clicked. Build a 
//				rotation in the requested direction (deduced from the sender's 
//				tag). 
//
//==============================================================================
- (IBAction) quickRotateClicked:(id)sender
{
	menuTagsT	tag			= [sender tag];
	Vector3		rotation	= ZeroPoint3;
	
	switch(tag)
	{
		case rotatePositiveXTag:	rotation = V3Make( 1,  0,  0);	break;
		case rotateNegativeXTag:	rotation = V3Make(-1,  0,  0);	break;
		case rotatePositiveYTag:	rotation = V3Make( 0,  1,  0);	break;
		case rotateNegativeYTag:	rotation = V3Make( 0, -1,  0);	break;
		case rotatePositiveZTag:	rotation = V3Make( 0,  0,  1);	break;
		case rotateNegativeZTag:	rotation = V3Make( 0,  0, -1);	break;
		default:													break;
	}
	[self rotateSelectionAround:rotation];
	
}//end quickRotateClicked:


#pragma mark -
#pragma mark Tools Menu

//========== showInspector: ====================================================
//
// Purpose:		Opens the inspector window. It may have something in it; it may 
//				not. That's up to the document.
//
//				I presume this method will take precedence over the one in 
//				LDrawApplication when a document is opened. This is not 
//				necessarily a good thing, but oh well.
//
//==============================================================================
- (IBAction) showInspector:(id)sender
{
	[[LDrawApplication sharedInspector] show:sender];
	
}//end showInspector:


//========== toggleFileContentsDrawer: =========================================
//
// Purpose:		Either open or close the file contents outline.
//
// Notes:		Now that the file contents is part of the main window, this has 
//				gotten quite a bit more complicated. 
//
//==============================================================================
- (IBAction) toggleFileContentsDrawer:(id)sender
{
	NSView	*firstSubview	= [[self->fileContentsSplitView subviews] objectAtIndex:0];
	CGFloat	maxPosition		= 0.0;
	
	// We collapse or un-collapse the split view.
	if([self->fileContentsSplitView isSubviewCollapsed:firstSubview])
	{
		// Un-collapse the view
		maxPosition = [[self->fileContentsSplitView delegate] splitView:self->fileContentsSplitView
												 constrainMinCoordinate:0.0
															ofSubviewAt:0];
															
		[self->fileContentsSplitView setPosition:maxPosition ofDividerAtIndex:0];
	}
	else
	{
		// Collapse the view
		[self->fileContentsSplitView setPosition:0.0 ofDividerAtIndex:0];
	}
	
}//end toggleFileContentsDrawer:


//========== gridGranularityMenuChanged: =======================================
//
// Purpose:		We just used the menubar to change the granularity of the grid. 
//				This is rather irritating because we need to manage the other 
//				visual indicators of the selection:
//				1) the checkmark in the menu itself
//				2) the selection in the toolbar's grid widget.
//				The menu we will handle in -validateMenuItem:.
//				The toolbar is trickier.
//
//==============================================================================
- (IBAction) gridGranularityMenuChanged:(id)sender
{
	NSInteger           menuTag     = [sender tag];
	gridSpacingModeT    newGridMode = gridModeFine;;
	
	
	switch(menuTag)
	{
		case gridFineMenuTag:
			newGridMode = gridModeFine;
			break;
		
		case gridMediumMenuTag:
			newGridMode = gridModeMedium;
			break;
		
		case gridCoarseMenuTag:
			newGridMode = gridModeCoarse;
			break;
	}
	
	[self setGridSpacingMode:newGridMode];
	
}//end gridGranularityMenuChanged:


//========== showDimensions: ===================================================
//
// Purpose:		Shows the dimensions window for this model.
//
//==============================================================================
- (IBAction) showDimensions:(id)sender {

	DimensionsPanel *dimensions = nil;
	
	dimensions = [DimensionsPanel dimensionPanelForFile:[self documentContents]];
	
	[NSApp beginSheet:dimensions
	   modalForWindow:[self windowForSheet]
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL ];
		  
}//end showDimensions


//========== showPieceCount: ===================================================
//
// Purpose:		Shows the dimensions window for this model.
//
//==============================================================================
- (IBAction) showPieceCount:(id)sender {
	
	PieceCountPanel *pieceCount = nil;
	
	pieceCount = [PieceCountPanel pieceCountPanelForFile:[self documentContents]];
	
	[NSApp beginSheet:pieceCount
	   modalForWindow:[self windowForSheet]
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL ];
		  
}//end showPieceCount:


#pragma mark -
#pragma mark View Menu

//========== zoomActual: =======================================================
//
// Purpose:		Zoom to 100%.
//
//==============================================================================
- (IBAction) zoomActual:(id)sender
{
	[mostRecentLDrawView setZoomPercentage:100];
	
}//end zoomActual:


//========== zoomIn: ===========================================================
//
// Purpose:		Enlarge the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomIn:(id)sender
{
	[mostRecentLDrawView zoomIn:sender];
	
}//end zoomIn:


//========== zoomOut: ==========================================================
//
// Purpose:		Shrink the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomOut:(id)sender
{
	[mostRecentLDrawView zoomOut:sender];
	
}//end zoomOut:


//========== viewOrientationSelected: ==========================================
//
// Purpose:		The user has chosen a new viewing angle from a menu.
//				sender is the menu item, whose tag is the viewing angle. We'll 
//				just pass this off to the appropriate view.
//
// Note:		This method will get skipped entirely if an LDrawGLView is the 
//				first responder; the message will instead go directly there 
//				because this method has the same name as the one in LDrawGLView.
//
//==============================================================================
- (IBAction) viewOrientationSelected:(id)sender
{
	[self->mostRecentLDrawView viewOrientationSelected:sender];
	
}//end viewOrientationSelected:


//========== toggleStepDisplay: ================================================
//
// Purpose:		Turns step display (like Lego instructions) on or off for the 
//				active model.
//
//==============================================================================
- (IBAction) toggleStepDisplay:(id)sender
{
	LDrawMPDModel	*activeModel	= [[self documentContents] activeModel];
	BOOL			 stepDisplay	= [activeModel stepDisplay];
	
	if(stepDisplay == NO) //was off; so turn it on.
		[self setStepDisplay:YES];
	else //on; turn it off now
		[self setStepDisplay:NO];
	
}//end toggleStepDisplay:


//========== advanceOneStep: ===================================================
//
// Purpose:		Moves the step display forward one step.
//
//==============================================================================
- (IBAction) advanceOneStep:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       currentStep     = [activeModel maximumStepIndexForStepDisplay];
	NSInteger       numberSteps     = [[activeModel steps] count];
	
	[self setCurrentStep: (currentStep+1) % numberSteps ];
	
}//end advanceOneStep:


//========== backOneStep: ======================================================
//
// Purpose:		Displays the previous step.
//
//==============================================================================
- (IBAction) backOneStep:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       currentStep     = [activeModel maximumStepIndexForStepDisplay];
	NSInteger       numberSteps     = [[activeModel steps] count];
	
	// Wrap around?
	if(currentStep == 0)
		currentStep = numberSteps;
	
	[self setCurrentStep: (currentStep-1) % numberSteps ];

}//end backOneStep:


//========== useSelectionForRotationCenter: ====================================
//
// Purpose:		Defines the model's rotation center.
//
//==============================================================================
- (IBAction) useSelectionForRotationCenter:(id)sender
{
	NSMutableArray *selectedDrawables = [NSMutableArray array];
	
	for(id currentDirective in self->selectedDirectives)
	{
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			[selectedDrawables addObject:currentDirective];
		}
	}
	
	if([selectedDrawables count] == 0)
	{
		[[self->documentContents activeModel] setRotationCenter:ZeroPoint3];
	}
	else
	{
		[[self->documentContents activeModel] setRotationCenter:[(LDrawDrawableElement*)[selectedDrawables objectAtIndex:0] position]];
	}
	
}//end useSelectionForRotationCenter:


//========== clearRotationCenter: ==============================================
//
// Purpose:		Resets rotation center to the origin.
//
//==============================================================================
- (IBAction) clearRotationCenter:(id)sender
{
	[[self->documentContents activeModel] setRotationCenter:ZeroPoint3];
		
}//end clearRotationCenter:


#pragma mark -
#pragma mark Piece Menu

//========== showParts: ========================================================
//
// Purpose:		Un-hides all selected parts.
//
//==============================================================================
- (IBAction) showParts:(id)sender
{
	[self setSelectionToHidden:NO];	//unhide 'em
	
}//end showParts:


//========== hideParts: ========================================================
//
// Purpose:		Hides all selected parts so that they are not drawn.
//
//==============================================================================
- (IBAction) hideParts:(id)sender
{
	[self setSelectionToHidden:YES]; //hide 'em
	
}//end hideParts:


//========== showAllParts: =====================================================
//
// Purpose:		Unhides all hidden parts.
//
//==============================================================================
- (IBAction) showAllParts:(id)sender
{
	LDrawModel  *activeModel    = [[self documentContents] activeModel];
	NSArray     *elements       = [activeModel allEnclosedElements];
	id          currentElement  = nil;
	NSInteger   counter         = 0;
	
	// Show everything
	for(counter = 0; counter < [elements count]; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		
		if(		[currentElement respondsToSelector:@selector(setHidden:)]
		   &&	[currentElement isHidden] == YES)
		{
			[self setElement:currentElement toHidden:NO]; //undoable hook.
		}
	}
}//end showAllParts:


//========== snapSelectionToGrid: ==============================================
//
// Purpose:		Aligns all selected parts to the current grid setting.
//
//==============================================================================
- (void) snapSelectionToGrid:(id)sender
{	
	NSUserDefaults      *userDefaults       = [NSUserDefaults standardUserDefaults];
	NSArray             *selectedObjects    = [self selectedObjects];
	id                  currentObject       = nil;
	float               gridSpacing         = 0;
	float               degreesToRotate     = 0;
	NSInteger           counter             = 0;
	TransformComponents snappedComponents   = IdentityComponents;
	
	//Determine granularity of grid.
	switch([self gridSpacingMode])
	{
		case gridModeFine:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_FINE];
			degreesToRotate	= GRID_ROTATION_FINE;	//15 degrees
			break;
		
		case gridModeMedium:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_MEDIUM];
			degreesToRotate	= GRID_ROTATION_MEDIUM;	//45 degrees
			break;
		
		case gridModeCoarse:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_COARSE];
			degreesToRotate	= GRID_ROTATION_COARSE;	//90 degrees
			break;
	}
	
	//nudge everything that can be rotated. That would be parts and only parts.
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
		if([currentObject isKindOfClass:[LDrawPart class]])
		{
			snappedComponents = [currentObject 
										componentsSnappedToGrid:gridSpacing
												   minimumAngle:degreesToRotate];
			[self setTransformation:snappedComponents
							forPart:currentObject];
		}
		
	}//end update loop
	
	[[self documentContents] noteNeedsDisplay];
}//end snapSelectionToGrid


#pragma mark -
#pragma mark Models Menu

//========== addModelClicked: ==================================================
//
// Purpose:		Create a new model and add it to the current file.
//
//==============================================================================
- (IBAction) addModelClicked:(id)sender
{
	LDrawMPDModel	*newModel		= [LDrawMPDModel model];

	[self addModel:newModel atIndex:NSNotFound preventNameCollisions:YES];
	[self setActiveModel:newModel];
	[[self documentContents] noteNeedsDisplay];
	
}//end modelSelected


//========== addStepClicked: ===================================================
//
// Purpose:		Adds a new step wherever it belongs.
//
//==============================================================================
- (IBAction) addStepClicked:(id)sender
{
	LDrawStep		*newStep		= [LDrawStep emptyStep];

	[self addStep:newStep parent:[self selectedModel] index:NSNotFound];
	
}//end addStepClicked:


//========== addPartClicked: ===================================================
//
// Purpose:		Adds a new step to the currently-displayed model. If a part of 
//				the model is already selected, the step will be added after 
//				selection. Otherwise, the step appears at the end of the list.
//
//==============================================================================
- (IBAction) addPartClicked:(id)sender
{	
	NSUserDefaults				*userDefaults			= [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT			partBrowserStyle		= [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	PartBrowserPanelController	*partBrowserController	= nil;
	
	switch(partBrowserStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//is it open?
			if([self->partBrowserDrawer state] == NSDrawerOpenState)
				[self->partsBrowser addPartClicked:sender];
			else
				[self->partBrowserDrawer open];
			
			break;
			
		case PartBrowserShowAsPanel:
			
			partBrowserController = [PartBrowserPanelController sharedPartBrowserPanel];
			
			//is it open and foremost?
			if([[partBrowserController window] isKeyWindow] == YES)
				[[partBrowserController partBrowser] addPartClicked:sender];
			else
				[[partBrowserController window] makeKeyAndOrderFront:sender];
			
			break;
	} 
	
}//end addPartClicked:


//========== addSubmodelReferenceClicked: ======================================
//
// Purpose:		Add a reference in the current model to the MPD submodel 
//				selected.
//
// Parameters:	sender: the NSMenuItem representing the submodel to add.
//
//==============================================================================
- (void) addSubmodelReferenceClicked:(id)sender
{
	NSString		*partName			= nil;
	LDrawMPDModel	*referencedModel = [[self documentContents] modelWithName:nil];
	LDrawMPDModel	*destinationModel	= [self selectedModel];
	BOOL			circularReference	= NO;
	
	if(destinationModel == nil)
		destinationModel = [[self documentContents] activeModel];
		
	partName			= [[sender representedObject] modelName];
	referencedModel 	= [[self documentContents] modelWithName:partName];
	circularReference	= [referencedModel containsReferenceTo:[destinationModel modelName]];
	
	//We got a part; let's add it!
	if(partName != nil && circularReference == NO){
		[self addPartNamed:partName];
	}
	
	if(circularReference)
	{
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert setMessageText:NSLocalizedString(@"CircularReferenceMessage", nil)];
		[alert setInformativeText:NSLocalizedString(@"CircularReferenceInformative", nil)];
		
		NSBeep();
		[alert beginSheetModalForWindow:[self windowForSheet]
						  modalDelegate:nil
						 didEndSelector:NULL
							contextInfo:NULL ];
		[alert release];
	}
}//end addSubmodelReferenceClicked:


//========== addLineClicked: ===================================================
//
// Purpose:		Adds a new line primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addLineClicked:(id)sender
{
	LDrawLine       *newLine        = [[[LDrawLine alloc] init] autorelease];
	NSUndoManager   *undoManager    = [self undoManager];
	LDrawColor      *selectedColor  = [[LDrawColorPanel sharedColorPanel] LDrawColor];
	Point3          position        = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newLine setVertex1:position];
	[newLine setVertex2:V3Make(position.x + 80, position.y - 80, position.z)];
	
	[newLine setLDrawColor:selectedColor];
	
	[self addStepComponent:newLine parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddLine", nil)];
	[[self documentContents] noteNeedsDisplay];
	
}//end addLineClicked:


//========== addTriangleClicked: ===============================================
//
// Purpose:		Adds a new triangle primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addTriangleClicked:(id)sender
{
	LDrawTriangle	*newTriangle	= [[[LDrawTriangle alloc] init] autorelease];
	NSUndoManager	*undoManager	= [self undoManager];
	LDrawColor      *selectedColor  = [[LDrawColorPanel sharedColorPanel] LDrawColor];
	Point3          position        = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newTriangle setVertex1:position];
	[newTriangle setVertex2:V3Make(position.x + 80, position.y -   0, position.z)];
	[newTriangle setVertex3:V3Make(position.x + 40, position.y -  40, position.z)];
	
	[newTriangle setLDrawColor:selectedColor];
	
	[self addStepComponent:newTriangle parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddTriangle", nil)];
	[[self documentContents] noteNeedsDisplay];
	
}//end addTriangleClicked:


//========== addQuadrilateralClicked: ==========================================
//
// Purpose:		Adds a new quadrilateral primitive to the currently-displayed 
//				model.
//
//==============================================================================
- (IBAction) addQuadrilateralClicked:(id)sender
{
	LDrawQuadrilateral  *newQuadrilateral   = [[[LDrawQuadrilateral alloc] init] autorelease];
	NSUndoManager       *undoManager        = [self undoManager];
	LDrawColor          *selectedColor      = [[LDrawColorPanel sharedColorPanel] LDrawColor];
	Point3              position            = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newQuadrilateral setVertex1:position];
	[newQuadrilateral setVertex2:V3Make(position.x + 80, position.y -   0, position.z)];
	[newQuadrilateral setVertex3:V3Make(position.x + 80, position.y -  80, position.z)];
	[newQuadrilateral setVertex4:V3Make(position.x +  0, position.y -  80, position.z)];
	
	[newQuadrilateral setLDrawColor:selectedColor];
	
	[self addStepComponent:newQuadrilateral parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddQuadrilateral", nil)];
	[[self documentContents] noteNeedsDisplay];
	
}//end addQuadrilateralClicked:


//========== addConditionalClicked: ============================================
//
// Purpose:		Adds a new conditional-line primitive to the currently-displayed 
//				model.
//
//==============================================================================
- (IBAction) addConditionalClicked:(id)sender
{
	LDrawConditionalLine    *newConditional = [[[LDrawConditionalLine alloc] init] autorelease];
	NSUndoManager           *undoManager    = [self undoManager];
	LDrawColor              *selectedColor  = [[LDrawColorPanel sharedColorPanel] LDrawColor];
	
	[newConditional setLDrawColor:selectedColor];
	
	[self addStepComponent:newConditional parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddConditionalLine", nil)];
	[[self documentContents] noteNeedsDisplay];
	
}//end addConditionalClicked:


//========== addCommentClicked: ================================================
//
// Purpose:		Adds a new comment primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addCommentClicked:(id)sender
{
	LDrawComment	*newComment		= [[[LDrawComment alloc] init] autorelease];
	NSUndoManager	*undoManager	= [self undoManager];
	
	[self addStepComponent:newComment parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddComment", nil)];
}//end addCommentClicked:


//========== addRawCommandClicked: =============================================
//
// Purpose:		Adds a new comment primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addRawCommandClicked:(id)sender
{
	LDrawMetaCommand	*newCommand		= [[[LDrawMetaCommand alloc] init] autorelease];
	NSUndoManager		*undoManager	= [self undoManager];
	
	[self addStepComponent:newCommand parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddMetaCommand", nil)];
}//end addCommentClicked:


//========== addMinifigure: ====================================================
//
// Purpose:		Create a new minifigure with the amazing Minifigure Generator 
//				and add it to the model.
//
//==============================================================================
- (void) addMinifigure:(id)sender
{
	MinifigureDialogController  *minifigDialog  = [MinifigureDialogController new];
	NSInteger                   result          = NSCancelButton;
	LDrawMPDModel               *minifigure     = nil;
	
	result = [minifigDialog runModal];
	if(result == NSOKButton)
	{
		minifigure = [minifigDialog minifigure];
		[minifigure optimizeOpenGL];
		[self addModel:minifigure atIndex:NSNotFound preventNameCollisions:YES];
	}
	
	[minifigDialog release];
	
}//end addMinifigure:


//========== modelSelected: ====================================================
//
// Purpose:		A new model from the Models menu was chosen to be the active 
//				model.
//
// Parameters:	sender: an NSMenuItem representing the model to make active.
//
//==============================================================================
- (void) modelSelected:(id)sender
{
	LDrawMPDModel	*newActiveModel		= [sender representedObject];

	[self setActiveModel:newActiveModel];
		
}//end modelSelected

#pragma mark Models Menu - LSynth Submenu

//========== insertSynthesizableDirective: =====================================
//
// Purpose:		Insert a synthesizable directive into the model.  This is a
//              hose, band or part.
//
// Parameters:	sender: an NSMenuItem representing the model to make active.
//
//==============================================================================
- (void) insertSynthesizableDirective:(id)sender
{
    LDrawLSynth         *synthesizedObject = [[[LDrawLSynth alloc] init] autorelease];
    //NSUndoManager       *undoManager   = [self undoManager];

    // TODO: fixup colour choice for synthesizable parts
    // from partbrowserdatasource:
    // [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]
    //LDrawColor          *selectedColor = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor];
    // Allow for no color selected
    LDrawColor *selectedColor = [[LDrawColorPanel sharedColorPanel] LDrawColor];
    NSString *type = [[sender representedObject] objectForKey:@"LSYNTH_TYPE"];

    //[synthesizedObject setImageName:[[sender representedObject] objectForKey:@"title"]];
    [synthesizedObject setLDrawColor:selectedColor];
    [synthesizedObject setLsynthType:type];

    // The represented object passed in from the menu click indicates whether it's a band or a hose.
    // All well and good, and useful when e.g. deciding how and whether to display constraints.
    // However we also have to consider Parts, which can be either Band Parts or Hose Parts, and
    // need to retain their Part-ness.  To this end we must do a manual lookup of the actual class.
    // TODO: another place that config should provide a convenience method for this
    if ([[[[NSApp delegate] lsynthConfiguration] getQuickRefHoses] containsObject:type]) {
        [synthesizedObject setLsynthClass:LSYNTH_HOSE];
    }
    else if ([[[[NSApp delegate] lsynthConfiguration] getQuickRefBands] containsObject:type]){
        [synthesizedObject setLsynthClass:LSYNTH_BAND];
    }
    else if ([[[[NSApp delegate] lsynthConfiguration] getQuickRefParts] containsObject:type]){
        [synthesizedObject setLsynthClass:LSYNTH_PART];
    }

    // Check we're being called sensibly (i.e. from a menu)
    if (sender != nil && [sender representedObject] != nil) {

        // NEW
        LDrawContainer *parent = nil;
        NSInteger index = 0;

        // Step selected
        if ([[fileContentsOutline itemAtRow:[fileContentsOutline selectedRow]] isMemberOfClass:[LDrawStep class]]) {
            parent = [fileContentsOutline itemAtRow:[fileContentsOutline selectedRow]];
            index = [[parent subdirectives] count];
        }

        // No selection, add it at the bottom
        else if (self->lastSelectedPart == nil) {
            parent = nil;       // leave it up to the addStepComponent: method to add our Synth step correctly
            index = NSNotFound; // add at the end
        }
        
        // LDrawLSynth is selected
        // - Add it after
        // - Parent is the LDrawLSynth's parent step
        else if ([self->lastSelectedPart isMemberOfClass:[LDrawLSynth class]]) {
            parent = [fileContentsOutline parentForItem:self->lastSelectedPart];
            LDrawLSynth *synthPart = self->lastSelectedPart;
            index = [[parent subdirectives] indexOfObject:synthPart] + 1;
        }
        
        // Constraint is selected, add it after the containing LDrawLSynth
        else if ([self->lastSelectedPart isMemberOfClass:[LDrawPart class]] &&
                 [[fileContentsOutline parentForItem:self->lastSelectedPart] isMemberOfClass:[LDrawLSynth class]]) {
            parent = [fileContentsOutline parentForItem:[fileContentsOutline parentForItem:self->lastSelectedPart]];
            LDrawLSynth *synthPart = [fileContentsOutline parentForItem:self->lastSelectedPart];
            index = [[parent subdirectives] indexOfObject:synthPart] + 1;
        }

        // Don't know what it is.  Probably a part.
        else {
            NSLog(@"no idea");
            parent = nil;
            index = NSNotFound;
        }

        // tidy up to conform to other addStepComponent: calls and do the same with constraint adding to open up the tree
        //[self addStepComponent:synthesizedObject parent:nil index:NSNotFound];

        [self addStepComponent:synthesizedObject
                        parent:parent
                         index:index];
    }
    
}//end insertSynthesizedDirective:


//========== InsertLSynthConstraint: =======================================
//
// Purpose:		Insert a synthesizable directive constraint into the model.
//              We don't distinguish between hose or band constraints since
//              both types can be used for either synthesizable type.
//
// Parameters:	sender: an NSMenuItem representing the constraint to insert
//
//==============================================================================
-(void) InsertLSynthConstraint:(id)sender
{
    // We are fussier than for synthesizable containers; we can *only* be added to them.
    // We just have to worry about the relative position

    if(self->lastSelectedPart != nil) {
        LDrawPart *constraint = [[LDrawPart alloc] init];
        [constraint setDisplayName:[[sender representedObject] objectForKey:@"partName"]];
        [constraint setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]]; // parent's colour

        LDrawContainer *parent = nil;
        NSInteger index = NSNotFound;
        LDrawLSynth *synthesizablePart = nil;
        TransformComponents transformation = [lastSelectedPart transformComponents];
        [constraint setTransformComponents:transformation];

        // LDrawLSynth part selected, add at the end
        if ([self->lastSelectedPart isKindOfClass:[LDrawLSynth class]]) {
            parent = self->lastSelectedPart;
            index = [[parent subdirectives] count];
            synthesizablePart = parent;

            //  Add our constraint, resynthesize and mark as needing display
            [constraint setEnclosingDirective:parent];
            [constraint addObserver:parent];
            [parent insertDirective:constraint atIndex:index];
            [synthesizablePart synthesize];
            [[self documentContents] noteNeedsDisplay];

            // Show the new element
            [fileContentsOutline expandItem:parent];
            [fileContentsOutline selectObjects:[NSArray arrayWithObject:constraint]];
            [constraint setSelected:YES];
        }

        // If a constraint is selected (i.e. a part with an LDrawLSynth parent) add ourselves after it
        else if ([self->lastSelectedPart isKindOfClass:[LDrawDirective class]] &&
                [[fileContentsOutline parentForItem:self->lastSelectedPart] isMemberOfClass:[LDrawLSynth class]]) {
            parent = [fileContentsOutline parentForItem:self->lastSelectedPart];
            int row = [parent indexOfDirective:self->lastSelectedPart];
            index = row + 1;
            synthesizablePart = parent;

            //  Add our constraint, resynthesize and mark as needing display
            [constraint addObserver:parent];
            [parent insertDirective:constraint atIndex:index];
            [self updateInspector];
            [synthesizablePart synthesize];
            [[self documentContents] noteNeedsDisplay];
            [fileContentsOutline expandItem:parent];
            [fileContentsOutline selectObjects:[NSArray arrayWithObject:constraint]];
            [constraint setSelected:YES];
        }

        else {
            NSLog(@"BIG FAT CONSTRAINT ADDING ERROR");
        }
        [constraint release];
    }
} // end InsertLSynthConstraint

-(void) surroundLSynthConstraints:(id)sender
{
    NSLog(@"surroundLSynthConstraints");
}

-(void) invertLSynthConstraintSelection:(id)sender
{
    NSLog(@"invertLSynthConstraintSelection");
}

//========== insertINSIDEOUTSIDELSynthDirective: ===============================
//
// Purpose:		Insert an LSynth direction directive, INSIDE or OUTSIDE, which
//              causes a constraint to switch the side the band passes it.
//
//==============================================================================
-(void) insertINSIDEOUTSIDELSynthDirective:(id)sender
{
    NSLog(@"addINSIDEOUTSIDELSynthDirective");
    if(self->lastSelectedPart != nil) {
        LDrawLSynthDirective *direction = [[LDrawLSynthDirective alloc] init];

        // Set direction based on menuItem tag
        if ([(NSMenuItem *)sender tag] == lsynthInsertINSIDETag) {
            [direction setStringValue:@"INSIDE"];
        }
        else if ([(NSMenuItem *)sender tag] == lsynthInsertOUTSIDETag) {
            [direction setStringValue:@"OUTSIDE"];
        }
        else if ([(NSMenuItem *)sender tag] == lsynthInsertCROSSTag) {
            [direction setStringValue:@"CROSS"];
        }
        LDrawContainer *parent = nil;
        NSInteger index = NSNotFound;

        // LDrawLSynth part selected, add at the end
        if ([self->lastSelectedPart isKindOfClass:[LDrawLSynth class]]) {
            parent = self->lastSelectedPart;
            index = [[parent subdirectives] count];

        }

        // If a constraint is selected (i.e. a part with an LDrawLSynth parent) add ourselves after it
        else if ([self->lastSelectedPart isKindOfClass:[LDrawDirective class]] &&
                [[fileContentsOutline parentForItem:self->lastSelectedPart] isMemberOfClass:[LDrawLSynth class]]) {
            parent = [fileContentsOutline parentForItem:self->lastSelectedPart];
            int row = [parent indexOfDirective:self->lastSelectedPart];
            index = row + 1;
        }

        [direction setEnclosingDirective:parent];
        [direction addObserver:parent];
        [parent insertDirective:direction atIndex:index];
        [(LDrawLSynth *)parent synthesize];
        [[self documentContents] noteNeedsDisplay];
        [fileContentsOutline expandItem:parent];
        [fileContentsOutline selectObjects:[NSArray arrayWithObject:direction]];
        [direction setSelected:YES];
        [direction release];
    }
}//end insertINSIDEOUTSIDELSynthDirective:

#pragma mark -
#pragma mark UNDOABLE ACTIVITIES
#pragma mark -

//these are *low-level* calls which provide support for the Undo architecture.
// all of these are wrapped by high-level calls, which are all application-level 
// code should ever need to use.


//========== addDirective:toParent: ============================================
//
// Purpose:		Undo-aware call to add a directive to the specified parent.
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)newDirective
			 toParent:(LDrawContainer * )parent
{
	NSInteger index = [[parent subdirectives] count];
	
	[self addDirective:newDirective
			  toParent:parent
			   atIndex:index];
			   
}//end addDirective:toParent:


//========== addDirective:toParent:atIndex: ====================================
//
// Purpose:		Undo-aware call to add a directive to the specified parent.
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)newDirective
			 toParent:(LDrawContainer * )parent
			  atIndex:(NSInteger)index
{
	NSUndoManager	*undoManager	= [self undoManager];
	
	[[self documentContents] lockForEditing];
	self->lockViewingAngle = YES;
	{
		[[undoManager prepareWithInvocationTarget:self]
			deleteDirective:newDirective ];
	
		// Turn off change notifications while mutating steps. Fixes Step 
		// Display bug in which the viewing angle changes whenever inserting a 
		// part. 
		[parent insertDirective:newDirective atIndex:index];
	}
	CGLLockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	{
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		[self->documentContents optimizeVertexes];
		
	}
	self->lockViewingAngle = NO;
	CGLUnlockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	[[self documentContents] unlockEditor];
	
	[self updateInspector];
	
}//end addDirective:toParent:atIndex:


//========== deleteDirective: ==================================================
//
// Purpose:		Removes the specified doomedDirective from its enclosing 
//				container.
//
//==============================================================================
- (void) deleteDirective:(LDrawDirective *)doomedDirective
{
	NSUndoManager   *undoManager    = [self undoManager];
	LDrawContainer  *parent         = [doomedDirective enclosingDirective];
	NSInteger       index           = [[parent subdirectives] indexOfObject:doomedDirective];
	
	[[self documentContents] lockForEditing];
	self->lockViewingAngle = YES;
	{
		[[undoManager prepareWithInvocationTarget:self]
				addDirective:doomedDirective
					toParent:parent
					 atIndex:index ];
		
		[parent removeDirective:doomedDirective];

		[self updateInspector];
		[self->documentContents optimizeVertexes];
	}
	self->lockViewingAngle = NO;
	[[self documentContents] unlockEditor];

	// After a directive is deleted, we need to resynchronize our step field - maybe the current step changed.
	// There may be other places where we need this too.
	[self->stepField setIntegerValue:[[[self documentContents] activeModel] maximumStepIndexForStepDisplay] + 1];

}//end deleteDirective:


//========== moveDirective:inDirection: ========================================
//
// Purpose:		Undo-aware call to move the object in the direction indicated. 
//				The vector here should indicate the exact amount to move. It 
//				should be adjusted to the grid mode already).
//
//==============================================================================
- (void) moveDirective:(LDrawDrawableElement *)object
		   inDirection:(Vector3)moveVector
{
	NSUndoManager	*undoManager	= [self undoManager];
	Vector3			 opposite		= {0};
	
	//Prepare the undo.
	
	opposite.x = -(moveVector.x);
	opposite.y = -(moveVector.y);
	opposite.z = -(moveVector.z);
	
	[[self documentContents] lockForEditing];
	{
		[[self documentContents] unlockEditor];
		[[undoManager prepareWithInvocationTarget:self]
				moveDirective: object
				  inDirection: opposite ];
		[undoManager setActionName:NSLocalizedString(@"UndoMove", nil)];
		
		//Do the move.
		[object moveBy:moveVector];
		
		[self->documentContents optimizeVertexes];
//		[object optimizeOpenGL];

	}
	
	//our part changed; notify!
	[self updateInspector];
	[object noteNeedsDisplay];
								  
}//end moveDirective:inDirection:


//========== preserveDirectiveState: ===========================================
//
// Purpose:		Records the entire state of the object with the undo manager. 
//
// Note:		Undo operations are stored on a *stack*, so the order of undo 
//				registration in the code is the opposite from the order in 
//				which the undo operations are executed.
//
//==============================================================================
- (void) preserveDirectiveState:(LDrawDirective *)directive
{
	NSUndoManager	*undoManager	= [self undoManager];

	[[self documentContents] lockForEditing];
	{
		// ** Read code bottom-to-top ** //

		[[undoManager prepareWithInvocationTarget:directive] noteNeedsDisplay];
		[[undoManager prepareWithInvocationTarget:[directive enclosingModel]] optimizeVertexes];
		[directive registerUndoActions:undoManager];
		
		[[undoManager prepareWithInvocationTarget:self]
								preserveDirectiveState:directive ];
	}
	[[self documentContents] unlockEditor];
	
}//end preserveDirectiveState:


//========== rotatePart:onAxis:byDegrees: ======================================
//
// Purpose:		Undo-aware call to rotate the object in the direction indicated. 
//
// Notes:		This gets a little tricky because there is more than one way 
//				to represent a single rotation when using three rotation angles. 
//				Since we don't really know which one was intended, we can't just 
//				blithely manipulate the rotation components.
//
//				Instead, we must generate a new transformation matrix that 
//				rotates by degreesToRotate in the desired direction. Then we 
//				multiply that matrix by the part's current transformation. This 
//				way, we can rest assured that we rotated the part exactly the 
//				direction the user intended, no matter what goofy representation
//				the components came up with.
//
//				Caveat: We have to zero out the translation components of the 
//				part's transformation before we append our new rotation. Thus 
//				the part will be rotated in place.
//
//==============================================================================
- (void) rotatePart:(LDrawPart *)part
		  byDegrees:(Tuple3)rotationDegrees
		aroundPoint:(Point3)rotationCenter
{

	NSUndoManager	*undoManager		= [self undoManager];
	Tuple3			 oppositeRotation	= V3Negate(rotationDegrees);
	
	[[undoManager prepareWithInvocationTarget:self]
			rotatePart: part
			 byDegrees: oppositeRotation
		   aroundPoint: rotationCenter  ]; //undo: rotate backwards
	[undoManager setActionName:NSLocalizedString(@"UndoRotate", nil)];
	
	
	[[self documentContents] lockForEditing];
	{
		[part rotateByDegrees:rotationDegrees centerPoint:rotationCenter];
//		[part optimizeOpenGL];
	}
	[[self documentContents] unlockEditor];

	
	[self updateInspector];
	[part noteNeedsDisplay];
	
} //rotatePart:onAxis:byDegrees:


//========== setElement:toHidden: ==============================================
//
// Purpose:		Undo-aware call to change the visibility attribute of an element.
//
//==============================================================================
- (void) setElement:(LDrawDrawableElement *)element toHidden:(BOOL)hideFlag
{
	NSUndoManager	*undoManager	= [self undoManager];
	NSString		*actionName		= nil;
	
	if(hideFlag == YES)
		actionName = NSLocalizedString(@"UndoHidePart", nil);
	else
		actionName = NSLocalizedString(@"UndoShowPart", nil);
	
	[[self documentContents] lockForEditing];
	{
		[[self documentContents] unlockEditor];
		[[undoManager prepareWithInvocationTarget:self]
			setElement:element
			  toHidden:(!hideFlag) ];
		[undoManager setActionName:actionName];
		
		[element setHidden:hideFlag];
		[self->documentContents optimizeVertexes];
	}
	[element noteNeedsDisplay];

}//end setElement:toHidden:


//========== setObject:toColor: ================================================
//
// Purpose:		Undo-aware call to change the color of an object.
//
//==============================================================================
- (void) setObject:(LDrawDirective <LDrawColorable>* )object toColor:(LDrawColor *)newColor
{
	NSUndoManager *undoManager = [self undoManager];
	
	[[undoManager prepareWithInvocationTarget:self]
												setObject:object
												  toColor:[object LDrawColor] ];
	[undoManager setActionName:NSLocalizedString(@"UndoColor", nil)];
	
	[[self documentContents] lockForEditing];
	{
		[object setLDrawColor:newColor];
		[object optimizeOpenGL];
		[self->documentContents optimizeVertexes];
	}
	[[self documentContents] unlockEditor];
	[self updateInspector];
	[object noteNeedsDisplay];

}//end setObject:toColor:


//========== setTransformation:forPart: ========================================
//
// Purpose:		Undo-aware call to set the entire transformation for a part. 
//				This is an important step in snapping a part to the grid.
//
//==============================================================================
- (void) setTransformation:(TransformComponents)newComponents
				   forPart:(LDrawPart *)part
{
	NSUndoManager		*undoManager		= [self undoManager];
	TransformComponents	 currentComponents	= [part transformComponents];
	
	[[self documentContents] lockForEditing];
	{
		[[self documentContents] unlockEditor];
		[part setTransformComponents:newComponents];
//		[part optimizeOpenGL];
		
		//Be ready to restore the old components.
		[[undoManager prepareWithInvocationTarget:self]
				setTransformation:currentComponents
						  forPart:part ];
		
		[undoManager setActionName:NSLocalizedString(@"UndoSnapToGrid", nil)];
	}
	[self updateInspector];
	[part noteNeedsDisplay];
	
}//end setTransformation:forPart:


#pragma mark -
#pragma mark OUTLINE VIEW
#pragma mark -

#pragma mark Data Source

//**** NSOutlineViewDataSource ****
//========== outlineView:numberOfChildrenOfItem: ===============================
//
// Purpose:		Returns the number of items which should be displayed under an 
//				expanded item.
//
//==============================================================================
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	NSInteger numberOfChildren = 0;
	
	//root object; return the number of submodels
	if(item == nil)
		numberOfChildren = [[documentContents submodels] count];
	
	//a step or model (or something); return the nth directives command
	else if([item isKindOfClass:[LDrawContainer class]])
		numberOfChildren = [[item subdirectives] count];
		
	return numberOfChildren;
	
}//end outlineView:numberOfChildrenOfItem:


//**** NSOutlineViewDataSource ****
//========== outlineView:isItemExpandable: =====================================
//
// Purpose:		Returns the number of items which should be displayed under an 
//				expanded item.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	//You can expand models and steps.
	if([item isKindOfClass:[LDrawContainer class]] )
		return YES;
	else
		return NO;
	
}//end outlineView:isItemExpandable:


//**** NSOutlineViewDataSource ****
//========== outlineView:child:ofItem: =========================================
//
// Purpose:		Returns the child of item at the position index.
//
//==============================================================================
- (id)outlineView:(NSOutlineView *)outlineView
			child:(NSInteger)index
		   ofItem:(id)item
{
	NSArray *children = nil;
	
	//children of the root object; the nth of models.
	if(item == nil)
		children = [documentContents submodels];
		
	//a container; return the nth subdirective.	
	else if([item isKindOfClass:[LDrawContainer class]])
		children = [item subdirectives];
	
	return [children objectAtIndex:index];
	
}//end outlineView:child:ofItem:


//**** NSOutlineViewDataSource ****
//========== outlineView:objectValueForTableColumn:byItem: =====================
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (id)			outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn
					 byItem:(id)item
{
	//Start off with a simple error message. Hopefully we won't see it.
	id representation = @"<Something went wrong here.>";
	
	//an LDraw directive; thank goodness! It knows how to describe itself.
	// The description will form the basis of the attributed text for the cell.
	if([item isKindOfClass:[LDrawDirective class]]) {
		representation = [item browsingDescription];
		
		//Apply formatting to our little string.
		representation = [self formatDirective:item
					  withStringRepresentation:representation];
    }

	return representation;

}//end outlineView:objectValueForTableColumn:byItem:


#pragma mark -
#pragma mark Drag and Drop

//**** NSOutlineViewDataSource ****
//========== outlineView:writeItems:toPasteboard: ==============================
//
// Purpose:		Initiates a drag. We drag directives by copying them at the 
//				outset. Upon the successful completion of the drag, we "paste" 
//				the copied directives wherever they landed, then delete the 
//				original objects.
//
//				We also drag a string representation of the objects for the 
//				benefit of other applications.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView
		 writeItems:(NSArray *)items
	   toPasteboard:(NSPasteboard *)pboard
{
	NSInteger		numberItems = [items count];
	NSMutableArray	*rowIndexes = [NSMutableArray arrayWithCapacity:numberItems];
	NSInteger		itemIndex	= 0;
	NSInteger		counter 	= 0;
	LDrawDirective	*firstItem	= [items objectAtIndex:0];
	BOOL disallow = NO;
	
	// Disallow dragging if it is the only step in the model
	if(		[items count] == 1
	   &&	[firstItem isKindOfClass:[LDrawStep class]]
	   &&	[[[firstItem enclosingModel] steps] count] == 1)
	{
		disallow = YES;
	}
	
	//Write the objects as data.
	[self writeDirectives:items toPasteboard:pboard];
	
	//Now write the row indexes out. We'll use them to delete the original 
	// objects in the event of a successful drag.
	for(counter = 0; counter < numberItems; counter++){
		itemIndex = [outlineView rowForItem:[items objectAtIndex:counter]];
		[rowIndexes addObject:[NSNumber numberWithInteger:itemIndex]];
	}
	[pboard addTypes:[NSArray arrayWithObjects:LDrawDragSourceRowsPboardType, LDrawDisallowDragToSourcePboardType, nil]
			   owner:nil];
	[pboard setPropertyList:rowIndexes forType:LDrawDragSourceRowsPboardType];
	
	if(disallow)
		[pboard setPropertyList:(id)kCFBooleanTrue forType:LDrawDisallowDragToSourcePboardType];
	else
		[pboard setPropertyList:(id)kCFBooleanFalse forType:LDrawDisallowDragToSourcePboardType];
	
	return YES;
	
}//end outlineView:writeItems:toPasteboard:


//**** NSOutlineViewDataSource ****
//========== outlineView:validateDrop:proposedItem:proposedChildIndex: =========
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView
				   validateDrop:(id <NSDraggingInfo>)info
				   proposedItem:(id)newParent
			 proposedChildIndex:(NSInteger)index
{
	NSPasteboard		*pasteboard		= [info draggingPasteboard];
	NSOutlineView		*sourceView		= [info draggingSource];
	NSDragOperation		 dragOperation	= NSDragOperationNone;
	
	//Fix our logic for handling drags to the root of the outline.
	if(newParent == nil)
		newParent = [self documentContents];
	
	//We must make sure we have the proper pasteboard type available.
	if(		index != NSOutlineViewDropOnItemIndex //not a "drop-on" operation.
	   &&	[[pasteboard types] containsObject:LDrawDirectivePboardType])
	{
		
		//This drag is acceptable. Now figure out the operation.
		if(sourceView == outlineView)
			dragOperation = NSDragOperationMove;
		else
			dragOperation = NSDragOperationCopy;
		
		//---------- Eliminate Illegal Positions -------------------------------
		
		//Read the first object off the pasteboard so we can figure 
		// out where this drop is allowed to happen.
		NSArray			*objects		= [pasteboard propertyListForType:LDrawDirectivePboardType];
		NSData			*data			= nil;
		id				 currentObject	= nil;
		
		//Unarchive.
		data			= [objects objectAtIndex:0];
		currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		//Now pop the data into our file.
		if(		sourceView == outlineView
		   &&	[[pasteboard types] containsObject:LDrawDisallowDragToSourcePboardType]
		   &&	[[pasteboard propertyListForType:LDrawDisallowDragToSourcePboardType] boolValue])
		{
//			NSLog(@"killing prohibited-into-source drag");
			dragOperation	= NSDragOperationNone;
		}
		
		else if(	[currentObject	isKindOfClass:[LDrawModel class]] == YES
				&&	[newParent		isKindOfClass:[LDrawFile class]] == NO)
		{
//			NSLog(@"killing model-not-in-file drag");
			dragOperation	= NSDragOperationNone;
		}
			
		else if(	[currentObject	isKindOfClass:[LDrawStep class]] == YES
				&&	[newParent		isKindOfClass:[LDrawModel class]] == NO)
		{
//			if([newParent isKindOfClass:[LDrawStep class]])
//				[outlineView setDropItem:[newParent enclosingDirective]
//							dropChildIndex:0];
//			NSLog(@"rejecting step drag to %@", [newParent class]);
			dragOperation	= NSDragOperationNone;
		}
		
		else if(	[currentObject	isKindOfClass:[LDrawContainer class]] == NO
				&&	[newParent		isKindOfClass:[LDrawContainer class]] == NO)
		{
//			NSLog(@"killing thingy-not-in-step");
			dragOperation	= NSDragOperationNone;
		}

        // Prohibit dragging non-constraint objects onto an LDrawLSynth part
        else if (   [currentObject	isKindOfClass:[LDrawPart class]]
                 && [newParent isKindOfClass:[LDrawLSynth class]]
                 && ![[LSynthConfiguration sharedInstance] isLSynthConstraint:currentObject]) {
            dragOperation	= NSDragOperationNone;
        }
	}
	return dragOperation;

}//end outlineView:validateDrop:proposedItem:proposedChildIndex:


//**** NSOutlineViewDataSource ****
//========== outlineView:acceptDrop:item:childIndex: ===========================
//
// Purpose:		Finishes the current drop, depositing as near as possible to 
//				the specified item.
//
// Notes:		Complexities lie within. Note them carefully.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView
		 acceptDrop:(id <NSDraggingInfo>)info
			   item:(id)newParent
		 childIndex:(NSInteger)dropIndex
{
	//Identify the root object if needed.
	if(newParent == nil)
		newParent = [self documentContents];
	
	NSPasteboard    *pasteboard             = [info draggingPasteboard];
	NSUndoManager   *undoManager            = [self undoManager];
	NSOutlineView   *sourceView             = [info draggingSource];
	NSMutableArray  *doomedObjects          = [NSMutableArray array];
	NSArray         *pastedObjects          = nil;
	BOOL            renameDuplicateModels   = YES;
	NSInteger       counter                 = 0;
	
	if(sourceView == outlineView)
	{
		//We dragged within the same table. That means we expect the original 
		// objects dragged to "move" to the new position. Well, we can't 
		// actually *move* them, since our drag is implemented as a copy-and-paste.
		// However, we can simply delete the original objects, which will 
		// look the same anyway.
		//
		// Note we're doing this *before* moving, so that the indexes are 
		// still correct.
		NSArray         *rowsToDelete   = nil;
		NSInteger       doomedIndex     = 0;
		LDrawDirective  *objectToDelete = nil;
		
		//Gather up the objects we'll be removing.
		rowsToDelete = [pasteboard propertyListForType:LDrawDragSourceRowsPboardType];
		for(counter = 0; counter < [rowsToDelete count]; counter++)
		{
			doomedIndex = [[rowsToDelete objectAtIndex:counter] integerValue];
			objectToDelete = [outlineView itemAtRow:doomedIndex];
			[doomedObjects addObject:objectToDelete];
		}
		
		// When rearranging models within a file, don't do "copy X" renaming.
		renameDuplicateModels = NO;
	}

    // Gather up (unique) parents that are donating child nodes to this move
    // If the parents support tidying up they'll be given a chance later.
    // This is intended for e.g. containers such as LDrawSynth that may need
    // to take action if their subdirectives change.
    NSMutableSet *donatingParents = [[NSMutableSet alloc] init];
    for (LDrawPart *part in doomedObjects) {
        [donatingParents addObject:[sourceView parentForItem:part]];
    }

    // Do The Move.
	pastedObjects = [self pasteFromPasteboard:pasteboard
						preventNameCollisions:renameDuplicateModels
									   parent:newParent
										index:dropIndex];
	
	if(sourceView == outlineView)
	{
		//Now that we've inserted the new objects, we need to delete the 
		// old ones.
		for(counter = 0; counter < [doomedObjects count]; counter++)
			[self deleteDirective:[doomedObjects objectAtIndex:counter]];
		
		[undoManager setActionName:NSLocalizedString(@"UndoReorder", nil)];
	}

    // Ask the source and target parents to cleanup if they can e.g. used for
    // updating container selection state
    for (LDrawDirective *parent in [donatingParents allObjects]) {
        if ([parent isKindOfClass:[LDrawContainer class]] &&
            [parent respondsToSelector:@selector(cleanupAfterDropIsDonor:)]) {
            [parent performSelector:@selector(cleanupAfterDropIsDonor:) withObject:[NSNumber numberWithBool:YES]];
        }
    }

    if ([newParent respondsToSelector:@selector(cleanupAfterDropIsDonor:)]) {
        [newParent performSelector:@selector(cleanupAfterDropIsDonor:) withObject:[NSNumber numberWithBool:NO]];
    }

    //And lastly, select the dragged objects.
	[(LDrawFileOutlineView*)outlineView selectObjects:pastedObjects];

    [donatingParents release];
	return YES;
	
}//end outlineView:acceptDrop:item:childIndex:



#pragma mark -
#pragma mark Delegate

//**** NSOutlineView ****
//========== outlineView:willDisplayCell:forTableColumn:item: ==================
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (void) outlineView:(NSOutlineView *)outlineView
	 willDisplayCell:(id)cell
	  forTableColumn:(NSTableColumn *)tableColumn
				item:(id)item
{
	NSString	*imageName = nil;
	NSImage		*theImage;
	
	if([item isKindOfClass:[LDrawDirective class]])
		imageName = [item iconName];
		
	if(imageName == nil || [imageName isEqualToString:@""])
		theImage = nil;
	else
		theImage = [NSImage imageNamed:imageName];
		
	[(IconTextCell *)cell setImage:theImage];
	
}//end outlineView:willDisplayCell:forTableColumn:item:


//**** NSOutlineView ****
//========== outlineViewSelectionDidChange: ====================================
//
// Purpose:		We have selected a different something in the file contents.
//				We need to show it as selected in the OpenGL viewing area.
//				This means we may have to change the active model or step in 
//				order to display the selection.
//
//==============================================================================
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView   *outlineView        = [notification object];
	NSArray         *selectedObjects    = [self selectedObjects];
	id              lastSelectedItem    = [outlineView itemAtRow:[outlineView selectedRow]];
	LDrawMPDModel   *selectedModel      = [self selectedModel];
	LDrawStep       *selectedStep       = [self selectedStep];
	NSInteger		selectedStepIndex	= 0;
	NSInteger       counter             = 0;
	
	// This method can be called from LDrawOpenGLView (in which case we already 
	// have a context we want to use) or it might be called on its own. Since 
	// selecting parts can trigger OpenGL commands, we should make sure we have 
	// a context active, but we should also restore the current context when 
	// we're done. 
	NSOpenGLContext *originalContext = [NSOpenGLContext currentContext];
	[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
	
	//Deselect all the previously-selected directives
	// (clears the internal directive flag used for drawing)
	for(counter = 0; counter < [self->selectedDirectives count]; counter++)
		[[selectedDirectives objectAtIndex:counter] setSelected:NO];
	
	//Tell the newly-selected directives that they just got selected.
	[selectedDirectives release];
	selectedDirectives = [selectedObjects retain];
	for(counter = 0; counter < [self->selectedDirectives count]; counter++)
		[[selectedDirectives objectAtIndex:counter] setSelected:YES];
	
	//Update things which need to take into account the entire selection.
	[[LDrawApplication sharedInspector] inspectObjects:selectedObjects];
	[[LDrawColorPanel sharedColorPanel] updateSelectionWithObjects:selectedObjects];
	if(selectedModel != nil)
	{
		// Put the selection on screen (if we need to)
		[self setActiveModel:selectedModel];
		
		// Advance to the current step (if we need to)
		if(selectedStep != nil)
		{
			selectedStepIndex = [selectedModel indexOfDirective:selectedStep];
			
			if(selectedStepIndex > [selectedModel maxStepIndexToOutput])
			{
				[self setCurrentStep:selectedStepIndex]; // update document UI
			}
		}
	}
	[[self documentContents] noteNeedsDisplay];
	
	//See if we just selected a new part; if so, we must remember it.
	if ([lastSelectedItem isKindOfClass:[LDrawPart class]] ||
        [lastSelectedItem isKindOfClass:[LDrawLSynth class]])
		[self setLastSelectedPart:lastSelectedItem];
	
	[originalContext makeCurrentContext];
	
}//end outlineViewSelectionDidChange:


#pragma mark -
#pragma mark MOUSE COORDINATES
#pragma mark -

//========== LDrawGLView:mouseIsOverPoint:confidence: ==========================
//
// Purpose:		Display the 3D world coordinates of the mouse as it hovers over 
//				the model. 
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView mouseIsOverPoint:(Point3)modelPoint confidence:(Tuple3)confidence
{
	[self->coordinateFieldX setFloatValue:modelPoint.x];
	[self->coordinateFieldY setFloatValue:modelPoint.y];
	[self->coordinateFieldZ setFloatValue:modelPoint.z];
	
	NSColor *questionableColor	= [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
	NSColor *confidentColor 	= [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
	
	[self->coordinateFieldX setTextColor:(confidence.x == 0.0) ? questionableColor : confidentColor];
	[self->coordinateFieldY setTextColor:(confidence.y == 0.0) ? questionableColor : confidentColor];
	[self->coordinateFieldZ setTextColor:(confidence.z == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelX setTextColor:(confidence.x == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelY setTextColor:(confidence.y == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelZ setTextColor:(confidence.z == 0.0) ? questionableColor : confidentColor];
	
	[self->coordinateFieldX setHidden:NO];
	[self->coordinateFieldY setHidden:NO];
	[self->coordinateFieldZ setHidden:NO];
	[self->coordinateLabelX setHidden:NO];
	[self->coordinateLabelY setHidden:NO];
	[self->coordinateLabelZ setHidden:NO];
}


//========== LDrawGLViewMouseExited: ===========================================
//
// Purpose:		The mouse location is no longer relevant to coordinate display. 
//				This could be because the mouse exited the view, or because it 
//				is controlling a tool which is not coordinate sensitive. 
//
//==============================================================================
- (void) LDrawGLViewMouseNotPositioning:(LDrawGLView *)glView
{
	[self->coordinateFieldX setHidden:YES];
	[self->coordinateFieldY setHidden:YES];
	[self->coordinateFieldZ setHidden:YES];
	[self->coordinateLabelX setHidden:YES];
	[self->coordinateLabelY setHidden:YES];
	[self->coordinateLabelZ setHidden:YES];
}


#pragma mark -
#pragma mark LDRAW GL VIEW
#pragma mark -

//**** LDrawGLView ****
//========== LDrawGLView:acceptDrop: ===========================================
//
// Purpose:		The user has deposited some drag-anddrop parts into an 
//			    LDrawGLView. Now they need to be imported into the model. 
//
// Notes:		Just like in -duplicate: and 
//				-outlineView:acceptDrop:item:childIndex:, we appropriate the 
//				pasting architecture to simplify importing the parts.
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView
		  acceptDrop:(id < NSDraggingInfo >)info
		  directives:(NSArray *)directives
{
	NSPasteboard    *pasteboard         = [NSPasteboard pasteboardWithName:@"BricksmithDragAndDropPboard"];
	NSUndoManager   *undoManager        = [self undoManager];
	NSInteger       selectionCount      = [self->selectedDirectives count];
	id              currentDirective    = nil;
	id              dragPart            = nil;
	Point3          originalPosition    = ZeroPoint3;
	Point3          dragPosition        = ZeroPoint3;
	Vector3         displacement        = ZeroPoint3;
	NSInteger       counter             = 0;
	NSInteger       dropDirectiveIndex  = 0;
	
	// Being dragged within the same document. We must simply apply the 
	// transforms from the dragged parts to the original parts, which have been 
	// hidden during the drag. 
	//
	// Exception: If we have no current selection, it means this was a copy 
	//			  drag. Just paste instead of updating.
	if(		[[info draggingSource] respondsToSelector:@selector(LDrawDirective)]
	   &&	[[info draggingSource] LDrawDirective] == [self documentContents]
	   &&	selectionCount > 0 )
	{
		for(counter = 0; counter < selectionCount; counter++)
		{
			currentDirective	= [self->selectedDirectives objectAtIndex:counter];
			
			if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
			{
				dragPart		= [directives objectAtIndex:dropDirectiveIndex];
				originalPosition= [(LDrawDrawableElement*)currentDirective position];
				dragPosition	= [(LDrawDrawableElement*)dragPart position];
				displacement	= V3Sub(dragPosition, originalPosition);

				[self moveDirective:currentDirective inDirection:displacement];
				[currentDirective setHidden:NO];
				
				dropDirectiveIndex++;
			}
		}
	}
	else
	{
		[self writeDirectives:directives toPasteboard:pasteboard];
		[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];
		[undoManager setActionName:NSLocalizedString(@"UndoDrop", nil)];
	}
	
	[self->documentContents optimizeVertexes];

}//end LDrawGLView:acceptDrop:


//**** LDrawGLView ****
//========== LDrawGLViewBecameFirstResponder: ==================================
//
// Purpose:		One of our model views just became active, so we need to update 
//				our display to represent that view's characteristics.
//
//==============================================================================
- (void) LDrawGLViewBecameFirstResponder:(LDrawGLView *)glView
{
	// We used bindings to sync up the ever-in-limbo zoom control.
	[self setMostRecentLDrawView:glView];

}//end LDrawGLViewBecameFirstResponder:


//========== LDrawGLView:dragHandleDidMove: ====================================
//
// Purpose:		A primitive's geometry is being directly manipulated.
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView dragHandleDidMove:(LDrawDragHandle *)dragHandle
{
	[self updateInspector];
}


//========== LDrawGLViewPartDragEnded: =========================================
//
// Purpose:		Part drag has ended, successfully or unsuccessfully. This is our 
//				opportunity to clean up.
//
//==============================================================================
- (void) LDrawGLViewPartDragEnded:(LDrawGLView*)glView
{
	[self->selectedDirectivesBeforeCopyDrag release];
	self->selectedDirectivesBeforeCopyDrag = nil;
}


//========== LDrawGLViewPartsWereDraggedIntoOblivion: ==========================
//
// Purpose:		The parts which originated the most recent drag operation have 
//				apparently been dragged clear out of the document. Maybe they 
//				went into another document. Maybe they got dragged into empty 
//				space. Whereever they went, they are gone now. 
//
//				The trouble is that when we started dragging them, we just *hid* 
//				them, in anticipation of their landing back within the document. 
//				(It was too much trouble to delete them at the beginning, 
//				because then we might have to reconstruct where they were in the 
//				model hierarchy if they did stay in the same document.) Now that 
//				we know they are really truly gone, we need to delete their 
//				hidden ghosts. 
//
//==============================================================================
- (void) LDrawGLViewPartsWereDraggedIntoOblivion:(LDrawGLView *)glView
{
	NSArray *directivesToDelete = [[self->selectedDirectives mutableCopy] autorelease];
	id		currentDirective	= nil;
	
	for(currentDirective in directivesToDelete)
	{
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			// Even though the directive has been drag-deleted, we still need to 
			// delete it in an undo-friendly way. That means we need to restore 
			// its visibility, since we hid the part when dragging began. 
			[currentDirective setHidden:NO];
		
			[self deleteDirective:currentDirective];
		}
	}
	
}//end LDrawGLViewPartsWereDraggedIntoOblivion:


//========== LDrawGLViewPreferredPartTransform: ================================
//
// Purpose:		Returns the part transform which would be nice applied to new 
//			    parts. This is used during Drag-and-Drop to unpack directives 
//			    and show them in the right place. 
//
//==============================================================================
- (TransformComponents) LDrawGLViewPreferredPartTransform:(LDrawGLView *)glView
{
	TransformComponents	components	 = IdentityComponents;
	
	// If we have a previously-selected part, honor it.
	if(self->lastSelectedPart != nil)
		components = [self->lastSelectedPart transformComponents];
		
	return components;
	
}//end LDrawGLViewPreferredPartTransform:


//**** LDrawGLView ****

//============ markPreviousSelection ============================================
//
// Purpose:		This function marks the current selection - each time 
//				wantsToSelectDirectives is called the new selection is calculated
//				relative to this marked one.  This sets the baseline for when the
//				marquee constantly rebuilds the selection.
//
//==============================================================================
- (void) markPreviousSelection
{
	if(self->markedSelection)
	{
		[self->markedSelection release];
		markedSelection = NULL;
	}
	
	markedSelection = [self selectedObjects];
	[markedSelection retain];	
}//end markPreviousSelection


//============ unmarkPreviousSelection ============================================
//
// Purpose:		This function purges the saved selection - it is called when the
//				marquee drag finishes to save memory.
//
//==============================================================================
- (void) unmarkPreviousSelection
{
	if(markedSelection)
	{
		[markedSelection release];
		markedSelection = NULL;
	}
}//end unmarkPreviousSelection


//========== LDrawGLView:wantsToSelectDirectives:selectionMode: ========
//
// Purpose:		The given LDrawView has decided some directives should be 
//				selected, probably because the user marquee selected.
//				If the array is empty, the old selection is still preserved if
//				"extension" is used.
//
//==============================================================================
- (void)	LDrawGLView:(LDrawGLView *)glView
 wantsToSelectDirectives:(NSArray *)directivesToSelect selectionMode:(SelectionModeT) selectionMode
 {
	if(markedSelection)
	{
		// Since we are going to do a bulk selection, calculate 
		// the union of the past selection and this one if we are
		// extending.  Otherwise we only want the new selection.
		NSMutableArray * all;
		NSArray * sel = (all = (selectionMode != SelectionReplace)
			? [NSMutableArray arrayWithArray:markedSelection] 
			: [NSMutableArray arrayWithArray:directivesToSelect]) ;
		
		if(selectionMode == SelectionExtend)
			[all addObjectsFromArray:directivesToSelect];
		else if(selectionMode == SelectionSubtract)
			[all removeObjectsInArray:directivesToSelect];
		else if(selectionMode == SelectionIntersection)
		{
			NSMutableSet *orig = [NSMutableSet setWithArray:markedSelection];
			[orig intersectSet:[NSSet setWithArray:directivesToSelect]];
			sel = [orig allObjects];
		}
		
		if([sel count])		
		{
			[self selectDirectives:sel];
		}
		else 
		{
			[self selectDirective:nil byExtendingSelection:NO];
		}
		
	}
	
}//end LDrawGLView:wantsToSelectDirectives:selectionMode:


//========== LDrawGLView:wantsToSelectDirective:byExtendingSelection: ==========
//
// Purpose:		The given LDrawView has decided some directive should be 
//				selected, probably because the user clicked on it.
//				Pass nil to mean deselect.
//
//==============================================================================
- (void)	LDrawGLView:(LDrawGLView *)glView
 wantsToSelectDirective:(LDrawDirective *)directiveToSelect
   byExtendingSelection:(BOOL) shouldExtend
{
	[self selectDirective:directiveToSelect byExtendingSelection:shouldExtend];
	
}//end LDrawGLView:wantsToSelectDirective:byExtendingSelection:


//========== LDrawGLView:willBeginDraggingHandle: ==============================
//
// Purpose:		The view is about to begin direct primitive geometry 
//				manipulation. We need to record the object state for undo. 
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView willBeginDraggingHandle:(LDrawDragHandle *)dragHandle
{
	LDrawDirective *primitive = [dragHandle target];
	
	[self preserveDirectiveState:primitive];
}


//========== LDrawGLView:writeDirectivesToPasteboard:asCopy: ===================
//
// Purpose:		Begin a drag-and-drop part insertion initiated in the directive 
//				view. 
//
// Notes:		The parts you see being dragged around are always copies of the 
//				originals. When we aren't actually doing a copy drag, we just 
//				hide the originals. At the end of the drag, we update the 
//				originals with the new dragged positions, unhide them, and 
//				discard the stuff on the pasteboard. This frees us from having 
//				to remember what step each dragged element belonged to. 
//
//==============================================================================
- (BOOL)         LDrawGLView:(LDrawGLView *)glView
 writeDirectivesToPasteboard:(NSPasteboard *)pasteboard
					  asCopy:(BOOL)copyFlag
{
	NSInteger       selectionCount      = [self->selectedDirectives count];
	NSMutableArray  *archivedParts      = [NSMutableArray array];
	id              currentDirective    = nil;
	NSData          *partData           = nil;
	NSInteger       counter             = 0;
	BOOL            success             = NO;
	
	// Archive selected moveable directives.
	for(counter = 0; counter < selectionCount; counter++)
	{
		currentDirective = [self->selectedDirectives objectAtIndex:counter];
		
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			partData	= [NSKeyedArchiver archivedDataWithRootObject:currentDirective];
			[archivedParts addObject:partData];
			
			if(copyFlag == NO)
			{
				// Not copying; we want the dragging instance to be the only 
				// visual manifestation of this part as it moves. 
				[currentDirective setHidden:YES];
			}
		}
	}
	
	// If copying, DESELECT all current directives as a visual indicator that 
	// the originals will stay put. 
	if(copyFlag == YES)
	{
		self->selectedDirectivesBeforeCopyDrag = [self->selectedDirectives copy];
		[self selectDirective:nil byExtendingSelection:YES];
	}
	
	// Set up pasteboard
	if([archivedParts count] > 0)
	{
		[pasteboard declareTypes:[NSArray arrayWithObject:LDrawDraggingPboardType] owner:self];
		[pasteboard setPropertyList:archivedParts forType:LDrawDraggingPboardType];
		
		success = YES;
	}

	[self->documentContents optimizeVertexes];
	
	return success;
	
}//end LDrawGLView:writeDirectivesToPasteboard:asCopy:


#pragma mark -
#pragma mark SPLIT VIEW
#pragma mark -

//**** NSSplitView ****
//========== splitView:canCollapseSubview: =====================================
//
// Purpose:		Collapsing is good if we don't like this multipane view deal.
//
//==============================================================================
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
	
}//end splitView:canCollapseSubview:


//**** NSSplitView ****
//========== splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex: ===
//
// Purpose:		Allow split views to collapse when their divider is 
//				double-clicked. 
//
//==============================================================================
- (BOOL)				splitView:(NSSplitView *)splitView
			shouldCollapseSubview:(NSView *)subview
	forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	return YES;
	
}//end splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex:


//**** NSSplitView ****
//========== splitView:constrainMinCoordinate:ofSubviewAt: =====================
//
// Purpose:		Allow the file Contents split view to collapse by giving it a 
//				minimum size. 
//
//==============================================================================
- (CGFloat)   splitView:(NSSplitView *)sender
 constrainMinCoordinate:(CGFloat)proposedMin
			ofSubviewAt:(NSInteger)offset
{
	CGFloat	actualMin	= 0.0;

	if(		sender == self->fileContentsSplitView
	   &&	offset == 0 )
	{
		actualMin = 100; // only return a collapsible minimum for the file contents
	}
	else
		actualMin = proposedMin;
	
	return actualMin;
	
}//end splitView:constrainMinCoordinate:ofSubviewAt:


//**** NSSplitView ****
//========== splitView:constrainMaxCoordinate:ofSubviewAt: =====================
//
// Purpose:		Allow the graphics detail view to collapse by defining a maximum 
//				extent for the the main graphic view. (It's counter-intuitive!)
//
//==============================================================================
- (CGFloat)   splitView:(NSSplitView *)sender
 constrainMaxCoordinate:(CGFloat)proposedMax
			ofSubviewAt:(NSInteger)offset
{
	CGFloat	actualMax	= 0.0;
	
	// In order to allow the detail column to collapse, we have to do something 
	// strange: specify a maximum position for the main graphic view pane. When 
	// the divider is dragged more than halfway beyond that maximum point, the 
	// detail column (view index 1) automatically collapses. Weird...
	if(		sender == self->viewportArranger
		&&	offset == 0 ) // yes, that offset is correct. This method is NEVER called with offset == 1.
	{
		actualMax = NSMaxX([sender frame]) - 80; // min size of 80 for the detail column
	}
	else
		actualMax = proposedMax;
	
	return actualMax;
	
}//end splitView:constrainMinCoordinate:ofSubviewAt:


//**** NSSplitView ****
//========== splitView:resizeSubviewsWithOldSize: ==============================
//
// Purpose:		Do yucky MANUAL resizing of the split view subviews.
//
//				We use this method to make sure that the size of the File 
//				Contents sidebar remains CONSTANT while the window is being 
//				resized. This is how all Apple applications with sidebars 
//				behave, and it is good. 
//
//==============================================================================
- (void) splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	// Make sure the width of the File Contents column remains constant during 
	// live window resize. 
	if(		sender == self->fileContentsSplitView
		&&	[[[sender window] contentView] inLiveResize] == YES )
	{
		NSView	*fileContentsPane	= [[sender subviews] objectAtIndex:0];
		NSView	*graphicPane		= [[sender subviews] objectAtIndex:1];
		NSSize	totalSize			= [sender frame].size;
		NSSize	graphicPaneSize		= [graphicPane frame].size;
		
		// The graphic pane absorbs ALL width changes.
		graphicPaneSize.width		=	totalSize.width 
									 -	[sender dividerThickness]
									 -	NSWidth([fileContentsPane frame]);
		
		[graphicPane setFrameSize:graphicPaneSize];
	}
	
	// If there are only two view columns configured, make sure the rightmost 
	// column remains constant during live window resize. This fit's Allen's 
	// Preferred Viewport Layout, in which there is a set of detail views on the 
	// right. People who prefer otherwise are up a creek.
	if(		sender == self->viewportArranger
		&&	[[[sender window] contentView] inLiveResize] == YES
		&&	[[sender subviews] count] == 2 )
	{
		NSView	*mainViewPane		= [[sender subviews] objectAtIndex:0];
		NSView	*detailViewsPane	= [[sender subviews] objectAtIndex:1];
		NSSize	totalSize			= [sender frame].size;
		NSSize	mainViewPaneSize	= [mainViewPane frame].size;
		
		// The graphic pane absorbs ALL width changes.
		mainViewPaneSize.width		=	totalSize.width 
									 -	[sender dividerThickness]
									 -	NSWidth([detailViewsPane frame]);
		
		[mainViewPane setFrameSize:mainViewPaneSize];
	}
	
	// Allow the split view to finish normal calculations. For the File Contents 
	// split view, this does height resizing for us. For all other split views, 
	// it just does behavior as normal. 
	[sender adjustSubviews];
	
}//end splitView:resizeSubviewsWithOldSize:


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -


//========== libraryReloaded: ==================================================
//
// Purpose:		The library has been reloaded.  We need to notify our entire
//				set of directives that the library parts might have changed.
//				The directives don't do this themselves to avoid overhead.
//
//==============================================================================
- (void)libraryReloaded:(NSNotification *)notification
{
	[LDrawUtilities unresolveLibraryParts:documentContents];
}//end libraryReloaded


//========== activeModelChanged: ===============================================
//
// Purpose:		The file we are displaying has changed its active model.
//
//==============================================================================
- (void)activeModelChanged:(NSNotification *)notification
{
	//[fileContentsOutline reloadData];
	
	//Update the models menu.
	[self addModelsToMenus];
	
	[self setLastSelectedPart:nil];
	
}//end activeModelDidChange:


//**** NSDrawer ****
//========== drawerWillOpen: ===================================================
//
// Purpose:		The Parts Browser drawer is opening.
//
//==============================================================================
- (void)drawerWillOpen:(NSNotification *)notification
{
	if([notification object] == self->partBrowserDrawer)
	{
		// We have a problem. When the main window is resized while the drawer is 
		// closed, the OpenGLView moves, but the OpenGL drawing region doesn't! To 
		// fix this problem, we need to adjust the drawer's size while it is open; 
		// that causes the OpenGL to synchronize itself properly. 
		//
		// This doesn't feel like the right solution to this problem, but it works.
		// Also listed are some other things I tried that didn't work.
		
		//Works, but animation is very chunky. (better than adjusting the window, though)
		NSSize contentSize = [partBrowserDrawer contentSize];
		
		contentSize.height += 1;
		[partBrowserDrawer setContentSize:contentSize];
		contentSize.height -= 1;
		[partBrowserDrawer setContentSize:contentSize];

		//Fails.
		//	[partsBrowser->partPreview reshape];
		
		//Uh-uh.
		//	NSView *contentView = [partBrowserDrawer contentView];
		//	[contentView resizeWithOldSuperviewSize:[partBrowserDrawer contentSize]];
		
		//Nope.
		//	[contentView resizeSubviewsWithOldSize:[partBrowserDrawer contentSize]];
		
		//Ferget it.
		//	[contentView setNeedsDisplay:YES];
		
		//Works, but ruins nice animation.
		//	if(drawerState == NSDrawerClosedState){
		//		NSWindow *parentWindow = [partBrowserDrawer parentWindow];
		//		NSRect parentFrame = [parentWindow frame];
		//		parentFrame.size.width += 1;
		//		[parentWindow setFrame:parentFrame display:NO];
		//		parentFrame.size.width -= 1;
		//		[parentWindow setFrame:parentFrame display:NO];
		//	}
	}
}//end drawerWillOpen:


//========== partChanged: ======================================================
//
// Purpose:		Somewhere, somehow, a part (or some other LDrawDirective) was 
//				changed. There is some possibility that our data could be stale 
//				now. 
//
//==============================================================================
- (void) partChanged:(NSNotification *)notification
{
	LDrawDirective *changedDirective = [notification object];
	
	if([[changedDirective ancestors] containsObject:[self documentContents]])
	{
		// Since a component of the file changed, mark the entire file as 
		// changed too. 
		if(changedDirective != [self documentContents])
		{
			[[self documentContents] noteNeedsDisplay];
		}

        // Ensure that even if the outline contents have changed (for instance a
        // container that inserts directives automatically) the original selection
        // is maintained
        [fileContentsOutline selectObjects:selectedDirectives];
        [fileContentsOutline reloadData];

		//Model menu needs to change if:
		//	*model list changes (in the file)
		//	*model name changes (in the model)
		if(		[[notification object] isKindOfClass:[LDrawFile class]]
			||	[[notification object] isKindOfClass:[LDrawModel class]])
		{
			[self addModelsToMenus];
		}
		// If step display attributes changed and we're in step display, we need 
		// to reset the step's viewing angle. 
		// Note: Unfortunately, this is called when the step's content array 
		//		 changes, and we have no way of distinguishing that case except 
		//		 for a cheesy hack ivar "lockViewingAngle".
		else if(	[[notification object] isKindOfClass:[LDrawStep class]]
				&&	[[[self documentContents] activeModel] stepDisplay] == YES
				&&	self->lockViewingAngle == NO)
		{
			[self updateViewingAngleToMatchStep];
		}
	}
}//end partChanged:


//========== syntaxColorChanged: ===============================================
//
// Purpose:		The preferences have been updated; we need to refresh our data 
//				display.
//
//==============================================================================
- (void) syntaxColorChanged:(NSNotification *)notification
{
	[fileContentsOutline reloadData];
	
}//end syntaxColorChanged:


//**** NSWindow ****
//========== windowDidBecomeMain: ==============================================
//
// Purpose:		The window has come to the foreground.
//
//==============================================================================
- (void) windowDidBecomeMain:(NSNotification *)aNotification
{
	[self updateInspector];

    [self populateLSynthModelMenus];

	[self addModelsToMenus];
	
}//end windowDidBecomeMain:


//**** NSWindow ****
//========== windowDidResize: ==================================================
//
// Purpose:		As the window changes size, we must record the new dimensions 
//				for autosaving purposes. 
//
// Notes:		Snow Leopard adds windowDidEndLiveResize which may be more 
//				appropriate. 
//
//==============================================================================
- (void) windowDidResize:(NSNotification *)notification
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSWindow		*window			= [notification object];
	
	// Don't do anything for the resizing that happens during awakeFromNib.
	if([window isVisible])
	{
		// In Leopard, we don't have any control over split view autosaving. It 
		// is saved every time the split view resizes. Since the split view size 
		// is dependent on the window size, we must save it at the same time. 
		// Otherwise, we could open a new document after resizing another one 
		// and the split views would not match the window size. 
	
		[userDefaults setObject:NSStringFromSize([window frame].size)
						 forKey:DOCUMENT_WINDOW_SIZE];
	}
	
}//end windowDidResize:


//**** NSWindow ****
//========== windowWillClose: ==================================================
//
// Purpose:		The window is about to close; let's save some state info.
//
//==============================================================================
- (void) windowWillClose:(NSNotification *)notification
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSWindow		*window			= [notification object];
	
	[userDefaults setInteger:[partBrowserDrawer state]	forKey:PART_BROWSER_DRAWER_STATE];
	
	//Un-inspect everything
	[[LDrawApplication sharedInspector] inspectObjects:nil];
	
	// Bug: if this document isn't the foremost window, this will botch up the 
	//		menu! Remember, we can close windows in the background. 
	if([window isMainWindow] == YES){
		[self clearModelMenus];
	}
	
	[self->bindingsController setContent:nil];
	
}//end windowWillClose:


#pragma mark -
#pragma mark MENUS
#pragma mark -

//========== validateMenuItem: =================================================
//
// Purpose:		Determines whether the given menu item should be available.
//				This method is called automatically each time a menu is opened.
//				We identify the menu item by its tag, which is defined in 
//				MacLDraw.h.
//
//==============================================================================
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger       tag             = [menuItem tag];
	NSArray         *selectedItems  = [self selectedObjects];
	LDrawPart       *selectedPart   = [self selectedPart];
	NSPasteboard    *pasteboard     = [NSPasteboard generalPasteboard];
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	BOOL            enable          = NO;

	switch(tag)
	{
        ////////////////////////////////////////
        //
        // File Menu
        //
        ////////////////////////////////////////

        case revealInFinderTag:
            enable = YES;
            if ([self fileURL] == nil) {
                enable = NO;
            }
            break;

		////////////////////////////////////////
		//
		// Edit Menu
		//
		////////////////////////////////////////

		case cutMenuTag:
		case copyMenuTag:
		case deleteMenuTag:
		case duplicateMenuTag:
		case rotatePositiveXTag:
		case rotateNegativeXTag:
		case rotatePositiveYTag:
		case rotateNegativeYTag:
		case rotatePositiveZTag:
		case rotateNegativeZTag:
			if([selectedItems count] > 0)
				enable = YES;
			break;
		
		case pasteMenuTag:
			if([[pasteboard types] containsObject:LDrawDirectivePboardType])
				enable = YES;
			break;
		
		
		////////////////////////////////////////
		//
		// Tools Menu
		//
		////////////////////////////////////////
		
		//The grid menus are always enabled, but this is a fine place to keep 
		// track of their state.
		case gridFineMenuTag:
			[menuItem setState:(self->gridMode == gridModeFine)];
			enable = YES;
			break;
		case gridMediumMenuTag:
			[menuItem setState:(self->gridMode == gridModeMedium)];
			enable = YES;
			break;
		case gridCoarseMenuTag:
			[menuItem setState:(self->gridMode == gridModeCoarse)];
			enable = YES;
			break;
			
			
		////////////////////////////////////////
		//
		// View Menu
		//
		////////////////////////////////////////
		
		case useSelectionForSpinCenterMenuTag:
			enable = ([selectedItems count] > 0);
			break;
		
		case resetSpinCenterMenuTag:
			enable = !V3EqualPoints(ZeroPoint3, [[self->documentContents activeModel] rotationCenter]);
			break;

		case stepDisplayMenuTag:
			[menuItem setState:([activeModel stepDisplay])];
			enable = YES;
			break;
			
		case nextStepMenuTag:
			enable = ([activeModel stepDisplay] == YES);
			break;
		case previousStepMenuTag:
			enable = ([activeModel stepDisplay] == YES);
			break;
		
		
		////////////////////////////////////////
		//
		// Piece Menu
		//
		////////////////////////////////////////
			
		case hidePieceMenuTag:
			enable = [self elementsAreSelectedOfVisibility:YES]; //there are visible parts to hide.
			break;
			
		case showPieceMenuTag:
			enable = [self elementsAreSelectedOfVisibility:NO]; //there are invisible parts to show.
			break;
			
		case snapToGridMenuTag:
			enable = (selectedPart != nil);
			break;
		
				
		////////////////////////////////////////
		//
		// Model Menu
		//
		////////////////////////////////////////
		
		case submodelReferenceMenuTag:
			//we can't insert a reference to the active model into itself.
			// That would be an inifinite loop.
			enable = (activeModel != [menuItem representedObject]);
			break;


        case lsynthSynthesizableMenuTag:
            // We can only add synthesizable parts below a step so ensure we've not selected a model
            enable = (selectedPart != nil) && (![selectedPart isKindOfClass:[LDrawMPDModel class]]);
            break;

        case lsynthConstraintMenuTag:
            // We can only insert a constraint into an LDrawLSynth part.
            // Ensure it (or a constraint) is selected
            enable = ([selectedPart isKindOfClass:[LDrawLSynth class]] ||
                      [[fileContentsOutline parentForItem:selectedPart] isKindOfClass:[LDrawLSynth class]]);
            break;

// TODO: add these in later
//        case lsynthSurroundINSIDEOUTSIDETag:
//            // INSIDE/OUTSIDE pairs can only surround constraints under a single LSynth part
//            // Valid selections are therefore an LSynth part, a single constraint or multiple
//            // contiguous constraints.
//            enable = NO;
//
//            // Single object selected, and is constraint or LSynth part
//            if ([selectedItems count] == 1) {
//                if ([[selectedItems objectAtIndex:0] isKindOfClass:[LDrawLSynth class]] ||
//                    [[fileContentsOutline parentForItem:[selectedItems objectAtIndex:0]] isKindOfClass:[LDrawLSynth class]]) {
//                    enable = YES;
//                }
//            }
//
//            // More than one thing selected.  Check they are direct siblings and contiguous
//            else {
//                NSMutableSet *parents = [[NSMutableSet alloc] init];
//                for (LDrawDirective *directive in selectedItems) {
//                    [parents addObject:[fileContentsOutline parent]];
//
//                }
//            }
//
//            break;
//
//        case lsynthInvertINSIDEOUTSIDETag:
//            enable = YES;
//            break;

        case lsynthInsertINSIDETag:
            enable = YES;
            break;

        case lsynthInsertOUTSIDETag:
            enable = YES;
            break;



		////////////////////////////////////////
		//
		// Something else.
		//
		////////////////////////////////////////
		
		default:
			//We are an NSDocument; it has its own validator to track certain 
			// items.
			enable = [super validateMenuItem:menuItem];
			break;
	}
	
	return enable;
	
}//end validateMenuItem:


//========== validateToolbarItem: ==============================================
//
// Purpose:		Toolbar validation: eye candy that probably slows everything to 
//				a crawl.
//
//==============================================================================
- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	LDrawPart		*selectedPart	= [self selectedPart];
//	NSArray			*selectedItems	= [self selectedObjects];
	NSString		*identifier		= [item itemIdentifier];
	BOOL			 enabled		= NO;
	
	//Must have something selected.
	//Must have a part selected.
	if([identifier isEqualToString:TOOLBAR_SNAP_TO_GRID]  )
	{
		if(selectedPart != nil)
			enabled = YES;
	}
	
	//We don't have special conditions for it; give it a pass.
	else
		enabled = YES;

	return enabled;
	
}//end validateToolbarItem:


#pragma mark -

//========== addModelsToMenus ==================================================
//
// Purpose:		Creates a menu used to switch the active model. A list of all 
//				the models in the document is inserted into the Models menu in 
//				the application's menu bar; the active model gets a check next 
//				to it.
//
//				We also regenerate the Insert Reference submenu (for inserting 
//				MPD submodels as parts in a different model). They require 
//				additional validation which occurs in validateMenuItem.
//
//==============================================================================
- (void) addModelsToMenus
{
	NSMenu          *mainMenu           = [NSApp mainMenu];
	NSMenu          *modelMenu          = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenu          *referenceMenu      = [[modelMenu itemWithTag:insertReferenceMenuTag] submenu];
	NSInteger       separatorIndex      = [modelMenu indexOfItemWithTag:modelsSeparatorMenuTag];
	NSMenuItem      *modelItem          = nil;
	NSMenuItem      *referenceItem      = nil;
	NSArray         *models             = [[self documentContents] submodels];
	LDrawMPDModel   *currentModel       = nil;
	NSString        *modelDescription   = nil;
	NSInteger       counter             = 0;
	
	[self clearModelMenus];
	
	//Create menu items for each model.
	for(counter = 0; counter < [models count]; counter++)
	{
		currentModel		= [models objectAtIndex:counter];
		modelDescription	= [currentModel browsingDescription];
		
		//
		// Active Model menu items
		//
		modelItem = [[[NSMenuItem alloc] init] autorelease];
		[modelItem setTitle:modelDescription];
		[modelItem setRepresentedObject:currentModel];
		[modelItem setTarget:self];
		[modelItem setAction:@selector(modelSelected:)];
		
		//
		// MPD reference menu items
		//
		referenceItem = [[[NSMenuItem alloc] init] autorelease];
		[referenceItem setTitle:modelDescription];
		[referenceItem setRepresentedObject:currentModel];
		//We set the same tag for all items in the reference menu.
		// Validation will distinguish them with their represented objects.
		[referenceItem setTag:submodelReferenceMenuTag];
		[referenceItem setTarget:self];
		[referenceItem setAction:@selector(addSubmodelReferenceClicked:)];
		
		//
		// Insert the new item at the end.
		//
		[modelMenu insertItem:modelItem atIndex:separatorIndex+counter+1];
		[referenceMenu addItem:referenceItem];
		[[addReferenceButton menu] addItem:[[referenceItem copy] autorelease]];
		[[self->submodelPopUpMenu menu] addItem:[[modelItem copy] autorelease]];
		
		//
		// Set (or re-set) the selected state
		//
		if([[self documentContents] activeModel] == currentModel)
		{
			[modelItem setState:NSOnState];
			[self->submodelPopUpMenu selectItemAtIndex:counter];
		}
	}
	
}//end addModelsToMenus


//========== clearModelMenus ===================================================
//
// Purpose:		Removes all submodels from the menus. There are two places we 
//				track the submodels: in the Model menu (for selecting the active 
//				model, and in the references submenu (for inserting submodels as 
//				parts).
//
//==============================================================================
- (void) clearModelMenus
{
	NSMenu      *mainMenu       = [NSApp mainMenu];
	NSMenu      *modelMenu      = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenu      *referenceMenu  = [[modelMenu itemWithTag:insertReferenceMenuTag] submenu];
	NSInteger   separatorIndex  = [modelMenu indexOfItemWithTag:modelsSeparatorMenuTag];
	NSInteger   counter         = 0;
	
	//Kill all model menu items.
	for(counter = [modelMenu numberOfItems]-1; counter > separatorIndex; counter--)
		[modelMenu removeItemAtIndex: counter];
	
	for(counter = [referenceMenu numberOfItems]-1; counter >= 0; counter--)
		[referenceMenu removeItemAtIndex:counter];
		
	for(counter = [addReferenceButton numberOfItems]-1; counter > 0; counter--)
		[self->addReferenceButton removeItemAtIndex:counter];
		
	[self->submodelPopUpMenu removeAllItems];
	
}//end clearModelMenus


#pragma mark -
#pragma mark VIEWPORT MANAGEMENT
#pragma mark -

//========== all3DViewports ====================================================
//
// Purpose:		Returns an array of all the LDrawGLViews managed by the 
//				document and displaying the document contents. 
//
//==============================================================================
- (NSArray *) all3DViewports
{
	NSArray         *scrollViews        = [self->viewportArranger allViewports];
	NSMutableArray  *viewports          = [NSMutableArray array];
	NSScrollView    *currentScrollView  = nil;
	LDrawGLView     *currentGLView      = nil;
	NSUInteger      counter             = 0;

	// Count up all the GL views in each column
	for(counter = 0; counter < [scrollViews count]; counter++)
	{
		currentScrollView   = [scrollViews objectAtIndex:counter];
		currentGLView       = [currentScrollView documentView];
		
		[viewports addObject:currentGLView];
	}
	
	return viewports;
	
}//end all3DViewports


//========== connectLDrawGLView: ===============================================
//
// Purpose:		Associates the given LDrawGLView with this document.
//
//==============================================================================
- (void) connectLDrawGLView:(LDrawGLView *)glView
{
	[glView setDelegate:self];
	
	[glView setTarget:self];
	[glView setForwardAction:@selector(advanceOneStep:)];
	[glView setBackAction:@selector(backOneStep:)];
	[glView setNudgeAction:@selector(nudge:)];
	
	[glView setGridSpacingMode:[self gridSpacingMode]];
	
}//end connectLDrawGLView:


//========== main3DViewport ====================================================
//
// Purpose:		This is the viewport anointed "main", where we reflect things 
//				like the current step orientation. 
//
//==============================================================================
- (LDrawGLView *) main3DViewport
{
	NSArray     *allViewports       = [self all3DViewports];
	CGFloat     largestArea         = 0.0;
	CGFloat     currentArea         = 0.0;
	NSSize      currentSize         = NSZeroSize;
	LDrawGLView *largestViewport    = nil;
	
	// Find the largest viewport. We'll assume that's the one the user wants to 
	// be the main one. 
	for(LDrawGLView *currentViewport in allViewports)
	{
		currentSize = [[currentViewport enclosingScrollView] contentSize];
		currentArea = currentSize.width * currentSize.height;
		
		if(currentArea > largestArea)
		{
			largestArea     = currentArea;
			largestViewport = currentViewport;
		}
	}
		
	return largestViewport;
	
}//end main3DViewport


//========== updateViewportAutosaveNamesAndRestore: ============================
//
// Purpose:		Sets the autosave names for all the viewports. Call this after 
//				the viewport configuration changes. 
//
// Parameters:	shouldRestore	- pass YES to also read settings from prefs.
//
//==============================================================================
- (void) updateViewportAutosaveNamesAndRestore:(BOOL)shouldRestore
{
	NSArray             *viewports          = [self all3DViewports];
	LDrawGLView         *glView             = nil;
	NSUInteger          viewportCount       = [viewports count];
	NSUInteger          counter             = 0;
	
	// Recreate whatever was in use last
	for(counter = 0; counter < viewportCount; counter++)
	{
		glView          = [viewports objectAtIndex:counter];
		
		[glView setAutosaveName:[NSString stringWithFormat:@"fileGraphicView_%ld", (long)counter]];
		[glView setAutosaveName:[NSString stringWithFormat:@"fileGraphicView_%ld", (long)counter]];
		
		if(shouldRestore == YES)
			[glView restoreConfiguration];
	}

}//end updateViewportAutosaveNamesAndRestore:


#pragma mark -

//========== viewportArranger:didAddViewport: ==================================
//
// Purpose:		A new viewport has been added. Time to update the world!
//
// Parameters:	sourceView	- the view the newViewport is being split from. Will 
//				be nil if this is called during restoring the viewports from 
//				preferences. 
//
//==============================================================================
- (void) viewportArranger:(ViewportArranger *)viewportArrangerIn
		   didAddViewport:(ExtendedScrollView *)newViewport
		   sourceViewport:(ExtendedScrollView *)sourceView
{
	LDrawGLView *glView         = nil;
	LDrawGLView *sourceGLView   = nil;
	
	glView = [[[LDrawGLView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)
									 pixelFormat:[NSOpenGLView defaultPixelFormat]] autorelease];
	[self connectLDrawGLView:glView];
	
	// Tie them together
	[newViewport setDocumentView:glView];
	[newViewport centerDocumentView];
	[newViewport setPreservesScrollCenterDuringLiveResize:YES];
	[newViewport setStoresScrollCenterAsFraction:YES];

	[self loadDataIntoDocumentUI];
	
	// This doesn't work during viewport restoration. Didn't attempt to debug 
	// it; just moved the code to -windowControllerDidLoadNib: 
//	[glView scrollCenterToPoint:NSMakePoint( NSMidX([glView frame]), NSMidY([glView frame]) )];
	
	// Opening zoom level
	// Note: The zoom level when first opening the document is set to default 
	//		 values. But we aren't able to determine which views get what values 
	//		 until *all* the views have been fully restored. So we can't do it 
	//		 here. 
	if(sourceView != nil)
	{
		// Make the new view look like the old one.
		sourceGLView = [sourceView documentView];
		
		[glView setViewOrientation:[sourceGLView viewOrientation]];
		[glView setProjectionMode:[sourceGLView projectionMode]];
		[glView setZoomPercentage:[sourceGLView zoomPercentage]];
	}
	
	[self updateViewportAutosaveNamesAndRestore:NO];


}//end viewportArranger:didAddViewport:


//========== viewportArranger:willRemoveViewports: =============================
//
// Purpose:		3D viewports are about to be removed (but they haven't been 
//				quite yet). 
//
//==============================================================================
- (void) viewportArranger:(ViewportArranger *)viewportArranger
	  willRemoveViewports:(NSSet *)removingViewports;
{
	NSScrollView        *mostRecentViewport = [self->mostRecentLDrawView enclosingScrollView];
	NSArray             *allViewports       = [self->viewportArranger allViewports];
	ExtendedScrollView  *currentViewport    = nil;
	
	// If the current most-recent viewport is being removed, we need to make a 
	// new viewport "most-recent." That's because we have bindings observers 
	// watching the most recent view, and we'll crash if they're still observing 
	// when the view deallocates. 
	if([removingViewports containsObject:mostRecentViewport])
	{
		// Make the first viewport not being removed the most recent.
		for(currentViewport in allViewports)
		{
			if([removingViewports containsObject:currentViewport] == NO)
			{
				[self setMostRecentLDrawView:[currentViewport documentView]];
				break;
			}
		}
	}
	
}//end viewportArranger:willRemoveViewports:


//========== viewportArrangerDidRemoveViewports: ===============================
//
// Purpose:		A viewport (or maybe a whole bunch of them) has been removed. We 
//				don't get told which one, but that's because we don't need to 
//				know. 
//
//==============================================================================
- (void) viewportArrangerDidRemoveViewports:(ViewportArranger *)viewportArranger
{
	[self updateViewportAutosaveNamesAndRestore:NO];
	
}//end viewportArrangerDidRemoveViewports:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== addModel: =========================================================
//
// Purpose:		Add newModel to the current file.
//
// Notes:		Duplicate model names are verboten if renameModels is true, so 
//				if newModel's name matches an existing model name, an approriate 
//				"copy X" will be appended automatically. 
//
//				There is a bug here in that if several models having references 
//				to one another are pasted at once into a file with name 
//				conflicts, the file reference structure of the pasted models 
//				will point to the wrong names once this method does its renaming 
//				magic. To this I respond, "don't do that."
//
//==============================================================================
- (void) addModel:(LDrawMPDModel *)newModel atIndex:(NSInteger)insertAtIndex preventNameCollisions:(BOOL)renameModels
{
	NSString        *proposedModelName  = [newModel modelName];
	NSUndoManager   *undoManager        = [self undoManager];
	NSInteger       rowForItem          = 0;
	
	// Derive a non-duplicating name for this new model
	if(renameModels == YES)
	{
		while([[self documentContents] modelWithName:proposedModelName] != nil)
		{
			proposedModelName = [StringUtilities nextCopyPathForFilePath:proposedModelName];
		}
		[newModel setModelName:proposedModelName];
	}
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newModel toParent:[self documentContents]];
	}
	else
	{
		[self addDirective:newModel toParent:[self documentContents] atIndex:insertAtIndex];
	}
	
	// Select the new model.
	[fileContentsOutline expandItem:newModel];
	rowForItem = [fileContentsOutline rowForItem:newModel];
	[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:rowForItem]
					 byExtendingSelection:NO];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddModel", nil)];
	
}//end addModel:


//========== addStep:parent:index: =============================================
//
// Purpose:		Adds newStep to the currently-displayed model. If you specify an 
//				index, it will be inserted there. Otherwise, the step appears at 
//				the end of the list. 
//
//==============================================================================
- (void) addStep:(LDrawStep *)newStep parent:(LDrawMPDModel*)selectedModel index:(NSInteger)insertAtIndex
{
	NSUndoManager	*undoManager	= [self undoManager];
	
	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newStep toParent:selectedModel];
	}
	else
	{
		[self addDirective:newStep toParent:selectedModel atIndex:insertAtIndex];
	}
	
	// Select the new step.
	[fileContentsOutline expandItem:selectedModel];
	[fileContentsOutline expandItem:newStep];
	NSInteger rowForItem = [fileContentsOutline rowForItem:newStep];
	[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:rowForItem]
					 byExtendingSelection:NO];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddStep", nil)];
	
}//end addStep:


//========== addPartNamed: =====================================================
//
// Purpose:		Adds a part with the given name to the current step in the 
//				currently-displayed model.
//
//==============================================================================
- (void) addPartNamed:(NSString *)partName
{
	LDrawPart           *newPart        = [[[LDrawPart alloc] init] autorelease];
	NSUndoManager       *undoManager    = [self undoManager];
	LDrawColor          *selectedColor  = [[LDrawColorPanel sharedColorPanel] LDrawColor];
	TransformComponents transformation  = IdentityComponents;
	
	//We got a part; let's add it!
	if(partName != nil)
	{
		//Set up the part attributes
		[newPart setLDrawColor:selectedColor];
		[newPart setDisplayName:partName];
		
		if(self->lastSelectedPart != nil)
		{
			// Collect the transformation from the previous part and apply it to 
			// the new one. 
			transformation = [lastSelectedPart transformComponents];
			[newPart setTransformComponents:transformation];
		}
		
		[newPart optimizeOpenGL];
		
		[self addStepComponent:newPart parent:nil index:NSNotFound];
		
		[undoManager setActionName:NSLocalizedString(@"UndoAddPart", nil)];
		[[self documentContents] noteNeedsDisplay];
	}
}//end addPartNamed:


//========== addStepComponent: =================================================
//
// Purpose:		Adds newDirective to the bottom of the current step, or after 
//				the currently-selected element in the step if there is one.
//
// Parameters:	newDirective: a directive which can be added to a step. These 
//						include parts, geometric primitives, and comments.
//				parent - requested target step; if nil, uses the default behavior
//				insertAtIndex - index in parent.
//
//==============================================================================
- (void) addStepComponent:(LDrawDirective *)newDirective
				   parent:(LDrawContainer*)parent
					index:(NSInteger)insertAtIndex
{
	LDrawContainer	*targetContainer	= parent;
	LDrawMPDModel	*selectedModel		= [self selectedModel];
	NSInteger		rowForItem			= 0;

	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// We may have the model itself selected, in which case we will add this new 
	// element to the very bottom of the model.
	if(targetContainer == nil)
	{
		LDrawContainer *selectedContainer = [self selectedContainer];
		
		if(		selectedContainer != nil
		   &&	[selectedContainer isKindOfClass:[LDrawFile class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawModel class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawStep class]] == NO
           &&   [selectedContainer acceptsDroppedDirective:newDirective] == YES)
		{
			// If we have an "interesting" container selected -- like a texture 
			// -- that accepts the dropped directive add directives to it instead
			// of at the end of the model. The theory here is that these special
			// containers are kind of their  own little world, and as long as you
			// have one selected, you should continue working within it.
			targetContainer = selectedContainer;
		}
		else
		{
			targetContainer = [selectedModel visibleStep];
		}
	}
		
	if(insertAtIndex == NSNotFound)
	{
		// At a user's request, all new components are inserted in the last 
		// visible step. That's how duplicating drag-and-drops work anyway. 
		[self addDirective:newDirective toParent:targetContainer ];
	}
	else
	{
		[self addDirective:newDirective toParent:targetContainer atIndex:insertAtIndex ];
	}

	// Show the new element.
	[fileContentsOutline expandItem:selectedModel];
	[fileContentsOutline expandItem:targetContainer];
	
	// Select it too.
	rowForItem = [fileContentsOutline rowForItem:newDirective];
	[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:rowForItem]
					 byExtendingSelection:NO];
					 
	// Allow us to immediately use the keyboard to move the new part.
	[[self foremostWindow] makeFirstResponder:mostRecentLDrawView];
	
}//end addStepComponent:


#pragma mark -

//========== canDeleteDirective:displayErrors: =================================
//
// Purpose:		Tests whether the specified directive should be allowed to be 
//				deleted. If errorFlag is YES, also displays an appropriate error 
//				sheet explaining the reasons why directive cannot be deleted.
//
//==============================================================================
- (BOOL) canDeleteDirective:(LDrawDirective *)directive
			  displayErrors:(BOOL)errorFlag
{
	LDrawContainer	*parentDirective	= [directive enclosingDirective];
	BOOL			 isLastDirective	= ([[parentDirective subdirectives] count] <= 1);
	NSAlert			*alert				= [[NSAlert alloc] init];
	NSString		*message			= nil;
	NSString		*informative		= nil;
	BOOL			 canDelete			= YES;
	
	if([directive isKindOfClass:[LDrawModel class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastModelInformative", nil);
	}
	else if([directive isKindOfClass:[LDrawStep class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastStepInformative", nil);
	}
	
	if(canDelete == NO && errorFlag == YES)
	{
		message = NSLocalizedString(@"DeleteDirectiveError", nil);
		message = [NSString stringWithFormat:message, [directive browsingDescription]];
		
		[alert setMessageText:message];
		[alert setInformativeText:informative];
		
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		[alert beginSheetModalForWindow:[self windowForSheet]
						  modalDelegate:nil
						 didEndSelector:NULL
							contextInfo:NULL ];
		
	}
	
	[alert release];
	
	return canDelete;
	
}//end canDeleteDirective:displayErrors:


//========== elementsAreSelectedOfVisibility: ==================================
//
// Purpose:		Returns YES if there are elements selected which have the 
//				requested visibility. 
//
//==============================================================================
- (BOOL) elementsAreSelectedOfVisibility:(BOOL)visibleFlag
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	BOOL        invisibleSelected   = NO;
	BOOL        visibleSelected     = NO;
	
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject respondsToSelector:@selector(isHidden)])
		{
			invisibleSelected	= invisibleSelected || [currentObject isHidden];
			visibleSelected		= visibleSelected   || ([currentObject isHidden] == NO);
		}
	}
	
	if(visibleFlag == YES)
		return visibleSelected;
	else
		return invisibleSelected;
		
}//end elementsAreSelectedOfVisibility:


//========== formatDirective:withStringRepresentation: =========================
//
// Purpose:		Applies syntax coloring to the specified directive, which will 
//				be displayed with the text representation.
//
//==============================================================================
- (NSAttributedString *) formatDirective:(LDrawDirective *)item
				withStringRepresentation:(NSString *)representation
{
	NSUserDefaults			*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSString				*colorKey		= nil; //preference key for object's syntax color.
	NSColor					*syntaxColor	= nil;
	NSNumber				*obliqueness	= [NSNumber numberWithDouble:0.0]; //italicize?
	NSAttributedString		*styledString	= nil;
	NSMutableDictionary		*attributes		= [NSMutableDictionary dictionary];
	NSMutableParagraphStyle	*paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	//We want the text to appear nicely truncated in its column.
	// By setting the column to wrap and then setting the paragraph wrapping to 
	// truncate, we achieve the desired effect.
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	
	//Find the specified syntax color for the directive.
	if([item isKindOfClass:[LDrawModel class]])
		colorKey = SYNTAX_COLOR_MODELS_KEY;
	
	else if([item isKindOfClass:[LDrawStep class]])
		colorKey = SYNTAX_COLOR_STEPS_KEY;
	
	else if([item isKindOfClass:[LDrawComment class]])
		colorKey = SYNTAX_COLOR_COMMENTS_KEY;
		
	else if([item isKindOfClass:[LDrawPart class]])
		colorKey = SYNTAX_COLOR_PARTS_KEY;

    else if ([item isKindOfClass:[LDrawLSynth class]] ||
             [item isKindOfClass:[LDrawLSynthDirective class]])
        colorKey = SYNTAX_COLOR_PARTS_KEY;

	else if([item isKindOfClass:[LDrawLine				class]] ||
	        [item isKindOfClass:[LDrawTriangle			class]] ||
			[item isKindOfClass:[LDrawQuadrilateral		class]] ||
			[item isKindOfClass:[LDrawConditionalLine	class]]    )
		colorKey = SYNTAX_COLOR_PRIMITIVES_KEY;
	
	else if([item isKindOfClass:[LDrawColor class]])
		colorKey = SYNTAX_COLOR_COLORS_KEY;
	
	else
		colorKey = SYNTAX_COLOR_UNKNOWN_KEY;
	
	//We have the syntax coloring we want.
	syntaxColor = [userDefaults colorForKey:colorKey];
	
	if([item respondsToSelector:@selector(isHidden)])
		if([(id)item isHidden])
			obliqueness = [NSNumber numberWithDouble:0.5];
	
	
	//Assemble the attributes dictionary.
	[attributes setObject:paragraphStyle	forKey:NSParagraphStyleAttributeName];
	[attributes setObject:syntaxColor		forKey:NSForegroundColorAttributeName];
	[attributes setObject:obliqueness		forKey:NSObliquenessAttributeName];
	
	//Create the attributed string.
    styledString = [[NSAttributedString alloc]
							initWithString:representation
								attributes:attributes ];
	
	//Release stuff we created or copied.
	[paragraphStyle release];
	
	return [styledString autorelease];

}//end formatDirective:withStringRepresentation:


//========== loadDataIntoDocumentUI ============================================
//
// Purpose:		Informs the document's user interface widgets about the contents 
//				of the document they are supposed to be representing.
//
//				There are two occasions when this method must be called:
//					1) immediately after the document UI has first been loaded
//						(in windowControllerDidLoadNib:)
//					2) when reverting the document.
//						(in revertToSavedFromFile:ofType:)
//
//==============================================================================
- (void) loadDataIntoDocumentUI
{
	NSArray     *graphicViews   = [self all3DViewports];
	NSUInteger  counter         = 0;
	
	for(counter = 0; counter < [graphicViews count]; counter++)
	{
		[[graphicViews objectAtIndex:counter] setLDrawDirective:[self documentContents]];
	}
	[self->fileContentsOutline	reloadData];
	
	[self addModelsToMenus];

}//end loadDataIntoDocumentUI


//========== populateLSynthModelMenus ==========================================
//
// Purpose:		Populate the LSynth Model menus. We guard against creating
//              more than one menu.
//
//==============================================================================
- (void) populateLSynthModelMenus
{
    LDrawApplication *appDelegate    = [NSApp delegate];
    NSMenu           *mainMenu       = [NSApp mainMenu];
    NSMenu           *modelMenu      = [[mainMenu itemWithTag:modelsMenuTag] submenu];

    // We recreate this menu each time we're called since the
    // target potentially changes (different window/document)
    // TODO: make this once per document?

    if ([modelMenu itemWithTag:lsynthMenuTag]) {
        [modelMenu removeItemAtIndex:[modelMenu indexOfItemWithTag:lsynthMenuTag]];
    }

    if (! [modelMenu itemWithTag:lsynthMenuTag])
	{
        NSMenu    *lsynthMenu     = [[[NSMenu alloc] init] autorelease];

        // A declarative encoding of our LSynth menus
        // We process this, along with associated LSynthConfiguration data to generate our Model LSynth menu
        NSArray *menus = [NSArray arrayWithObjects:
                          [NSDictionary dictionaryWithObjects:
                           [NSArray arrayWithObjects:@"Add Parts", @"getParts", @"title", @"insertSynthesizableDirective:", [NSNumber numberWithInt:lsynthPartMenuTag], nil]
                                  forKeys:
                                          [NSArray arrayWithObjects:@"title", @"getter", @"entry_key", @"action", @"tag", nil]],
                          [NSDictionary dictionaryWithObjects:
                           [NSArray arrayWithObjects:@"Add Hose", @"getHoseTypes", @"title", @"insertSynthesizableDirective:", [NSNumber numberWithInt:lsynthSynthesizableMenuTag], nil]
                                                      forKeys:
                           [NSArray arrayWithObjects:@"title", @"getter", @"entry_key", @"action", @"tag", nil]],
                          [NSDictionary dictionaryWithObjects:
                           [NSArray arrayWithObjects:@"Add Hose Constraint", @"getHoseConstraints", @"description", @"InsertLSynthConstraint:", [NSNumber numberWithInt:lsynthConstraintMenuTag], nil]
                                                      forKeys:
                           [NSArray arrayWithObjects:@"title", @"getter", @"entry_key", @"action", @"tag", nil]],
                          [NSDictionary dictionaryWithObjects:
                           [NSArray arrayWithObjects:@"Add Band", @"getBandTypes", @"title", @"insertSynthesizableDirective:", [NSNumber numberWithInt:lsynthSynthesizableMenuTag], nil]
                                                      forKeys:
                           [NSArray arrayWithObjects:@"title", @"getter", @"entry_key", @"action", @"tag", nil]],
                          [NSDictionary dictionaryWithObjects:
                           [NSArray arrayWithObjects:@"Add Band Constraint", @"getBandConstraints", @"description", @"InsertLSynthConstraint:", [NSNumber numberWithInt:lsynthConstraintMenuTag], nil]
                                                      forKeys:
                           [NSArray arrayWithObjects:@"title", @"getter", @"entry_key", @"action", @"tag", nil]],

                          nil];

        for (NSDictionary *menuSpec in menus) {
            NSMenu *menu = [[[NSMenu alloc] init] autorelease]; // one for each of part, constraint, hose, band etc.

            // Retrieve the appropriate data for each menu entry, based on the getter given above
            // See e.g. http://stackoverflow.com/questions/2175818/add-method-selector-into-a-dictionary
            // for an alternative that could avoid the use of NSSelectorFromString by storing the selectors
            // directly in a dictionary.

            for (NSDictionary *entry in [[appDelegate lsynthConfiguration] performSelector:NSSelectorFromString([menuSpec objectForKey:@"getter"])]) {
                NSMenuItem *entryMenuItem = [[[NSMenuItem alloc] init] autorelease];
                [entryMenuItem setTitle:[entry objectForKey:[menuSpec objectForKey:@"entry_key"]]];
                [entryMenuItem setRepresentedObject:entry];
                [entryMenuItem setAction:NSSelectorFromString([menuSpec objectForKey:@"action"])];
                [entryMenuItem setTarget:self];
                // Should these be unique, i.e. add a loop index to a base value? Don't need them to be, yet.
                [entryMenuItem setTag:[[menuSpec objectForKey:@"tag"] integerValue]];
                [menu addItem:entryMenuItem];
            }
            NSMenuItem *subMenu = [[[NSMenuItem alloc] init] autorelease];
            [subMenu setTitle:[menuSpec objectForKey:@"title"]];
            [subMenu setSubmenu:menu];

            [menu setAutoenablesItems:YES]; // TODO: set it so that LSynth submenus are validated.
            //[menu setDelegate:self];

            [lsynthMenu addItem:subMenu]; // a menuItem
        }

        //
        // Add INSIDE/OUTSIDE menus
        //

        // Main menu and menuItem

        NSMenu *insideOutsideMenu = [[[NSMenu alloc] init] autorelease];
        NSMenuItem *insideOutsideMenuItem = [[[NSMenuItem alloc] init] autorelease];
        [insideOutsideMenuItem setTitle:@"Inside/Outside"];
        [lsynthMenu setSubmenu:insideOutsideMenu forItem:insideOutsideMenuItem];
        [lsynthMenu addItem:insideOutsideMenuItem];

        // Menu entries

// TODO: Add these in later
//        NSMenuItem *surroundSelectionItem = [[[NSMenuItem alloc] init] autorelease];
//        [surroundSelectionItem setTitle:@"Surround Selection"];
//        [surroundSelectionItem setTarget:self];
//        [surroundSelectionItem setAction:@selector(surroundLSynthConstraints:)];
//        [surroundSelectionItem setTag:lsynthSurroundINSIDEOUTSIDETag];
//        [insideOutsideMenu addItem:surroundSelectionItem];
//
//        NSMenuItem *invertSelectionItem = [[[NSMenuItem alloc] init] autorelease];
//        [invertSelectionItem setTitle:@"Invert Selection"];
//        [invertSelectionItem setTarget:self];
//        [invertSelectionItem setAction:@selector(invertLSynthConstraintSelection:)];
//        [invertSelectionItem setTag:lsynthInvertINSIDEOUTSIDETag];
//        [insideOutsideMenu addItem:invertSelectionItem];

        NSMenuItem *addInsideItem = [[[NSMenuItem alloc] init] autorelease];
        [addInsideItem setTitle:@"Insert INSIDE"];
        [addInsideItem setTarget:self];
        [addInsideItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
        [addInsideItem setTag:lsynthInsertINSIDETag];
        [insideOutsideMenu addItem:addInsideItem];

        NSMenuItem *addOutsideItem = [[[NSMenuItem alloc] init] autorelease];
        [addOutsideItem setTitle:@"Insert OUTSIDE"];
        [addOutsideItem setTarget:self];
        [addOutsideItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
        [addOutsideItem setTag:lsynthInsertOUTSIDETag];
        [insideOutsideMenu addItem:addOutsideItem];

        NSMenuItem *addCrossItem = [[[NSMenuItem alloc] init] autorelease];
        [addCrossItem setTitle:@"Insert CROSS"];
        [addCrossItem setTarget:self];
        [addCrossItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
        [addCrossItem setTag:lsynthInsertCROSSTag];
        [insideOutsideMenu addItem:addCrossItem];

        // Add in the main LSynth menu to the Model menu
        NSMenuItem *lsynthSubMenu = [[[NSMenuItem alloc] init] autorelease];
        [lsynthSubMenu setTitle:@"LSynth"];
        [lsynthSubMenu setTag:lsynthMenuTag];
        [modelMenu setSubmenu:lsynthMenu forItem:lsynthSubMenu];
        // Add it at the top.  Should it go at the bottom?  It's my favourite
        // feature but may not be everyone's
        [modelMenu insertItem:lsynthSubMenu atIndex:0];
    }
}//end populateLSynthModelMenus


//========== selectedContainer =================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawContainer *) selectedContainer
{
	NSInteger		selectedRow 		= [fileContentsOutline selectedRow];
	id				selectedItem		= [fileContentsOutline itemAtRow:selectedRow];
	LDrawContainer	*selectedContainer	= nil;
	
	// Hack alert!
	// If we are doing a copy-drag operation, remember the original selection 
	// and use it. (We can't use the current selection during copy drag because 
	// we clear it when the drag begins.)
	if([self->selectedDirectivesBeforeCopyDrag count] > 0)
		selectedItem = [selectedDirectivesBeforeCopyDrag objectAtIndex:0];
	
	// Find selected container
	if([selectedItem isKindOfClass:[LDrawContainer class]])
		selectedContainer = selectedItem;
	else
		selectedContainer = [selectedItem enclosingDirective];
	
	return selectedContainer;
	
}//end selectedContainer


//========== selectedObjects ===================================================
//
// Purpose:		Returns the LDraw objects currently selected in the file.
//
//==============================================================================
- (NSArray *) selectedObjects
{
	NSIndexSet      *selectedIndexes    = [fileContentsOutline selectedRowIndexes];
	NSUInteger      currentIndex        = [selectedIndexes firstIndex];
	NSMutableArray  *selectedObjects    = [NSMutableArray arrayWithCapacity:[selectedIndexes count]];
	id              currentObject       = nil;
	
	//Search through all the indexes and get the objects associated with them.
	while(currentIndex != NSNotFound){
	
		currentObject = [fileContentsOutline itemAtRow:currentIndex];
		[selectedObjects addObject:currentObject];
		
		currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
	}
	
	return selectedObjects;
	
}//end selectedObjects


//========== selectedModel =====================================================
//
// Purpose:		Returns the model that encloses the current selection, or nil 
//				if there is no selection.
//
// Note:		If you intend to use this method's output to figure out which 
//				model to display, then you need to convert a nil case into the 
//				active model.
//
//==============================================================================
- (LDrawMPDModel *) selectedModel
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return (LDrawMPDModel*)[selectedItem enclosingModel];

}//end selectedModel


//========== selectedModel =====================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or  
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawStep *) selectedStep
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return [selectedItem enclosingStep];

}//end selectedStep


//========== selectedStepComponent =============================================
//
// Purpose:		Returns the drawable LDraw element that is currently selected.
//				(e.g., Part, Quadrilateral, Triangle, etc.)
//
//				Returns nil if the selection is not one of these atomic LDraw
//				commands.
//
//==============================================================================
- (LDrawDirective *) selectedStepComponent
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	//If a model is selected, a step can't be!
	if(		selectedItem == nil
       ||	[selectedItem isKindOfClass:[LDrawFile class]]
	   ||	[selectedItem isKindOfClass:[LDrawModel class]]
	   ||	[selectedItem isKindOfClass:[LDrawStep class]] )
		return nil;
	
	else { //it's not a file, model, or step; whatever it is, it's what we are 
			// looking for.
		return selectedItem;
	}
}//end selectedStep


//========== selectedPart ======================================================
//
// Purpose:		Returns the first part that is currently selected, or nil if no 
//				part is selected.
//
//==============================================================================
- (LDrawPart *) selectedPart
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	
	while(counter < [selectedObjects count])
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject isKindOfClass:[LDrawPart class]])
			break;
		else
			counter++;
	}
	
	//Either we just found one, on we found nothing.
	return currentObject;
}//end 


//========== updateInspector ===================================================
//
// Purpose:		Updates the Inspector to display the currently-selected objects.
//				This should be called in response to any potentially state-
//				changing actions on a directive.
//
//==============================================================================
- (void) updateInspector
{
	NSArray *selectedObjects = [self selectedObjects];
	
	[[LDrawApplication sharedInspector] inspectObjects:selectedObjects];
	[[LDrawColorPanel sharedColorPanel] updateSelectionWithObjects:selectedObjects];
	
}//end updateInspector


//========== updateViewingAngleToMatchStep =====================================
//
// Purpose:		Sets the viewing angle of the main viewport to the angle 
//				requested by the current step for Step Display mode. 
//
//==============================================================================
- (void) updateViewingAngleToMatchStep
{
	LDrawMPDModel       *activeModel        = [[self documentContents] activeModel];
	NSInteger           requestedStep       = [activeModel maximumStepIndexForStepDisplay];
	Tuple3              viewingAngle        = [activeModel rotationAngleForStepAtIndex:requestedStep];
	ViewOrientationT    viewOrientation     = [LDrawUtilities viewOrientationForAngle:viewingAngle];
	LDrawGLView         *affectedViewport   = [self main3DViewport];
	
	// Set the Viewing angle
	if(viewOrientation != ViewOrientation3D)
		[affectedViewport setProjectionMode:ProjectionModeOrthographic];
	else
		[affectedViewport setProjectionMode:ProjectionModePerspective];
	
	[affectedViewport setViewOrientation:viewOrientation];
	[affectedViewport setViewingAngle:viewingAngle];
	
}//end updateViewingAngleToMatchStep


//========== writeDirectives:toPasteboard: =====================================
//
// Purpose:		Writes objects to the given pasteboard, ensuring that each 
//				directive is written only once.
//
//				This method places two arrays on the pasteboard for these types:
//				* LDrawDirectivePboardType: array of LDrawDirectives converted 
//							to NSData objects.
//				* NSStringPboardType: array of strings representing the objects 
//							in the format written to an LDraw file.
//
// Notes:		This method will clear the contents of the pasteboard.
//
//==============================================================================
- (void) writeDirectives:(NSArray *)directives
			toPasteboard:(NSPasteboard *)pasteboard
{
	//Pasteboard types.
	NSArray			*pboardTypes		= [NSArray arrayWithObjects:
												LDrawDirectivePboardType, //Bricksmith's preferred type.
												NSStringPboardType, //representation for other applications.
												nil ];
	LDrawDirective	*currentObject		= nil;
	NSMutableArray	*objectsToCopy		= [NSMutableArray array];
	//list of containers we've already archived. We don't want to re-archive any 
	// of their children.
	NSMutableArray	*archivedContainers	= [NSMutableArray array];
	NSData			*data				= nil;
	NSString		*string				= nil;
	//list of LDrawDirectives which have been converted to data.
	NSMutableArray	*archivedObjects	= [NSMutableArray array];
	//list of LDrawDirectives which have been converted to strings.
	NSMutableString	*stringedObjects	= [NSMutableString stringWithCapacity:256];
	NSInteger		counter				= 0;
	
	//Write out the selected objects, but only once for each object. 
	// Don't write out items whose parent is selected; the parent will 
	// automatically write its children.
	for(counter = 0; counter < [directives count]; counter++)
	{
		currentObject = [directives objectAtIndex:counter];
		//If we haven't already run into this object (via its parent container)
		// then we want to write it out. Otherwise, it will be copied implicitly 
		// along with its parent rather than copied explicitly.
		if([currentObject isAncestorInList:archivedContainers] == NO){
			[objectsToCopy addObject:currentObject];
		}
		//If this object is a container, we must record that it has been 
		// archived. Either it was archived just now, or it was archived 
		// earlier when its parent was archived.
		if([currentObject isKindOfClass:[LDrawContainer class]]){
			[archivedContainers addObject:currentObject];
		}
	}
	
	
	//Now that we have figured out *what* to copy, convert it into the 
	// *representations* we will use to copy.
	for(counter = 0; counter < [objectsToCopy count]; counter++)
	{
		currentObject = [objectsToCopy objectAtIndex:counter];
		
		//Convert the object into the two representations we know how to write.
		data	= [NSKeyedArchiver archivedDataWithRootObject:currentObject];
		string	= [currentObject write];
		
		//Save the representations into the arrays we'll write to the pasteboard.
		[archivedObjects addObject:data];
		[stringedObjects appendFormat:@"%@\n", string];
								//not using CRLF here because any Mac program that 
								// knows enough to do DOS line-endings will automatically
								// add them to pasted content.
	}
	
	
	//Set up our pasteboard.
	[pasteboard declareTypes:pboardTypes owner:nil];
	
	//Internally, Bricksmith uses archived LDrawDirectives to copy/paste.
	[pasteboard setPropertyList:archivedObjects forType:LDrawDirectivePboardType];
	
	//For other applications, however, we provide the LDraw file contents for 
	// the objects. Note that these strings cannot be pasted back into the 
	// program.
	[pasteboard setString:stringedObjects forType:NSStringPboardType];
	
}//end writeDirectives:toPasteboard:


//========== pasteFromPasteboard: ==============================================
//
// Purpose:		Paste the directives on the given pasteboard into the document.
//				The pasteboard must contain LDrawDirectivePboardType.
//
//				By generalizing the method in this way, we allow pasting off 
//				private internal pasteboards too. This method is used by 
//				-duplicate: in order to leverage the existing copy/paste code 
//				without wantonly destroying the contents of the General 
//				Pasteboard.
//
// Returns:		The objects added, or nil if nothing was on the pasteboard.
//
// Parameters:	pasteboard		- where the archived directives live
//				renameModels	- add "copy X" suffixes to pasted models as needed. 
//				parent			- add objects to this component (pass nil for default behavior)
//				insertAtIndex	- child index within parent (pass NSNotFound for default behavior)
//
//==============================================================================
- (NSArray *) pasteFromPasteboard:(NSPasteboard *) pasteboard
			preventNameCollisions:(BOOL)renameModels
						   parent:(LDrawContainer*)parent
							index:(NSInteger)insertAtIndex
{
	NSArray         *objects        = nil;
	id              currentObject   = nil; //some kind of unarchived LDrawDirective
	NSData          *data           = nil;
	NSMutableArray  *addedObjects   = [NSMutableArray array];
	NSInteger       counter         = 0;
	
	//We must make sure we have the proper pasteboard type available.
 	if([[pasteboard types] containsObject:LDrawDirectivePboardType])
	{
		//Unarchived everything and dump it into our file.
		objects = [pasteboard propertyListForType:LDrawDirectivePboardType];
		for(counter = 0; counter < [objects count]; counter++)
		{
			NSInteger real_index = insertAtIndex;
			if(real_index != NSNotFound)	real_index += counter;
			data			= [objects objectAtIndex:counter];
			currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];
			
			//Now pop the data into our file.
			if([currentObject isKindOfClass:[LDrawModel class]])
                [self addModel:currentObject atIndex:real_index preventNameCollisions:renameModels];
			else if([currentObject isKindOfClass:[LDrawStep class]])
				[self addStep:currentObject parent:(LDrawMPDModel*)parent index:real_index];
			else
			{
				[self addStepComponent:currentObject parent:parent index:real_index];
			}
			
			[currentObject optimizeOpenGL];
			[addedObjects addObject:currentObject];
		}
		
		//Select all the objects which have been added.
		[fileContentsOutline selectObjects:addedObjects];
	}

	//As this is the centralized conduit through which all "pasting" operations 
	// flow, this is where we refresh.
	[[self documentContents] noteNeedsDisplay];
	
	return addedObjects;
	
}//end pasteFromPasteboard:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're crossing over Jordan; we're heading to that mansion just 
//				over the hilltop (the gold one that's silver-lined).
//
// Note:		We DO NOT RELEASE TOP-LEVEL NIB OBJECTS HERE! NSWindowController 
//				does that automagically.
//
//==============================================================================
- (void) dealloc
{
	[[ModelManager sharedModelManager] documentSignOut:documentContents];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[documentContents	release];
	[lastSelectedPart	release];
	[selectedDirectives	release];

	[super dealloc];
	
}//end dealloc

@end
