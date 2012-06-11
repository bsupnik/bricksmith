//==============================================================================
//
// File:		Inspector.h
//
// Purpose:		Manages the flow of the inspection system in the application.
//
//  Created by Allen Smith on 2/25/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@class ObjectInspectionController;

@interface Inspector : NSObject {

	IBOutlet	NSPanel		*inspectorPanel;		//the main window.
				NSString	*emptyInspectorTitle;	//window title for empty selection
				NSView		*emptyInspectorView;	//content view used for invalid inspections
	IBOutlet	NSTextField	*errorTextField;		//inside emptyInspectorView; use to explain the problem.
	
	ObjectInspectionController	*currentInspector;	//controller for the loaded inspector.
	
}

- (void) inspectObject:(id) object;
- (void) inspectObjects:(NSArray *) objects;
- (BOOL) loadInspectorForObject:(id) objectToInspect;
- (void) unloadInspector;
- (void) show:(id) sender;

@end
