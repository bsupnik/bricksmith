//==============================================================================
//
// File:		Inspector.m
//
// Purpose:		Manages the flow of the inspection system in the application.
//				This class, of which there ought to be only one instance, 
//				creates a single Inspector utility window and manages the 
//				display of the specialized inspectors for each kind of editable 
//				component.
//
//              InspectionXXX classes should implement, at a minimum
//                - (id) init  // should load the .xib
//                - (void) commitChanges:(id)sender
//                - (IBAction) revert:(id)sender
//
//              ...in addition to any methods to handle editing in the inspector.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "Inspector.h"

#import "ObjectInspectionController.h"


@implementation Inspector


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Ready the inspector palette.
//
//==============================================================================
- (id) init
{
    self = [super init];
	
    if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO) {
        NSLog(@"Can't load Inspector nib file");
    }
	
	//When the Nib first loads, it contains the view we intend to use for an 
	// empty inspector. 
	emptyInspectorTitle = [[inspectorPanel title] retain];
	emptyInspectorView = [[inspectorPanel contentView] retain];
	
	//Display a message appropriate to inspecting nothing.
	[self inspectObject:nil];
	
    return self;
	
}//end init


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== inspectObject: ====================================================
//
// Purpose:		Convenience method for -inspectObjects
//
//==============================================================================
- (void) inspectObject:(id)object
{
	NSArray *objectList;
	
	if(object != nil)
		objectList = [NSArray arrayWithObject:object];
	else
		objectList = [NSArray array];
	
	[self inspectObjects: objectList];
	
}//end inspectObject:


//========== inspectObjects: ===================================================
//
// Purpose:		Displays an object with its own special inspection panel.
//
//				This method takes an array in order to easily accommodate a
//				"multiple selection" error message. If you actually want 
//				anything inspected, you should pass an array with a single 
//				element.
//
//==============================================================================
- (void) inspectObjects:(NSArray *) objects
{
	BOOL		 foundInspector		= NO;
	NSString	*errorString		= nil;
	id			 objectToInspect	= nil;
	
	//No object to inspect? Just show the empty message.
	if(objects == nil || [objects count] == 0)
	{
		errorString = NSLocalizedString(@"EmptySelection", nil);
		[self unloadInspector];
	}
	else if([objects count] > 1)
	{
		errorString = NSLocalizedString(@"MultipleSelection", nil);
		[self unloadInspector];
	}
	else{
		//We have an object; let's see if we can get an inspector for it.
		objectToInspect = [objects objectAtIndex:0];
		
		if([currentInspector object] != objectToInspect)
		{
			[self unloadInspector];
		
			foundInspector = [self loadInspectorForObject:objectToInspect];

			//We have an object, but it doesn't have an inspector we understand.
			// Display a message indicating there is nothing here to inspect.
			if(foundInspector == NO)
				errorString = NSLocalizedString(@"NoInspector", nil);
		}
		else
		{
			foundInspector = YES;
			[currentInspector revert:self]; //calling revert should set the values of the palette.
		}

	}
	
	if(foundInspector == NO){
		[inspectorPanel setContentView:emptyInspectorView];
		[inspectorPanel setTitle:emptyInspectorTitle];
		[errorTextField setStringValue:errorString];
	}
	
}//end inspectObjects:


//========== loadInspectorForObject: ===========================================
//
// Purpose:		Loads the inspector view and controller for inspecting object.
//
// Notes:		This method should never be called directly from outside the 
//				class.
//
//==============================================================================
- (BOOL) loadInspectorForObject:(id) objectToInspect
{
	BOOL foundInspector = NO; //not yet, anyway.
	
	//Inspectable objects will tell us what class to use to inspect with.
	if([objectToInspect respondsToSelector:@selector(inspectorClassName)]){
		
		//Find the class to use, and instantiate one.
		NSString	*className			= [objectToInspect performSelector:@selector(inspectorClassName)];
		Class		 InspectionClass	= NSClassFromString(className);
		
		if([InspectionClass isSubclassOfClass:[ObjectInspectionController class]]){
			//We have an inspector for the object that we understand!
			foundInspector = YES;
			id objectInspector = [[InspectionClass alloc] init];
			[objectInspector setObject:objectToInspect];
			
			//Show the inspector palette.
			[inspectorPanel setContentView:[[objectInspector window] contentView]];
			[inspectorPanel setTitle:[[objectInspector window] title]];
			
			//Save the inspector, so we know what we are inspecting, and so 
			// we can clean up the memory for it.
			currentInspector = objectInspector;
		}
		
	}//end inspectable check.
	
	return foundInspector;
	
}//end loadInspectorForObject:


//========== unloadInspector ===================================================
//
// Purpose:		Destroys the current inspector object.
//
//==============================================================================
- (void) unloadInspector
{
	// End any editing happening in the current inspector. It is very important 
	// to do this *before* attempting to replace the inspector!
	[inspectorPanel makeFirstResponder:nil];
	[currentInspector release];
	currentInspector = nil;
}


//========== show ==============================================================
//
// Purpose:		Open the inspector panel for all the world to see.
//
//==============================================================================
- (void) show:(id) sender
{
	[inspectorPanel makeKeyAndOrderFront:sender];

}//end show:


#pragma mark -
#pragma mark DELEGATES
#pragma mark -

//**** NSWindow ****
//========== windowDidResignKey: ===============================================
//
// Purpose:		Window is losing editing ability.
//
//==============================================================================
- (void)windowDidResignKey:(NSNotification *)notification
{
	// End any editing happening in the current inspector. We need to do this 
	// because once the inspector is no longer key, you can do nasty things to 
	// the object it is editing -- like deleting it, for example. If you were to 
	// delete the object the inspector is using, the inspector would then try to 
	// commit any outstanding edits on an object which is no longer in the 
	// document. This confuses Undo horribly; the application can hang if you 
	// try to undo over that change. 
	[inspectorPanel makeFirstResponder:nil];
}


//**** NSWindow ****
//========== windowWillReturnUndoManager: ======================================
//
// Purpose:		Allows Undo to keep working transparently through this window by 
//				allowing the undo request to forward on to the active document.
//
//==============================================================================
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	return [currentDocument undoManager];

}//end windowWillReturnUndoManager:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The Class Vanishes.
//
//==============================================================================
- (void) dealloc
{
	[inspectorPanel			release];
	[emptyInspectorTitle	release];
	[emptyInspectorView		release];
	[currentInspector		release];
	
	[super dealloc];
	
}//end dealloc


@end
