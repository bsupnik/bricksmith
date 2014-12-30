//==============================================================================
//
// File:		SearchPanel.m
//
// Purpose:		Search for parts in a file.  Structure copied from ColorPanel.
//
//==============================================================================
#import "SearchPanelController.h"

#import "LDrawDocument.h"
#import "LDrawMPDModel.h"
#import "LDrawFile.h"
#import "LDrawStep.h"
#import "LDrawModel.h"
#import "LDrawPart.h"
#import "LDrawLSynth.h"
#import "LDrawColorPanel.h"
#import "LDrawGLView.h"
#import "LDrawFileOutlineView.h"
#import "PartBrowserTableView.h"
#import "MacLDraw.h"

@implementation SearchPanelController

SearchPanelController *sharedSearchPanel = nil;

//========== awakeFromNib ======================================================
//
// Purpose:		Brings the Search panel to life.
//
// Note:		Please note that this method is called BEFORE most class
//				initialization code.
//
//==============================================================================
- (void) awakeFromNib
{
    // Register for dragging operations - we want to be able to drag parts into the search box
    [[self window] registerForDraggedTypes:[NSArray arrayWithObjects:LDrawDirectivePboardType, LDrawDraggingPboardType, nil]];
    
	// Set the initial state of the UI
	NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
	LDrawDocument        *currentDocument    = [documentController currentDocument];
	NSArray              *selectedObjects    = [currentDocument selectedObjects];
	[self updateInterfaceForSelection:selectedObjects];
	
}//end awakeFromNib

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//---------- sharedSearchPanel ---------------------------------------[static]--
//
// Purpose:		Returns the global instance of the search panel.
//
//------------------------------------------------------------------------------
+ (SearchPanelController *) searchPanel
{
    if(sharedSearchPanel == nil)
        sharedSearchPanel = [[SearchPanelController alloc] init];

    return sharedSearchPanel;

}//end sharedSearchPanel

//========== init ==============================================================
//
// Purpose:		Brings the LDraw search panel to life.
//
//==============================================================================
- (id) init
{
	self = [super initWithWindowNibName:@"SearchPanel"];
	if(self)
	{
	}
    return self;
}// end init

#pragma mark - ACCESSORS -

//---------- isVisible -----------------------------------------------[static]--
//
// Purpose:		Returns whether the shared search panel object is visible or 
//				not.
//
//------------------------------------------------------------------------------
+ (BOOL) isVisible
{
	return (sharedSearchPanel != nil);
}

