//==============================================================================
//
// File:		AMSProgressPanel.h
//
// Purpose:		Displays a progress bar which estimates the time remaining to 
//				completion. 
//
//  Created by Allen Smith on Sun Sept 19 2004.
//  Copyright (c) 2004. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@interface AMSProgressPanel : NSObject
{
		   IBOutlet NSWindow			*dialogWindow;
	__weak IBOutlet NSTextField			*explanatoryText;
	__weak IBOutlet NSProgressIndicator	*progressBar;
	__weak IBOutlet NSTextField			*timeRemaining;
	
	double			 progressAmount; //the value of the progress bar.
	BOOL			 endsIndeterminate;
	BOOL			 runningAsSheet; //if yes, the progress panel is currently onscreen as a sheet.
	NSTimeInterval	 timeBetweenUpdates; //number of seconds between progress updates.
}

//Initialization
+ (AMSProgressPanel *) progressPanel;
+ (AMSProgressPanel *) doProgressBarWithMax:(double)maximum forWindow:(NSWindow *)parentWindow message:(NSString*)messageKey;
- (id) initWithMax:(double)maximum message:(NSString*)messageKey;

//Accessors
- (void) setIndeterminate:(BOOL)flag;
- (void) setValue:(double)newValue;
- (void) increment;
- (void) setMinValue:(double)newValue;
- (void) setMaxValue:(double)newValue;
- (void) setMessage:(NSString *)message;
- (void) setShowsTimeRemaining:(BOOL)flag;
- (void) setBecomesIndeterminateWhenCompleted:(BOOL)flag;
- (void) setUpdateFrequency:(NSTimeInterval)updateInterval;

//Actions
- (void) showProgressPanel;
- (void) showAsSheetForWindow:(NSWindow *)parentWindow;
- (void) close;


@end
