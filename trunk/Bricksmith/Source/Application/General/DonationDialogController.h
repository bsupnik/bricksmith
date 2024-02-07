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


////////////////////////////////////////////////////////////////////////////////
//
// class DonationDialogController
//
////////////////////////////////////////////////////////////////////////////////
@interface DonationDialogController : NSWindowController
{
	__weak IBOutlet BackgroundColorView	*mainBackground;
	__weak IBOutlet BackgroundColorView	*bottomBar;
	__weak IBOutlet NSButton			*suppressionCheckbox;
}

// Show dialog
- (void) runModal;
- (BOOL) shouldShowDialog;

// Actions
- (IBAction) laterButtonClicked:(id)sender;
- (IBAction) donateButtonClicked:(id)sender;
- (IBAction) suppressionCheckboxClicked:(id)sender;

@end
