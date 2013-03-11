//==============================================================================
//
// File:		LDrawApplication.h
//
// Purpose:		This is the "application controller." Here we find application-
//				wide instance variables and actions, as well as application 
//				delegate code for startup and shutdown.
//
// Note:		Do not confuse this class with BricksmithApplication, which is 
//				an NSApplication subclass.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawApplication.h"

#import <3DConnexionClient/ConnexionClientAPI.h>
#import <mach/mach_time.h>
#import <Sparkle/Sparkle.h>

#import "DonationDialogController.h"
#import "Inspector.h"
#import "LDrawColorPanel.h"
#import "LDrawDocument.h"
#import "LDrawPaths.h"
#import "MacLDraw.h"
#import "PartBrowserPanelController.h"
#import "PartLibrary.h"
#import "PartLibraryController.h"
#import "LSynthConfiguration.h"
#import "PreferencesDialogController.h"
#import "ToolPalette.h"
#import "TransformerIntMinus1.h"

//==============================================================================
// Define a weak link to the 3DConnexion driver. See link below for more info on weak linking
// http://developer.apple.com/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/WeakLinking.html
// Note that, for this to work, "Other Linker Flags" in the project settings must contain:
//    -weak_framework 3DconnexionClient.framework
// The idea here is that the software automatically detects if a 3D mouse is present, but
// runs just fine if it is not.
extern OSErr InstallConnexionHandlers() __attribute__((weak_import));


@implementation LDrawApplication

//---------- initialize ----------------------------------------------[static]--
//
// Purpose:		Load things that need to be loaded *extremely* early in startup.
//
//------------------------------------------------------------------------------
+ (void) initialize
{
	TransformerIntMinus1 *minus1Transformer = [[[TransformerIntMinus1 alloc] init] autorelease];
	
	[NSValueTransformer setValueTransformer:minus1Transformer
									forName:@"TransformerIntMinus1" ];
}//end initialize


//========== awakeFromNib ======================================================
//
// Purpose:		Do first-load clean-up.
//
//==============================================================================
- (void) awakeFromNib
{
	OSErr	error;
	
	// Check to see if the 3DConnexion driver is installed
	if(InstallConnexionHandlers != NULL)
	{
		// Install message handler and register our client
		error = InstallConnexionHandlers(connexionMessageHandler, 0L, 0L);
		
		// This takes over in our application only. Note that the first field 
		// here is the "Bundle OS Type code" from the Info.plist file. 
		// Previously, this was set to '????', which isn't good. I just made up 
		// 'Brik', but if you want to change it, make the change both here and 
		// in the Info.plist file. Back in the OS 9 days, this code was hugely 
		// important, as it would identify who created a file. Not sure in the 
		// OS X world how much it matters. 
		connexionClientID = RegisterConnexionClient('Brik', "\pBricksmith", kConnexionClientModeTakeOver, kConnexionMaskAll);
		
		// This line was in the sample code, but doesn't compile, and doesn't seem to matter,
		// so has been removed.
		// Remove warning message about the framework not being available
		// ??? [mtFWNotFound removeFromSuperview];
	}	
}//end awakeFromNib


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//---------- openGLPixelFormat ---------------------------------------[static]--
//
// Purpose:		Returns the pixel format used in Bricksmith OpenGL views.
//
//------------------------------------------------------------------------------
+ (NSOpenGLPixelFormat *) openGLPixelFormat
{
	NSOpenGLPixelFormat				*pixelFormat		= nil;
	NSOpenGLPixelFormatAttribute	pixelAttributes[]	= {
															NSOpenGLPFANoRecovery, // Enable automatic use of OpenGL "share" contexts for Core Animation.
															NSOpenGLPFADoubleBuffer,
															NSOpenGLPFADepthSize,		32,
															NSOpenGLPFASampleBuffers,	1, // enable line antialiasing
															NSOpenGLPFASamples,			4, // antialiasing beauty
															0};

	pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: pixelAttributes];
	return [pixelFormat autorelease];
}