#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== doSearchAndSelect: ================================================
//
// Purpose:		The main search method.  This operates as follows:
//
//              - Determine where to search (the scope): File, Model, Step or within
//                the current selection
//              - Collect all potential matches up
//              - Filter out parts that don't match our criteria, based on part
//                type and colour
//              - Select the remaining matching parts
//
//==============================================================================
- (IBAction)doSearchAndSelect:(id)sender
{
    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    LDrawDocument        *currentDocument    = [documentController currentDocument];
    NSArray              *selectedObjects    = [self selectedObjects];
    ScopeT                scope              = (ScopeT)[[scopeMatrix selectedCell] tag];
    SearchPartCriteriaT   criterion          = (SearchPartCriteriaT)[[findTypeMatrix selectedCell] tag];
    ColorFilterT          colorCriterion     = (ColorFilterT)[[colorMatrix selectedCell] tag];
    
    //
    // Determine our search criteria
    //

    NSArray *colorFilter = nil;
    NSArray *partFilter = nil;
    NSMutableArray *selectedParts = [[[NSMutableArray alloc] init] autorelease];
    NSMutableArray *searchableObjects = [[[NSMutableArray alloc] init] autorelease];
    
    // First up, adjust the options if there's no selection
    if ([selectedObjects count] == 0) {
        if (scope == ScopeStep || scope == ScopeSelection) {
            scope = ScopeFile;
        }
        
        if (colorCriterion == ColorSelectionFilter) {
            colorCriterion = ColorNoFilter;
        }
        
        if (criterion == SearchSelectedParts) {
            criterion = SearchAllParts;
        }
    }
    
    // Where to search - File, Model and Step
    if (scope != ScopeSelection) {
        
        // Nothing selected?  Search the current model or default to searching the entire file
        if (![selectedObjects count]) {
            if (scope == ScopeModel) {
                if ([[currentDocument documentContents] activeModel]) {
                    [searchableObjects addObject:[[currentDocument documentContents] activeModel]];
                }
            }
            else {
                if ([currentDocument  documentContents]) {
                    [searchableObjects addObject:[currentDocument  documentContents]];
                };
            }
        }
        
        // filter non-parts from the selection (we can't search *for* steps, but we can search
        // *in* the current step, model etc.
        [selectedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[LDrawPart class]] || [obj isKindOfClass:[LDrawLSynth class]] // parts
                || ([obj isKindOfClass:[LDrawStep class]] && scope == ScopeStep)                 // steps
                || ([obj isKindOfClass:[LDrawModel class]] && scope == ScopeModel)) {            // models
                [selectedParts addObject:obj];
            }
        }];
        
        for (LDrawPart *part in selectedParts) {
            
            // Find the container at the correct scope
            id scopedContainer = nil;
            if (scope == ScopeStep) {
                scopedContainer = [part enclosingStep];
            }
            else if (scope == ScopeModel) {
                scopedContainer = [part enclosingModel];
            }
            else if (scope == ScopeFile) {
                scopedContainer = [part enclosingFile];
            }
            
            // Keep it if we don't already have it
            if ([searchableObjects indexOfObject:scopedContainer] == NSNotFound) {
                [searchableObjects addObject:scopedContainer];
            }
        }
    }
    
    // Search within the selection, so just take it wholesale
    else {
        searchableObjects = [[selectedObjects mutableCopy] autorelease];
    }
    
    // Color
    if (colorCriterion == ColorFilter) {
        colorFilter = [NSArray arrayWithObject:[colorWell LDrawColor]];
    }
    else if (colorCriterion == ColorSelectionFilter) {
        NSMutableArray *colors = [[NSMutableArray alloc] init];
        [selectedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[LDrawPart class]] || [obj isKindOfClass:[LDrawLSynth class]]) {
                if ([colors indexOfObject:[obj LDrawColor]] == NSNotFound) {
                    [colors addObject:[obj LDrawColor]];
                }
            }
        }];
        colorFilter = colors;
    }
    
    // What to search for
    if (criterion == SearchSpecificPart) {

        // Split the text field on commas
        NSArray *tmpParts = [[partName stringValue] componentsSeparatedByString:@","];
        __block NSMutableArray *partNames = [[NSMutableArray alloc] init];
        __block NSString *part = nil;
        
        // Add ".dat" to parts without a recognised suffix
        [tmpParts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            part = [[obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
            if (![part hasSuffix:@".dat"] && ![part hasSuffix:@".ldr"]) {
                part = [NSString stringWithFormat:@"%@.dat", part];
            }
            [partNames addObject:part];
        }];
        
        partFilter = partNames;
    }
    else if (criterion == SearchSelectedParts) {
        NSMutableArray *partNames = [[NSMutableArray alloc] init];
        [selectedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[LDrawPart class]]) {
                [partNames addObject:[obj referenceName]];
            }
            else if ([obj isKindOfClass:[LDrawLSynth class]]) {
                [partNames addObject:[obj lsynthType]];
            }
        }];
        partFilter = partNames;
    }
    
    //
    // Collect up all potential matches
    //
    
    NSMutableArray *matchables = [[[NSMutableArray alloc] init] autorelease];
    for (id searchableObject in searchableObjects) {
        // Parts
        if ([searchableObject isKindOfClass:[LDrawPart class]]) {
            [matchables addObject:searchableObject];
        }
        
        // Containers
        else if ([searchableObject isKindOfClass:[LDrawContainer class]]) {
            [matchables addObjectsFromArray:[self partsInContainer:searchableObject]];
        }
        
        // Include LSynth objects, as well as their contained constraints
        if ([searchableObject isKindOfClass:[LDrawLSynth class]]) {
            [matchables addObject:searchableObject];
        }
    }
    
    //
    // Filter potential matches against our criteria
    //
    
    NSMutableArray *nonMatchingParts = [[[NSMutableArray alloc] init] autorelease];
    
    for (id part in matchables) {
        
        // Filter on color
        if (colorFilter && [colorFilter indexOfObject:[part LDrawColor]] == NSNotFound) {
            [nonMatchingParts addObject:part];
            continue;
        }
        
        // Filter on part criterion
        NSString *name = nil;
        if ([part isKindOfClass:[LDrawPart class]]) {
            name = [part referenceName];
        }
        else if ([part isKindOfClass:[LDrawLSynth class]]) {
            name = [part lsynthType];
        }
        
        if (partFilter && [partFilter indexOfObject:name] == NSNotFound) {
            [nonMatchingParts addObject:part];
            continue;
        }
    }

    // Filter hidden parts out if appropriate
    if ([searchHiddenParts state] == NSOnState) {
        [matchables enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj respondsToSelector:@selector(setHidden:)] && [obj isHidden] &&
                [nonMatchingParts indexOfObject:obj] == NSNotFound) {
                [nonMatchingParts addObject:obj];
            }
        }];
    }
    
    [matchables removeObjectsInArray:nonMatchingParts];
    
    [currentDocument selectDirectives:matchables];
} // end doSearchAndSelect:

