//==============================================================================
//
// File:		LDrawApplication.h
//
// Purpose:		This is the "application controller." Here we find application-
//				wide instance variables and actions, as well as application 
//				delegate code for startup and shutdown.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
/* LDrawApplication */

#import <Cocoa/Cocoa.h>

@class Inspector;
@class PartLibrary;
@class PartLibraryController;
@class LSynthConfiguration;


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawApplication
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawApplication : NSObject
{
	PartLibraryController	*partLibraryController;	// centralized location for part information.
    LSynthConfiguration     *lsynthConfiguration;   // centralized location for LSynth configuration
	Inspector				*inspector;				// system for graphically inspecting classes.
	NSOpenGLContext			*sharedGLContext;		// OpenGL variables like display list numbers are shared through this.
	UInt16			        connexionClientID;		// The identifier of client to a 3Dconnexion controller, if there is one.
	
	BOOL					suppressDonationPrompt;
}

//Actions
- (IBAction) doPreferences:(id)sender;
- (IBAction) doDonate:(id)sender;
- (IBAction) doHelp:(id)sender;
- (IBAction) doKeyboardShortcutHelp:(id)sender;
- (IBAction) doGettingNewPartsHelp:(id)sender;
- (IBAction) showColors:(id)sender;
- (IBAction) showInspector:(id)sender;
- (IBAction) doPartBrowser:(id)sender;
- (IBAction) showMouseTools:(id)sender;
- (IBAction) hideMouseTools:(id)sender;

//Accessors
+ (NSOpenGLPixelFormat *) openGLPixelFormat;
+ (Inspector *) sharedInspector;
+ (NSOpenGLContext *) sharedOpenGLContext;
+ (PartLibraryController *) sharedPartLibraryController;
- (Inspector *) inspector;
- (PartLibraryController *) partLibraryController;
- (LSynthConfiguration *) lsynthConfiguration;
- (NSOpenGLContext *) openGLContext;

//Utilities
- (void) findLDrawPath;
- (void) openHelpAnchor:(NSString *)helpAnchor;
- (NSString *) userName;
- (void) populateLSynthModelMenus;

void connexionMessageHandler(io_connect_t connection, natural_t messageType, void *messageArgument);

@end
