//==============================================================================
//
// File:		DonationDialogController.m
//
// Purpose:		Shamelessly plead for money. You can make it go away for a 
//				while, but not forever. Mwuhahahaha.
//
// Modified:	07/23/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import "DonationDialogController.h"

#import "BackgroundColorView.h"
#import "LDrawApplication.h"
#import "LDrawFile.h"
#import "LDrawGLView.h"
#import "MacLDraw.h"


@implementation DonationDialogController

//========== awakeFromNib ======================================================
//
// Purpose:		Finish setting up the UI.
//
// Notes:		Bad things happened when I tried to use windowDidLoad.
//
//==============================================================================
- (void) awakeFromNib
{
	NSString    *modelPath  = nil;
	LDrawFile   *bumModel   = nil;

	[self->mainBackground	setBackgroundColor:[NSColor whiteColor]];
	[self->bottomBar		setBackgroundColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
	
	// Display an LDraw model of a beggar, just to set the tone.
	modelPath  = [[NSBundle mainBundle] pathForResource:@"Bum" ofType:@"ldr"];
	bumModel   = [LDrawFile fileFromContentsAtPath:modelPath];
	
	[self->bumModelView		setLDrawDirective:bumModel];
	[self->bumModelView		setAcceptsFirstResponder:NO];
	
	[self->bumModelView		reshape]; // must get projection set up to call zoomToFit:
	[self->bumModelView		zoomToFit:nil];
	
}//end awakeFromNib


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize the object
//
//==============================================================================
- (id) init
{
	self = [super initWithWindowNibName:@"Donation"];
	
	// Load the window. This ensures nib outlets are accessible.
	[self window];
	
	return self;

}//end init


#pragma mark -
#pragma mark SHOW DIALOG
#pragma mark -

//========== runModal ==========================================================
//
// Purpose:		Brings the dialog up.
//
//==============================================================================
- (void) runModal
{
	NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
	CFBundleRef     mainBundle      = CFBundleGetMainBundle();
	UInt32          bundleVersion   = CFBundleGetVersionNumber(mainBundle);
	
	// Set dialog values
	[self->suppressionCheckbox setState:NSOffState];
	

	// Show window
	[[self window] center];
	[[self window] makeKeyAndOrderFront:self];
	[NSApp runModalForWindow:[self window]];
	
	// Record for next time
	[userDefaults setInteger:bundleVersion forKey:DONATION_SCREEN_LAST_VERSION_DISPLAYED];
	[userDefaults synchronize];
	
}//end runModal


//========== shouldShowDialog ==================================================
//
// Purpose:		Returns whether we should nag the user to pay us this time.
//
//==============================================================================
- (BOOL) shouldShowDialog
{
	NSUserDefaults  *userDefaults               = [NSUserDefaults standardUserDefaults];
	CFBundleRef     mainBundle                  = CFBundleGetMainBundle();
	UInt32          bundleVersion               = CFBundleGetVersionNumber(mainBundle);
	BOOL            userRequestedSuppression    = [userDefaults boolForKey:DONATION_SCREEN_SUPPRESS_THIS_VERSION];
	UInt32          lastNagVersion              = [userDefaults integerForKey:DONATION_SCREEN_LAST_VERSION_DISPLAYED];
	BOOL            showDonationRequest         = YES;
	
	if(userRequestedSuppression == YES)
	{
		showDonationRequest = NO;
	}
	
	if(lastNagVersion != bundleVersion)
	{
		showDonationRequest = YES;
		
		// New version. Make them click the box again.
		[userDefaults setBool:NO forKey:DONATION_SCREEN_SUPPRESS_THIS_VERSION];
	}
	
	return showDonationRequest;	
	
}//end shouldShowDialog


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== donateButtonClicked: ==============================================
//
// Purpose:		Whisk them away to a website at which they can remunerate me.
//
//==============================================================================
- (IBAction) donateButtonClicked:(id)sender
{
	LDrawApplication	*appDelegate = [NSApp delegate];
	
	[appDelegate doDonate:sender];
	
}//end donateButtonClicked:


//========== laterButtonClicked: ===============================================
//
// Purpose:		OK clicked, dismiss dialog.
//
//==============================================================================
- (IBAction) laterButtonClicked:(id)sender
{
	[NSApp stopModalWithCode:NSOKButton];
	[self close];
	
}//end laterButtonClicked


//========== suppressionCheckboxClicked: =======================================
//
// Purpose:		They want us to stop nagging for this version.
//
//==============================================================================
- (IBAction) suppressionCheckboxClicked:(id)sender
{
	NSUserDefaults  *userDefaults               = [NSUserDefaults standardUserDefaults];
	BOOL            userRequestedSuppression    = [self->suppressionCheckbox state];
	
	[userDefaults setBool:userRequestedSuppression forKey:DONATION_SCREEN_SUPPRESS_THIS_VERSION];
	
}//end suppressionCheckboxClicked:


@end