//========== scopeChanged: =====================================================
//
// Purpose:		Update the UI in response to the user changing the search scope
//
//==============================================================================
- (IBAction)scopeChanged:(id)sender {
    [self updateInterfaceForSelection:[self selectedObjects]];
} // end scopeChanged:

//========== colorOptionChanged: ===============================================
//
// Purpose:		Update the UI in response to the user changing the search color option
//
//==============================================================================
- (IBAction)colorOptionChanged:(id)sender {
    [self updateInterfaceForSelection:[self selectedObjects]];
} // end colorOptionChanged:

//========== findTypeOptionChanged: ============================================
//
// Purpose:		Update the UI in response to the user changing the search part option
//
//==============================================================================
- (IBAction)findTypeOptionChanged:(id)sender {
    [self updateInterfaceForSelection:[self selectedObjects]];
} // end findTypeOptionChanged:

#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//**** NSWindow ****
//========== windowWillClose: ==================================================
//
// Purpose:		Window is closing; clean up.
//
//==============================================================================
- (void) windowWillClose:(NSNotification *)notification
{
	[self autorelease];
	sharedSearchPanel = nil;
}


//**** NSWindow ****
//========== windowWillReturnUndoManager: ======================================
//
// Purpose:		Allows Undo to keep working transparently through this window by
//				allowing the undo request to forward on to the active document.
//
//==============================================================================
- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
    NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];

    return [currentDocument undoManager];

}//end windowWillReturnUndoManager:


#pragma mark - UTILITIES -

//========== partsInContainer: =================================================
//
// Purpose:		A recursive helper function to find all parts in a container
//
//==============================================================================
-(NSArray *)partsInContainer:(LDrawContainer *)container
{
    NSMutableArray *parts = [[[NSMutableArray alloc] init] autorelease];
    for (id directive in [container subdirectives]) {
        if ([directive isKindOfClass:[LDrawPart class]]) {
            [parts addObject:directive];
        }
        // Recurse on subcontainers
        else if (([directive isKindOfClass:[LDrawContainer class]] && ![directive isKindOfClass:[LDrawLSynth class]])
                 || ([directive isKindOfClass:[LDrawLSynth class]] && [searchInsideLSynthContainers state] == NSOnState)) {
            [parts addObjectsFromArray:[self partsInContainer:directive]];
        }
        
        // Add LSynth "Parts" specifically. Their contents are handled above
        if ([directive isKindOfClass:[LDrawLSynth class]]) {
            [parts addObject:directive];
        }
    }
    
    return parts;
} // end partsInContainer:

//========== updateInterfaceForSelection: ======================================
//
// Purpose:		The Document lets us know when the selection changes.  We can in
//              turn update the UI appropriately.  We don't change the user's
//              options, merely warn them what we'll do.
//
//==============================================================================
- (void) updateInterfaceForSelection:(NSArray *)selectedObjects
{
    // The selection's changed which means we shouldn't be the active color well anymore
    [LDrawColorWell setActiveColorWell:nil];
    
    // No selection so display a suitable warning message and disable the UI elements
    NSMutableArray *warningComponents = [[NSMutableArray alloc] init];

    if ([selectedObjects count] == 0
        &&
        // Even if we have nothing selected the combination of options might not be cause for alarm
        ([scopeMatrix selectedTag] == ScopeSelection ||
         [scopeMatrix selectedTag] == ScopeStep ||
         [colorMatrix selectedTag] == ColorSelectionFilter ||
         [findTypeMatrix selectedTag] == SearchSelectedParts)
        ) {
        
        [warningComponents addObject:NSLocalizedString(@"SearchWarningRoot", @"")];
        
        // The "what"
        if ([findTypeMatrix selectedTag] == SearchAllParts || [findTypeMatrix selectedTag] == SearchSelectedParts) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningAllParts", @"")];
        }
        else if ([findTypeMatrix selectedTag] == SearchSpecificPart) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningSpecifiedParts", @"")];
        }
        
        [warningComponents addObject:@"of"]; // preposition
        
        // The color
        if ([colorMatrix selectedTag] == ColorNoFilter || [colorMatrix selectedTag] == ColorSelectionFilter) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningAnyColor", @"")];
        }
        else if ([colorMatrix selectedTag] == ColorFilter) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningSpecifiedColor", @"")];
        }
        
        [warningComponents addObject:@"in"]; // preposition
        
        // The "where"
        if ([scopeMatrix selectedTag] == ScopeFile || [scopeMatrix selectedTag] == ScopeStep || [scopeMatrix selectedTag] == ScopeSelection) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningFileScope", @"")];
        }
        else if ([scopeMatrix selectedTag] == ScopeModel) {
            [warningComponents addObject:NSLocalizedString(@"SearchWarningModelScope", @"")];
        }

        [warningText setStringValue:[[warningComponents componentsJoinedByString:@" "] stringByAppendingString:@"."]];
        [warningText setHidden:NO];
        
    }
    
    // No warnings
    else {
        [warningText setHidden:YES];
    }
} // end updateInterfaceForSelection:

//========== selectedObjects ===================================================
//
// Purpose:		Convenience method to return all selected objects in the document
//
//==============================================================================
-(NSArray *)selectedObjects
{
    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    LDrawDocument        *currentDocument    = [documentController currentDocument];

    return [currentDocument selectedObjects];
} // end selectedObjects

#pragma mark -
#pragma mark <NSDraggingDestination>
#pragma mark -

//========== draggingEntered: ==================================================
//
// Purpose:		Return the drag type.  We don't want to move or copy the data.
//              The Link type gives us a nice indicative arrow with our cursor.
//
//==============================================================================
-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    // We want to intercept drops on the part name text field and handle them ourselves
    [partName setEditable:NO];
    return NSDragOperationLink;
} // end draggingEntered:

//========== draggingExited: ==================================================
//
// Purpose:		The user has dragged the part back out of the window.
//
//==============================================================================
-(void)draggingExited:(id < NSDraggingInfo >)sender
{
    // Reenable normal editing of the part name text field
    [partName setEditable:YES];
} // end draggingExited:

//========== prepareForDragOperation: ==========================================
//
// Purpose:		Someone wants to drop something on us.  We don't want to accept
//              the drop, but we do want to know what parts they wanted to drop
//              on us.
//
//==============================================================================
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    NSArray        *archivedDirectives = nil;
    NSMutableArray *directiveNames     = [[[NSMutableArray alloc] init] autorelease];
    NSUInteger      directiveCount     = 0;
	NSUInteger      counter            = 0;
	id              currentObject      = nil;
	NSData         *data               = nil;
    NSString       *partNames          = nil;
    
    // Parts can be dragged from the outline view or the part browser.  GLView drags
    // remove the pieces once they leave the window, so we ignore those.
    
    if ([[sender draggingSource] isKindOfClass:[LDrawFileOutlineView class]]
        || [[sender draggingSource] isKindOfClass:[PartBrowserTableView class]]) {

        NSPasteboard *pasteboard = [sender draggingPasteboard];
        
        // Outline View
        if ([[sender draggingSource] isKindOfClass:[LDrawFileOutlineView class]]) {
            archivedDirectives	= [pasteboard propertyListForType:LDrawDirectivePboardType];
        }
        
        // Part browser
        else if ([[sender draggingSource] isKindOfClass:[PartBrowserTableView class]]) {
            archivedDirectives	= [pasteboard propertyListForType:LDrawDraggingPboardType];
        }
        
        // Grab the part names
        directiveCount = [archivedDirectives count];
        for(counter = 0; counter < directiveCount; counter++)
        {
            data = [archivedDirectives objectAtIndex:counter];
            currentObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            
            // We're only interested in LDrawParts we've not already found
            if ([currentObject isKindOfClass:[LDrawPart class]] &&
                [directiveNames indexOfObject:[currentObject referenceName]] == NSNotFound) {
                [directiveNames addObject:[currentObject referenceName]];
            }
        }
        
        partNames = [directiveNames componentsJoinedByString:@","];
    }

    [partName setStringValue:partNames];
    
    // We don't actually want to do a drag, but we do want to reenable the text field
    [partName setEditable:YES];
    return YES;
} // end prepareForDragOperation:

#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're off to the big Brick in the sky
//
//==============================================================================
- (void) dealloc
{
    [super dealloc];
    
}//end dealloc

@end
