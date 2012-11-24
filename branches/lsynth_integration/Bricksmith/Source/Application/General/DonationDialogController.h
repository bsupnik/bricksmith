//==============================================================================
//
// File:		DonationDialogController.h
//
// Purpose:		Shamelessly ask for money.
//
// Modified:	07/23/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

@class BackgroundColorView;
@class LDrawGLView;


////////////////////////////////////////////////////////////////////////////////
//
// class DonationDialogController
//
////////////////////////////////////////////////////////////////////////////////
@interface DonationDialogController : NSWindowController
{
	IBOutlet BackgroundColorView	*mainBackground;
	IBOutlet BackgroundColorView	*bottomBar;
	IBOutlet LDrawGLView			*bumModelView;
	IBOutlet NSButton				*suppressionCheckbox;
}

// Show dialog
- (void) runModal;
- (BOOL) shouldShowDialog;

// Actions
- (IBAction) laterButtonClicked:(id)sender;
- (IBAction) donateButtonClicked:(id)sender;
- (IBAction) suppressionCheckboxClicked:(id)sender;

@end
