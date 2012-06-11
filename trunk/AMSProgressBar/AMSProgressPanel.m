//==============================================================================
//
// File:		AMSProgressPanel.m
//
// Purpose:		Displays a progress bar which estimates the time remaining to 
//				completion.
//
//  Created by Allen Smith on Sun Sept 19 2004.
//  Copyright (c) 2004. All rights reserved.
//==============================================================================
#import "AMSProgressPanel.h"

@implementation AMSProgressPanel

#pragma mark -
#pragma mark Initialization
#pragma mark -


//========== progressPanel =====================================================
//
// Purpose:		Initializes a simple progress bar window. It's up to you to do 
//				more with it. 
//
//				By default, the range is 0.0 to 100.0 and it does not show time 
//				remaining, and does not become indeteriminate upon completion. 
//
//==============================================================================
+ (AMSProgressPanel *) progressPanel
{
	AMSProgressPanel *progressWindow = [[[AMSProgressPanel alloc] init] autorelease];
	
	return progressWindow;
}


//========== doProgressBarWithMax:forWindow:parentWindow =======================
//
// Purpose:		Initializes and displays in one fell swoop
//				messageKey is a key from a Localized string file
//
//==============================================================================
+ (AMSProgressPanel*) doProgressBarWithMax:(double)maximum
								 forWindow:(NSWindow *)parentWindow
								   message:(NSString*)messageKey
{
	AMSProgressPanel *progressWindow = [[[AMSProgressPanel alloc]
												initWithMax:maximum
													message:messageKey] autorelease];
	
	[progressWindow showAsSheetForWindow:parentWindow];
	
	return progressWindow;
}


//========== init: =============================================================
//
// Purpose:		Just loads the bundle and sets up a very basic window.
//
//==============================================================================
- (id) init
{
	self = [super init];
	[NSBundle loadNibNamed:@"Progress Bar" owner:self];
	
	runningAsSheet = NO; //not yet displayed.
	
	[explanatoryText setStringValue:@""];
	[timeRemaining setHidden:YES];
	[self setBecomesIndeterminateWhenCompleted:NO];
	timeBetweenUpdates = 1.0/4.0; //4 updates per second.
	previousUpdateTime = [NSDate distantPast];
	
	return self;
}

//========== initWithMax: ======================================================
//
// Purpose: Initializes everything and sets the progress bars' max value to maximum
//
//==============================================================================
- (id) initWithMax:(double)maximum
		   message:(NSString*)message
{
	[self init];
	
	[progressBar setDoubleValue:0.0];
	[progressBar setMaxValue:maximum];
	
	//Create labels
	[explanatoryText setStringValue:message];
	[timeRemaining setHidden:NO];
	
	return self;
}

#pragma mark -
#pragma mark Accessors
#pragma mark -


//========== setIndeterminate: =================================================
//
// Purpose:		Sets whether the progress bar we display is indeterminate.
//
//==============================================================================
- (void) setIndeterminate:(BOOL)flag
{
	[self->progressBar setIndeterminate:flag];
	if(flag == YES)
	{
		//seems like animation is a run-loop event (no surprise, really). But if 
		// we are doing tight processing, that means the bar will never animate!
		// So we must multithread, performance be darned.
		[progressBar setUsesThreadedAnimation:YES];
		[self->progressBar startAnimation:self];
		
		[dialogWindow displayIfNeeded];
	}
	
}//end setIndeterminate:


//========== setValue: =========================================================
//
// Purpose:		Updates the progress bar and its time indicator. Note that we 
//				maintain a value of the progress bar inside this class. We do 
//				this because we only update the progress bar itself every so 
//				often (thus drastically reducing the amount of processing time 
//				it chews up), so we need our own little reference for what the 
//				bar is between updates.
//
//==============================================================================
- (void) setValue:(double)newValue
{
	double maximumToAttain = [progressBar maxValue];
	
	progressAmount = newValue;
	
	if(newValue < maximumToAttain)
	{
		//Check and see if it is too early to update.
		// This speeds up progress display considerably.
		if(-[previousUpdateTime timeIntervalSinceNow] > timeBetweenUpdates)
		{
			//Estimate time remaining.
			NSTimeInterval  secondsSinceStart           = -[startTime timeIntervalSinceNow]; //negative because startTime was before now
			float           secondsPerValue             = secondsSinceStart/newValue;
			float           estimatedSecondsRemaining   = secondsPerValue * (maximumToAttain-newValue);
			
			NSBundle        *classBundle                = [NSBundle bundleForClass:[self class]];
			NSString        *timeRemainingLabel         = [classBundle localizedStringForKey:@"Estimated time remaining:" value:nil table:nil]; //searches Localizable.strings
			NSString        *unitsForTimeRemaining      = nil;
			int             numberUnitsRemaining        = 0;
			
			if(estimatedSecondsRemaining < 2){
				unitsForTimeRemaining = [classBundle localizedStringForKey:@"second" value:nil table:nil];
				numberUnitsRemaining = 1;
			}
			else if(estimatedSecondsRemaining < 60){
				unitsForTimeRemaining = [classBundle localizedStringForKey:@"seconds" value:nil table:nil];
				numberUnitsRemaining = estimatedSecondsRemaining; //will round due to float->int conversion
			}
			else if(estimatedSecondsRemaining < 120){
				unitsForTimeRemaining = [classBundle localizedStringForKey:@"minute" value:nil table:nil];
				numberUnitsRemaining = 1;
			}
			else{
				unitsForTimeRemaining = [classBundle localizedStringForKey:@"minutes" value:nil table:nil];
				numberUnitsRemaining = estimatedSecondsRemaining / 60; //converts to minutes
			}
			
			[progressBar setDoubleValue:progressAmount];
			[timeRemaining setStringValue:[NSString stringWithFormat:@"%@ %d %@", timeRemainingLabel, numberUnitsRemaining, unitsForTimeRemaining]];
			
			//We just updated.
			previousUpdateTime = [NSDate date];
			
			[dialogWindow displayIfNeeded];
			
		}
	
	}
	
	//We have finished the progress.
	else{
		[timeRemaining setStringValue:@""];
		
		if(endsIndeterminate == YES)
			[progressBar setIndeterminate:YES];
			
		[dialogWindow displayIfNeeded];
	}
	
}//end setValue:


//========== increment =========================================================
//
// Purpose:		Increments the value of the bar by 1. This only causes a redraw 
//				if the updateInterval has already elapsed.
//
//==============================================================================
- (void) increment
{
	[self setValue: progressAmount+1 ];
}


//========== setMinValue: ======================================================
//
// Purpose:		Sets the smallest number displayed by the progress bar (the 
//				left-hand side).
//
//==============================================================================
- (void) setMinValue:(double)newValue
{
	[progressBar setMinValue:newValue];
}


//========== setMaxValue: ======================================================
//
// Purpose:		Sets the progress bar maximum.
//
//==============================================================================
- (void) setMaxValue:(double)newValue
{
	[progressBar setMaxValue:newValue];
}


//========== setMessage: =======================================================
//
// Purpose:		Sets the progress bar maximum.
//
//==============================================================================
- (void) setMessage:(NSString *)message
{
	[explanatoryText setStringValue:message];
}


//========== setShowsTimeRemaining: ============================================
//
// Purpose:		Activates the feature whereby the progress bar attempts to 
//				calculate how long it has been going.
//
//==============================================================================
- (void) setShowsTimeRemaining:(BOOL)flag;
{
	[timeRemaining setHidden:flag];
}


//========== setBecomesIndeterminateWhenCompleted: =============================
//
// Purpose:		If flag is yes, the progress bar will switch to indeterminate 
//				mode when it is complete.
//
//==============================================================================
- (void) setBecomesIndeterminateWhenCompleted:(BOOL)flag
{
	endsIndeterminate = flag;
}

//========== setUpdateFrequency: ===============================================
//
// Purpose:		Hyperactive progress bars chew up huge amounts of processing 
//				power. It's far better to restrict them to updating only a few 
//				times per second.
//
//				Pass 0 to update whenever setValue: is called.
//				Otherwise, setValue: has no effect unless updateInterval seconds 
//					have passed since the last call to setValue:
//
//==============================================================================
- (void) setUpdateFrequency:(NSTimeInterval)updateInterval
{
	timeBetweenUpdates = updateInterval;
}


#pragma mark -
#pragma mark Actions
#pragma mark -

//========== showProgressPanel =================================================
//
// Purpose:		Shows the progress bar as a non-modal window that floats above
//				most other windows.
//
//==============================================================================
- (void) showProgressPanel
{
	//record the start time used for estimating time remaining
	startTime = [NSDate date]; //right now
	
	runningAsSheet = NO;
	[dialogWindow setLevel:NSModalPanelWindowLevel]; //floats above normal windows.
	[dialogWindow makeKeyAndOrderFront:self];
	
//	[self->progressBar startAnimation:self];

}//end showProgressPanel


//========== showAsSheetForWindow: =============================================
//
// Purpose: brings up the progress bar window as a sheet on parentWindow
//			No mechanism exists here to actually close the sheet!
//
//==============================================================================
- (void) showAsSheetForWindow:(NSWindow *)parentWindow
{
	//record the start time used for estimating time remaining
	startTime = [NSDate date]; //right now
	runningAsSheet = YES;
	
	[NSApp beginSheet:dialogWindow
	   modalForWindow:parentWindow 
		modalDelegate:self 
	   didEndSelector:nil
		  contextInfo:nil ];
}


//========== close =============================================================
//
// Purpose:		Closes the panel.
//
//==============================================================================
- (void) close
{
	if(runningAsSheet == YES)
	{
		//if you don't end the sheet, you can never make another sheet. Eeek!
		[NSApp endSheet:dialogWindow];
		runningAsSheet = NO;		
	}
	//Close the window no matter what.
	[dialogWindow orderOut:self];
	
}//end close


#pragma mark -
#pragma mark Destructor
#pragma mark -

//========== dealloc ===========================================================
//==============================================================================
- (void) dealloc
{
	//Release top-level nib objects
	[dialogWindow release];
	
	//Finish deallocation
	[super dealloc];
}


@end
