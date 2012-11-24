//==============================================================================
//
// File:		ExtendedSplitView.m
//
// Purpose:		Fills in some of the many blanks Apple left in NSSplitView.
//
// Notes:		The blanks are less multitudinous in Leopard, so this class is 
//				essentially a no-op under that OS and its descendants.
//
//  Created by Allen Smith on 11/11/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "ExtendedSplitView.h"


@implementation ExtendedSplitView

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== autosaveName ======================================================
//
// Purpose:		Returns the name under which this SplitView is configured to 
//				save itself to preferences.
//
// Notes:		Obsolete under Leopard.
//
//==============================================================================
- (NSString *) autosaveName
{
	// Use the Leopard implementation if we can.
	if([NSSplitView instancesRespondToSelector:@selector(autosaveName)])
	   return [super autosaveName];
	else
	   return self->autosaveName;
	   
}//end autosaveName


//========== setAutosaveName: ==================================================
//
// Purpose:		Sets the name under which this SplitView is configured to save 
//				itself to preferences. It will be saved automatically upon 
//				deallocation.
//
// Notes:		Obsolete under Leopard.
//
//==============================================================================
- (void) setAutosaveName:(NSString *)newName
{
	// Use the Leopard implementation if we can.
	if([NSSplitView instancesRespondToSelector:@selector(setAutosaveName:)])
	   [super setAutosaveName:newName];
	else
	{
		[newName retain];
		[self->autosaveName release];
		
		autosaveName = newName;
		
		// Automatically restore. This is what Apple is doing in Leopard.
		[self restoreConfiguration];
		
		// Start watching subviews here so we can autosave when the change size. 
		// They do not go through -didAddSubview: when being unarchived from a 
		// nib! 
		NSArray                 *subviews           = [self subviews];
		NSNotificationCenter    *notificationCenter = [NSNotificationCenter defaultCenter];
		NSUInteger              counter             = 0;
		for(counter = 0; counter < [subviews count]; counter++)
		{
			[notificationCenter addObserver:self
								   selector:@selector(subviewFrameDidChange:)
									   name:NSViewFrameDidChangeNotification
									 object:[subviews objectAtIndex:counter]];
		}
		
	}
}//end setAutosaveName:


#pragma mark -
#pragma mark PERSISTENCE
#pragma mark -

//========== restoreConfiguration ==============================================
//
// Purpose:		Restores the split view from preferences, if an autosave name 
//				has been set.
//
// Notes:		Obsolete under Leopard.
//
//==============================================================================
- (void) restoreConfiguration
{
	// Unnecessary under Leopard
	if([NSSplitView instancesRespondToSelector:@selector(setAutosaveName:)] == NO)
	{
		NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
		NSArray         *subviews       = [self subviews];
		NSView          *currentSubview = nil;
		NSRect          currentRect     = NSZeroRect;
		NSString        *rectString     = nil;
		NSMutableArray  *frameSizes     = nil;
		NSInteger       counter         = 0;
		
		if(self->autosaveName != nil)
		{
			frameSizes = [userDefaults objectForKey:self->autosaveName];
			if(frameSizes != nil && [subviews count] == [frameSizes count])
			{
				for(counter = 0; counter < [subviews count]; counter++)
				{
					currentSubview	= [subviews objectAtIndex:counter];
					rectString		= [frameSizes objectAtIndex:counter];
					currentRect		= NSRectFromString(rectString);
					
					//we have a BIG collapsing problem. The SplitView does not 
					// have a convenient -setCollapsed: method! We are going 
					// off this experimentally-verified result that the origin 
					// of a collapsed subview gets set to (1,000,000 , 1,000,000).
					// But if we just restore that frame, it WON'T WORK! Sooooo...
					// we set the size to 0, which forces it it out of view.
					if(NSMinX(currentRect) == 1e6 && NSMinY(currentRect) == 1e6)
					{
						currentRect.size.height = 0;
						currentRect.size.width = 0;
					}				   
					
					[currentSubview setFrame:currentRect];
				}
			}
		}
		
		//clean up our mess.
		[self adjustSubviews];
		
	//	subviews		= [self subviews];
	//	for(counter = 0; counter < [subviews count]; counter++){
	//		currentSubview	= [subviews objectAtIndex:counter];
	//		currentRect		= [currentSubview frame];
	//		rectString		= NSStringFromRect(currentRect);
	//		NSLog(@"%@", rectString);
	//	}
	//	NSLog(@"\n\n\n");
	}


}//end restoreConfiguration


//========== saveConfiguration =================================================
//
// Purpose:		Saves the splitview into preferences, provided an autosave name 
//				has been set.
//
// Notes:		Obsolete under Leopard.
//
//==============================================================================
- (void) saveConfiguration
{
	if(self->autosaveName != nil)
	{
		// Unnecessary under Leopard
		if([NSSplitView instancesRespondToSelector:@selector(setAutosaveName:)] == NO)
		{
			NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
			NSArray         *subviews       = [self subviews];
			NSView          *currentSubview = nil;
			NSRect          currentRect     = NSZeroRect;
			NSString        *rectString     = nil;
			NSMutableArray  *frameSizes     = [NSMutableArray array];
			NSInteger       counter         = 0;
			
			for(counter = 0; counter < [subviews count]; counter++)
			{
				currentSubview	= [subviews objectAtIndex:counter];
				currentRect		= [currentSubview frame];
				rectString		= NSStringFromRect(currentRect);
				[frameSizes addObject:rectString];
			}
			
			if(self->autosaveName != nil){
				[userDefaults setObject:frameSizes forKey:self->autosaveName];
			}
		}
	}
	
}//end saveConfiguration


#pragma mark -
#pragma mark TRACKING THESE WRETCHED THINGS
#pragma mark -

//========== subviewFrameDidChange: ============================================
//
// Purpose:		Split view autosaving in Leopard is triggered every time the 
//				view changes sizes, but not when it is deallocated. We need to 
//				mimic that behavior for Tiger in order to be compatible.
//
// Notes:		Other likely candidates, such as -adjustSubviews, don't work.
//
//==============================================================================
- (void) subviewFrameDidChange:(NSNotification *)notification
{
	[self saveConfiguration];
	
}//end subviewFrameDidChange:


//========== didAddSubview: ====================================================
//
// Purpose:		Hah! This won't be called when unpacking from a nib, but it's 
//				here for completeness! 
//
//==============================================================================
- (void) didAddSubview:(NSView *)subview
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	[super didAddSubview:subview];
	
	[notificationCenter addObserver:self
						   selector:@selector(subviewFrameDidChange:)
							   name:NSViewFrameDidChangeNotification
							 object:subview];
}//end didAddSubview:


//========== willRemoveSubview: ================================================
//
// Purpose:		If this class were used as a general-purpose object, this would 
//				be very important. I hope this class doesn't live that long.
//
//==============================================================================
- (void) willRemoveSubview:(NSView *)subview
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	[super willRemoveSubview:subview];
	
	[notificationCenter removeObserver:self name:NSViewFrameDidChangeNotification object:subview];
	
}//end willRemoveSubview:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Let's split!
//
//==============================================================================
- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
	
}//end dealloc

@end