//---------- sharedInspector -----------------------------------------[static]--
//
// Purpose:		Returns the inspector object, which is created when the 
//				application launches.
//
// Note:		This method is static, so we don't have to keep passing pointers 
//				to this class around.
//
//------------------------------------------------------------------------------
+ (Inspector *) sharedInspector
{
	return [[NSApp delegate] inspector];
	
}//end sharedInspector


//---------- sharedOpenGLContext -------------------------------------[static]--
//
// Purpose:		Returns the OpenGLContext which unifies our display-list tags.
//				Every LDrawGLView should share this context.
//
//------------------------------------------------------------------------------
+ (NSOpenGLContext *) sharedOpenGLContext
{
	return [[NSApp delegate] openGLContext];
	
}//end sharedOpenGLContext


//---------- sharedPartLibraryController -----------------------------[static]--
//
// Purpose:		Returns the object which manages the part libary.
//
// Note:		This method is static, so we don't have to keep passing pointers 
//				to this class around.
//
//------------------------------------------------------------------------------
+ (PartLibraryController *) sharedPartLibraryController
{
	//Rather than making the part library a global variable, I decided to make 
	// it an instance variable of the Application Controller class, of which 
	// there is only one instance. This class is the application delegate too.
	PartLibraryController *libraryController = [[NSApp delegate] partLibraryController];
	
	return libraryController;
	
}//end sharedPartLibrary


//========== inspector =========================================================
//
// Purpose:		Returns the local instance of the inspector, which should be 
//				the only copy of it in the program.
//
//==============================================================================
- (Inspector *) inspector
{
	return inspector;
	
}//end inspector


//========== partLibraryController =============================================
//
// Purpose:		Returns the local instance of the part library controller, which 
//				should be the only copy of it in the program. You can access the 
//				part library itself through this object. 
//
//==============================================================================
- (PartLibraryController *) partLibraryController
{
	return partLibraryController;
	
}//end partLibraryController


//========== lsynthConfiguration ===============================================
//
// Purpose:		Returns the local instance of the LSynth configuration.
//
//==============================================================================
- (LSynthConfiguration *) lsynthConfiguration
{
	return lsynthConfiguration;
	
}//end lsynthConfiguration


//========== sharedOpenGLContext ===============================================
//
// Purpose:		Returns the OpenGLContext which unifies our display-list tags.
//				Every LDrawGLView should share this context.
//
//==============================================================================
- (NSOpenGLContext *) openGLContext
{
	return self->sharedGLContext;
	
}//end openGLContext


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//#pragma mark -
#pragma mark Application Menu

//========== doPreferences =====================================================
//
// Purpose:		Show the preferences window.
//
//==============================================================================
- (IBAction) doPreferences:(id)sender
{
	[PreferencesDialogController doPreferences];
	
}//end doPreferences:


//========== doDonate: =========================================================
//
// Purpose:		Takes the user to a webpage where they can give me money!
//				(Here's hoping.)
//
//==============================================================================
- (IBAction) doDonate:(id)sender
{
	NSURL *donationURL = [NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=6985549"];

	[[NSWorkspace sharedWorkspace] openURL:donationURL];
	
}//end doDonate:


#pragma mark -
#pragma mark Tools Menu

//========== showInspector: ====================================================
//
// Purpose:		Opens the inspector window. It may have something in it; it may 
//				not. That's up to the document.
//
//==============================================================================
- (IBAction) showInspector:(id)sender
{
	[inspector show:sender];
	
}//end showInspector:


//========== doPartBrowser: ====================================================
//
// Purpose:		Show or toggle the Part Browser, depending on the user's style 
//			    preference. 
//
//==============================================================================
- (IBAction) doPartBrowser:(id)sender 
{
	NSUserDefaults				*userDefaults		= [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT			newStyle			= [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	NSDocumentController		*documentController = [NSDocumentController sharedDocumentController];
	PartBrowserPanelController	*partBrowser		= nil;

	switch(newStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//toggle the part browser on the foremost document
			[[[documentController currentDocument] partBrowserDrawer] toggle:sender];
			
			break;
			
		case PartBrowserShowAsPanel:
			
			//open the shared part browser.
			partBrowser = [PartBrowserPanelController sharedPartBrowserPanel];
			[[partBrowser window] makeKeyAndOrderFront:sender];
			
			break;
	} 
	
}//end doPartBrowser:


//========== showMouseTools: ===================================================
//
// Purpose:		Opens the mouse tools palette, used to control the mouse cursor 
//				mode (e.g., selection, zooming, etc.).
//
//==============================================================================
- (IBAction) showMouseTools:(id)sender
{
	[[ToolPalette sharedToolPalette] showToolPalette:sender];
	
}//end showMouseTools:


//========== hideMouseTools: ===================================================
//
// Purpose:		Closes the mouse tools palette.
//
//==============================================================================
- (IBAction) hideMouseTools:(id)sender
{
	[[ToolPalette sharedToolPalette] hideToolPalette:sender];
	
}//end hideMouseTools:


#pragma mark -
#pragma mark Part Menu

//========== showColors: =======================================================
//
// Purpose:		Opens the colors panel.
//
//==============================================================================
- (IBAction) showColors:(id)sender
{
	LDrawColorPanel *colorPanel = [LDrawColorPanel sharedColorPanel];
	
	[colorPanel makeKeyAndOrderFront:sender];
	
	// It seems some DOS old-timers want to enter colors WITHOUT EVER CLICKING 
	// THE MOUSE. So, we assume that if the color panel was summoned by its key 
	// equivalent, we are probably dealing with one of these rabid anti-mouse 
	// people. We automatically make the color search field key, so they can 
	// enter color codes to their heart's content. 
	if([[NSApp currentEvent] type] == NSKeyDown)
		[colorPanel focusSearchField:sender];
	
}//end showColors:


#pragma mark -
#pragma mark Help Menu

//========== doHelp: ===========================================================
//
// Purpose:		Display the Bricksmith tutorial.
//
//==============================================================================
- (IBAction) doHelp:(id)sender
{
	[self openHelpAnchor:@"index"];
	
}//end doHelp:


//========== doKeyboardShortcutHelp: ===========================================
//
// Purpose:		Display a help page about keyboard shortcuts.
//
// Notes:		Don't use Help Viewer. See addendum  in -doHelp:.
//
//==============================================================================
- (IBAction) doKeyboardShortcutHelp:(id)sender
{
	[self openHelpAnchor:@"KeyboardShortcuts"];
	
}//end doKeyboardShortcutHelp:


//========== doGettingNewPartsHelp: ============================================
//
// Purpose:		Display a help page about installing unofficial LDraw parts.
//
// Notes:		Don't use Help Viewer. See addendum  in -doHelp:.
//
//==============================================================================
- (IBAction) doGettingNewPartsHelp:(id)sender
{
	[self openHelpAnchor:@"AboutLDraw"];
	
}//end doKeyboardShortcutHelp:


#pragma mark -
#pragma mark DELEGATES

#pragma mark -
#pragma mark NSApplication

//**** NSApplication ****
//========== applicationWillFinishLaunching: ===================================
//
// Purpose:		The application has opened; this comes before anything else 
//				(i.e., opening files) but after the application is set up.
//
//==============================================================================
- (void) applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSOpenGLPixelFormat *pixelFormat    = [LDrawApplication openGLPixelFormat];
	NSUserDefaults      *userDefaults   = [NSUserDefaults standardUserDefaults];
	
	//Make sure the standard preferences exist so they will be available 
	// throughout the application.
	[PreferencesDialogController ensureDefaults];
	
	[LDrawUtilities setColumnizesOutput:[userDefaults boolForKey:COLUMNIZE_OUTPUT_KEY]];
	[LDrawUtilities setDefaultAuthor:[self userName]];
	
	//Create shared objects.
	self->inspector					= [Inspector new];
	self->partLibraryController		= [[PartLibraryController alloc] init];
    self->lsynthConfiguration       = [LSynthConfiguration sharedInstance];
	self->sharedGLContext			= [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
	
	[sharedGLContext makeCurrentContext];
	
	//Try to define an LDraw path before the application even finishes starting.
	[self findLDrawPath];

	//Load the parts into the library; see if they loaded properly.
	if([partLibraryController loadPartCatalog] == NO)
	{
		//No path has been chosen yet.
		// We must choose one now.
		[self doPreferences:self];
		//When the preferences dialog opens, it will automatically search for 
		// the prefs path. Failing to find it, it will force the user to choose 
		// a new one.
	}
	
    // Parse the LSynth config file, using the bundled lsynth.mpd
    // TODO: make the location a preference
    NSLog(@"Reading lsynth config");
    NSString *lsynthConfigPath = [[NSBundle mainBundle] pathForResource:@"lsynth" ofType:@"mpd"];
    [self->lsynthConfiguration parseLsynthConfig:lsynthConfigPath];

	// Register for Notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(partBrowserStyleDidChange:)
												 name:LDrawPartBrowserStyleDidChangeNotification
											   object:nil ];
	
}//end applicationWillFinishLaunching:


//**** NSApplication ****
//========== applicationDidFinishLaunching: ====================================
//
// Purpose:		The application has finished launching.
//
//==============================================================================
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	BOOL				 showPartBrowser	= [userDefaults boolForKey:PART_BROWSER_PANEL_SHOW_AT_LAUNCH];
	
	if(		showPartBrowser == YES
	   &&	[userDefaults integerForKey:PART_BROWSER_STYLE_KEY] == PartBrowserShowAsPanel)
	{
		[[[PartBrowserPanelController sharedPartBrowserPanel] window] makeKeyAndOrderFront:self];
	}
	
	#if DEBUG
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:30 ];	// Debug build?  Save quick - no need to lose work when an assert() fires.
	#else
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:300];
	#endif
	
}//end applicationDidFinishLaunching:


//**** NSApplication ****
//========== applicationWillTerminate: =========================================
//
// Purpose:		Bricksmith is quitting. Do any necessary pre-quit work, such as 
//				saving out preferences.
//
//==============================================================================
- (void)applicationWillTerminate:(NSNotification *)notification
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	PartBrowserPanelController	*partBrowserPanel	= [PartBrowserPanelController sharedPartBrowserPanel];
	
	[userDefaults setBool:[[partBrowserPanel window] isVisible]
				   forKey:PART_BROWSER_PANEL_SHOW_AT_LAUNCH ];
				   
	[userDefaults synchronize];

	// If 3Dconnexion framework is installed, unregister our connection to it.
	if(InstallConnexionHandlers != NULL)
	{
		// Unregister our client and clean up all handlers
		if(connexionClientID) UnregisterConnexionClient(connexionClientID);
		CleanupConnexionHandlers();
	}
}//end applicationWillTerminate:


//========== applicationShouldTerminate: =======================================
//
// Purpose:		We might have to gently remind the user that he ought to support 
//				this great project, um, monetarily. 
//
//==============================================================================
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
	DonationDialogController	*donation = [[DonationDialogController alloc] init];
	
	if([donation shouldShowDialog] == YES && suppressDonationPrompt == NO)
	{
		[donation runModal];
	}
	
	[donation release];
	
	return NSTerminateNow;
	
}//end applicationShouldTerminate:


//========== validateMenuItem: =================================================
//
// Purpose:		Determines whether the given menu item should be available.
//				This method is called automatically each time a menu is opened.
//				We identify the menu item by its tag, which is defined in 
//				MacLDraw.h.
//
// Notes:		Menu items targeted at the document are handled in 
//				LDrawDocument. 
//
//==============================================================================
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger       tag             = [menuItem tag];
	BOOL            enable          = NO;
	
	switch(tag)
	{
		////////////////////////////////////////
		//
		// Tools Menu
		//
		////////////////////////////////////////
			
		case showMouseToolsMenuTag:
			[menuItem setHidden:[[ToolPalette sharedToolPalette] isVisible]];
			enable = YES;
			break;
			
		case hideMouseToolsMenuTag:
			[menuItem setHidden:([[ToolPalette sharedToolPalette] isVisible] == NO)];
			enable = YES;
			break;
			
		default:
			enable = YES;
			break;
			
	}
	
	return enable;
	
}//end validateMenuItem:


#pragma mark -
#pragma mark Sparkle

//========== updaterWillRelaunchApplication: ===================================
//
// Purpose:		Sparkle is about to install an update and relaunch.
//
//==============================================================================
- (void) updaterWillRelaunchApplication:(SUUpdater *)updater
{
	// Asking for money in the middle of an update process is a bit distracting.
	suppressDonationPrompt = YES;
}


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== partBrowserStyleDidChange: ========================================
//
// Purpose:		Reconfigure the part browser display based on new user 
//				preferences.
//
//==============================================================================
- (void) partBrowserStyleDidChange:(NSNotification *)notification
{
	NSUserDefaults          *userDefaults       = [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT       newStyle            = [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	NSDocumentController    *documentController = [NSDocumentController sharedDocumentController];
	NSArray                 *documents          = [documentController documents];
	NSInteger               documentCount       = [documents count];
	NSInteger               counter             = 0;
	
	switch(newStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//close the shared part browser
			[[PartBrowserPanelController sharedPartBrowserPanel] close];
			
			// open the browser drawer on each document
			for(counter = 0; counter < documentCount; counter++)
			{
				[[[documents objectAtIndex:counter] partBrowserDrawer] open];
			}
			
			break;
			
		case PartBrowserShowAsPanel:
			
			//close the browser drawer on each document
			for(counter = 0; counter < documentCount; counter++)
			{
				[[[documents objectAtIndex:counter] partBrowserDrawer] close];
			}
			
			//open the shared part browser.
			[[[PartBrowserPanelController sharedPartBrowserPanel] window] makeKeyAndOrderFront:self];
			
			break;
	} 
	
}//end partBrowserStyleDidChange:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== openHelpAnchor: ===================================================
//
// Purpose:		Provides much-needed API layering to open the specified help 
//				anchor token. DO NOT USE NSHelpManager DIRECTLY! 
//
// Rant:		Apple's automatic help registration is worthless. I've tried the 
//				program on numerous Macs; it refuses to load until the OS 
//				finally realizes a new program is there, which takes either 
//				a) 2 million years or b) voodoo/ritualistic sacrifice. So 
//				I'm bypassing what it does for something much less magical.
//
// Note:		I did manage to do *something* on two computers that got it 
//				working automatically (touching, copying, I don't know). But 
//				it never just happened when the application was first installed.
//
// Addendum:	I think the files need to be run through some help 
//				utility/indexer in the Developer Tools. But Help Viewer in 
//				Leopard is so abominable that I'm just going to launch a 
//				browser. On my  PowerBook G4, the Leopard Help Viewer takes 
//				2 minutes 42 seconds to launch and become responsive to events. 
//				That is shockingly unacceptible. 
//
//==============================================================================
- (void) openHelpAnchor:(NSString *)helpAnchor
{
	NSBundle	*applicationBundle	= [NSBundle mainBundle];
	NSString	*fileName			= helpAnchor; // help anchor is the filename by my convention
	NSString	*helpPath			= [applicationBundle pathForResource:fileName
																  ofType:@"html"
															 inDirectory:@"Help"];
	NSURL		*helpURL			= [NSURL fileURLWithPath:helpPath];
	
//	[[NSWorkspace sharedWorkspace] openFile:helpRoot withApplication:@"Help Viewer.app"];
	[[NSWorkspace sharedWorkspace] openURL:helpURL];
		
}//end openHelpAnchor:


//========== findLDrawPath =====================================================
//
// Purpose:		Search for an LDraw folder and display failure UI if it's not 
//				found. 
//
//==============================================================================
- (void) findLDrawPath
{
	NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
	LDrawPaths      *paths          = [LDrawPaths sharedPaths];
	NSString        *preferencePath = [userDefaults stringForKey:LDRAW_PATH_KEY];
	NSString        *ldrawPath      = preferencePath;
	
	// Search
	[paths setPreferredLDrawPath:preferencePath];
	ldrawPath = [paths findLDrawPath];
	
	//We found one.
	if(ldrawPath != nil)
	{
		[paths setPreferredLDrawPath:ldrawPath];
		[userDefaults setObject:ldrawPath forKey:LDRAW_PATH_KEY];
	}
	else
	{
		[self->partLibraryController validateLDrawFolderWithMessage:preferencePath];
		ldrawPath = nil;
	}
	
}//end findLDrawPath


//========== userName ==========================================================
//
// Purpose:		Returns the name of the current user of the computer.
//
//==============================================================================
- (NSString *) userName
{
	NSString    *fullName   = NSFullUserName();
	
	// 10.8 presents a frightening warning when an application tries to access 
	// the address book. So just use the username.
//	ABPerson    *userInfo   = [[ABAddressBook sharedAddressBook] me];
//	NSString    *firstName  = [userInfo valueForProperty:kABFirstNameProperty];
//	NSString    *lastName   = [userInfo valueForProperty:kABLastNameProperty];
	
	return fullName;
}


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The curtain falls.
//
//==============================================================================
- (void) dealloc
{
	[partLibraryController	release];
	[inspector				release];
	[sharedGLContext		release];

	[super dealloc];
	
}//end dealloc


#pragma mark -
#pragma mark CALLBACKS
#pragma mark -

//========== connexionMessageHandler ===========================================
//
// Purpose:		Respond to motions made by a 3DConnexion mouse. Based on the 
//				documentation in the SDK (found at 
//				http://www.3dconnexion.com/service/software-developer.html), 
//				this code implements what the docs call "object mode", where 
//				motions of the mouse manipulate the bricks. 
//
//				The mouse generates so many callbacks, that some throttling is 
//				needed to control the responsiveness. Unlike most 3d 
//				applications, Bricksmith uses "quantized" movement where bricks 
//				are shifted and rotated based on grid spacing, so the really 
//				fine tuning the mouse supplies is overkill. Also, the code 
//				performing the brick motion is slow relative to the callbacks, 
//				which causes them to accumulate in the queue. If not controlled, 
//				this makes move events happen long after the user lets go of the 
//				mouse, as the still full queue empties. So, code below generally 
//				just ignores mouse messages that are "too old". 
//
//				Motion from the mouse is remembered and accumulated, until it 
//				becomes large enough to result in a rotation or translation. On 
//				each event, the code is set up to only pay attention to the 
//				largest source of movement of the mouse. Again, this is unlike 
//				most 3D applications, but fits the way Bricksmith works better. 
//				The end result is that minor motion tends to be ignored, and 
//				using the mouse tends to use "snaps" rather than a "floating" 
//				sort of conrol. Also, this makes any give motion of the mouse do 
//				only one thing. For example, if the user pulls the mouse mostly 
//				in the +x direction, but also rotates the z axis slightly, only 
//				the +x motion is done (though the other movements are remembered 
//				and accumulated, until a peice actually moves). 
//
//				Control follows the grid, unless the user holds down the control 
//				key. If they hold down this key, as in apps like Photoshop, the 
//				grid is ignored, and a more "free form" control is used. 
//
//				TODO One trick here is that the performance should be the same 
//				regardless of processor speed. I _think_ this code does that, 
//				but I'm not sure. 
//
//				TODO The oneTypeOfMotionAtATime setting is hard-coded to true 
//				now. This should maybe be a preference, but maybe not. 
//
//				TODO Bricksmith has a "spin model" tool. When that tool is 
//				active, the 3d mouse should probably switch to "camera mode". 
//				Since I almost never actually use the spin model tool, I'm not 
//				sure how much this matters. 
//
//==============================================================================
void connexionMessageHandler(io_connect_t connection, natural_t messageType, void *messageArgument)
{
	static bool initialized = false;
	static bool oneTypeOfMotionAtATime = true; // If true, each event only translates _or_ rotates, not both
	static ConnexionDeviceState	lastState;
	static Vector3	translationScaling;
	static Vector3	rotationScaling;
	static Vector3	translationAccumulatedSinceLastMove;
	static Vector3	rotationAccumulatedSinceLastMove;
	ConnexionDeviceState		*state;
	NSDocumentController		*documentController	= [NSDocumentController sharedDocumentController];
	LDrawDocument				*currentDocument = [documentController currentDocument];
	SInt32 lagThreshold = 1000; // TODO Make constant
	
	UInt64 eventTime, now, deltaT;
	SInt32 sinceLastEvent, sinceNow;
	
	// We initialize some static objects, once, only if they are ever needed.
	if (!initialized)
	{
		// These scaling vectors provide the translation of the mouse coordinate system
		// to Bricksmiths coordinate system. As per the SDK, this is done mostly by feel
		// with the numbers manually tuned to give response that "feels right". Making
		// these numbers smaller will slow down the response, while making them larger
		// will speed it up. Note that end users do _not_ need the ability to change these
		// numbers within Bricksmith. The mouse driver software allow a user to tune the
		// response on a per-application basis. The numbers below seem to feel right with
		// the driver set to its default values. These may need some fine tuning still.
		translationScaling = V3Make(0.05, 0.05, 0.05);
		rotationScaling = V3Make(0.02, 0.02, 0.02);
		// Vectors to store movement accumulated since the last time the selection actually
		// changed position.
		translationAccumulatedSinceLastMove = V3Make(0.0, 0.0, 0.0);
		rotationAccumulatedSinceLastMove = V3Make(0.0, 0.0, 0.0);
		initialized = true;
	}
	
	switch(messageType)
	{
		case kConnexionMsgDeviceState:				
			state = (ConnexionDeviceState*)messageArgument;
			// decipher what command/event is being reported by the driver
			switch (state->command)
			{
				case kConnexionCmdHandleAxis:
					// Doing a move creates quite a bit of lag, during which even more motion events
					// are queued. This accumulation makes the controller feel non-responsive. So, to 
					// avoid this, ignore messages that occurred too far in the past.
					eventTime = state->time;
					deltaT = eventTime - lastState.time;
					sinceLastEvent = abs(AbsoluteToDuration( *(AbsoluteTime *) &deltaT ));
					now = mach_absolute_time();
					deltaT = now - eventTime;
					sinceNow = abs(AbsoluteToDuration( *(AbsoluteTime *) &deltaT ));
					if (sinceNow < lagThreshold)
					{
						// OK, we will pay attention to this event. First, figure out if the user
						// wants to use "snap to grid" or not. For the moment, we use the control
						// key as the guide (this is similar to how Photoshop works, where things snap
						// to edges and nearby points unless the control key is down). Some other
						// mechanism could be substituted here.
						NSEvent *event = [NSApp currentEvent];
						int modifierFlags = [event modifierFlags];
						bool controlDown = (0 != (modifierFlags & NSControlKeyMask) );
						
						// Build translation and rotation vectors from the event state.
						Vector3 originalNudgeVector = V3Make(state->axis[0],state->axis[2],-state->axis[1]);
						Vector3	originalRotation = V3Make(state->axis[3],state->axis[5],-state->axis[4]);
						
						// If the setting says to, constrain motion such that the peice only does
						// one thing at a time (that is, only moves on one axis or rotates on one
						// axis), whatever is most indicated by the control
						if (oneTypeOfMotionAtATime && !controlDown)
						{
							float magTrans = V3Length(originalNudgeVector);
							float magRot = V3Length(originalRotation);
							if (magRot > magTrans)
							{
								originalNudgeVector = V3Make(0.0,0.0,0.0);
								originalRotation = V3IsolateGreatestComponent(originalRotation);
							}
							else
							{
								originalNudgeVector = V3IsolateGreatestComponent(originalNudgeVector);
								originalRotation = V3Make(0.0,0.0,0.0);
							}
						}

						// Add in translation and rotation from prior events that didn't register
						// enough to actually move.
						translationAccumulatedSinceLastMove = V3Add(originalNudgeVector, translationAccumulatedSinceLastMove);
						rotationAccumulatedSinceLastMove = V3Add(originalRotation, rotationAccumulatedSinceLastMove);
						
						// Make vectors that we will manipulate (note that V3Duplicate allocates memory; we want to use the stack)
						Vector3	translation = V3Make(translationAccumulatedSinceLastMove.x,translationAccumulatedSinceLastMove.y,translationAccumulatedSinceLastMove.z);
						Vector3	rotation = V3Make(rotationAccumulatedSinceLastMove.x,rotationAccumulatedSinceLastMove.y,rotationAccumulatedSinceLastMove.z);
																		
						// The controller and Bricksmith use different scales to measure position and rotation.
						// Here we use some scaling constants that seem to give correct responsiveness
						// using the defalt "All Application" settings.
						translation = V3Mul(translation,translationScaling);
						rotation = V3Mul(rotation,rotationScaling);

						// Now find the granularity of the motion. This depends on how the user is using
						// the grid setting. To keep the motion under control, we determine a "threshold"
						// based on the grid. If motion on a given axis doesn't exceed the threshold, it
						// is set to zero. This helps ignore "noise" when you primarily move along one axis,
						// but the controller still detects minor motion along others.
						gridSpacingModeT mode = [currentDocument gridSpacingMode];
						int translationQuantum = (int)[BricksmithUtilities gridSpacingForMode:mode];
						if (!controlDown)
						{
							translation.x = ((int)(translation.x / translationQuantum)) * translationQuantum;
							translation.y = ((int)(translation.y / translationQuantum)) * translationQuantum;
							translation.z = ((int)(translation.z / translationQuantum)) * translationQuantum;
							
							int rotationQuantum = 1;
							switch(mode)
							{
								case gridModeFine:
									rotationQuantum = GRID_ROTATION_FINE;	//15 degrees
									break;
								case gridModeMedium:
									rotationQuantum = GRID_ROTATION_MEDIUM;	//45 degrees
									break;
								case gridModeCoarse:
									rotationQuantum = GRID_ROTATION_COARSE;	//90 degrees
									break;
							}
							rotation.x = ((int)(rotation.x / rotationQuantum)) * rotationQuantum;
							rotation.y = ((int)(rotation.y / rotationQuantum)) * rotationQuantum;
							rotation.z = ((int)(rotation.z / rotationQuantum)) * rotationQuantum;
						}
						
						int length = abs(V3Length(translation));
						if (length > 0)
						{
							[currentDocument moveSelectionBy:translation];
							translationAccumulatedSinceLastMove = V3Make(0.0, 0.0, 0.0);
						}
						length = abs(V3Length(rotation));
						if (length > 0)
						{
							[currentDocument rotateSelection:rotation mode:RotateAroundSelectionCenter fixedCenter:NULL];
							rotationAccumulatedSinceLastMove = V3Make(0.0, 0.0, 0.0);
						}
						//printf("3Dconnexion moved: %llu %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n", deltaT, translation.x, translation.y, translation.z, rotation.x, rotation.y, rotation.z);
					}
					break;
					
				case kConnexionCmdHandleButtons:
					// Not sure how to best use the buttons yet
					switch(state->buttons)
					{
						// Make the left button cycle through the grid modes, from coarse to fine. This
						// tends to match use, where you start out with a wide grid, and narrow in as you
						// move. Making the left button do this visually matches the direction the toolbar
						// selection appears to move as you click.
						case 1:
							switch([currentDocument gridSpacingMode])
							{
								case gridModeFine:
									[currentDocument setGridSpacingMode:gridModeCoarse];
									break;
								case gridModeMedium:
									[currentDocument setGridSpacingMode:gridModeFine];
									break;
								case gridModeCoarse:
									[currentDocument setGridSpacingMode:gridModeMedium];
									break;
							}
							break;
						case 2:
							// Make the right button snap selection to grid
							[currentDocument snapSelectionToGrid:nil];
							break;
					}
					//printf("3Dconnexion button pressed: %d\n", (int)state->buttons);
					break;
			}                
			
			memmove(&lastState, state, (long)sizeof(ConnexionDeviceState));
			break;
			
		default:
			// other messageTypes can happen and should be ignored
			break;
	}
}


@end
