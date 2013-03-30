//==============================================================================
//
// File:		MacLDraw.h
//
// Purpose:		Keys, enumerations, and constants used in the Bricksmith 
//				project. 
//
// Notes:		Bricksmith was originally titled "Mac LDraw"; hence the name of 
//				this file. That name was dropped shortly before the 1.0 release 
//				because Tim Courtney said the LDraw name should be reserved for 
//				the Library itself, and I thought "Mac LDraw" was kinda boring. 
//
// Modified:	2/14/05 Allen Smith.
//
//==============================================================================


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Preferences Keys
//
////////////////////////////////////////////////////////////////////////////////

#define COLUMNIZE_OUTPUT_KEY						@"ColumnizeOutput"
#define DOCUMENT_WINDOW_SIZE						@"Document Window Size"
#define DONATION_SCREEN_LAST_VERSION_DISPLAYED		@"DonationRequestLastVersion"
#define DONATION_SCREEN_SUPPRESS_THIS_VERSION		@"DonationRequestSuppressThisVersion"
#define FAVORITE_PARTS_KEY							@"FavoriteParts"
#define FILE_CONTENTS_DRAWER_STATE					@"File Contents Drawer State" //obsolete
#define GRID_SPACING_COARSE							@"Grid Spacing: Coarse"
#define GRID_SPACING_FINE							@"Grid Spacing: Fine"
#define GRID_SPACING_MEDIUM							@"Grid Spacing: Medium"
#define LDRAW_GL_VIEW_ANGLE							@"LDrawGLView Viewing Angle"
#define LDRAW_GL_VIEW_PROJECTION					@"LDrawGLView Viewing Projection"
#define LDRAW_PATH_KEY								@"LDraw Path"
#define LDRAW_VIEWER_BACKGROUND_COLOR_KEY			@"LDraw Viewer Background Color"
#define MOUSE_DRAGGING_BEHAVIOR_KEY					@"Mouse Dragging Behavior"
#define RIGHT_BUTTON_BEHAVIOR_KEY					@"Right Button Behavior"
#define ROTATE_MODE_KEY								@"Rotate Mode"
#define MOUSE_WHEEL_BEHAVIOR_KEY					@"Mouse Wheel Behavior"
#define PART_BROWSER_DRAWER_STATE					@"Part Browser Drawer State"
#define PART_BROWSER_PANEL_SHOW_AT_LAUNCH			@"Part Browser Panel Show at Launch"
#define PART_BROWSER_PREVIOUS_CATEGORY				@"Part Browser Previous Category"
#define PART_BROWSER_PREVIOUS_SELECTED_ROW			@"Part Browser Previous Selected Row"
#define PART_BROWSER_SEARCH_MODE					@"Part Browser Search Mode"
#define PART_BROWSER_STYLE_KEY						@"Part Browser Style"
#define PREFERENCES_LAST_TAB_DISPLAYED				@"Preferences Tab"
#define SYNTAX_COLOR_COLORS_KEY						@"Syntak Color Colors"
#define SYNTAX_COLOR_COMMENTS_KEY					@"Syntax Color Comments"
#define SYNTAX_COLOR_MODELS_KEY						@"Syntax Color Models"
#define SYNTAX_COLOR_PARTS_KEY						@"Syntax Color Parts"
#define SYNTAX_COLOR_PRIMITIVES_KEY					@"Syntax Color Primitives"
#define SYNTAX_COLOR_STEPS_KEY						@"Syntax Color Steps"
#define SYNTAX_COLOR_UNKNOWN_KEY					@"Syntax Color Unknown"
#define TOOL_PALETTE_HIDDEN							@"Tool Palette Hidden"
#define VIEWPORTS_EXPAND_TO_AVAILABLE_SIZE			@"ViewportsExpandToAvailableSize"

// LSynth
#define LSYNTH_EXECUTABLE_PATH_KEY                  @"LSynth Executable Path"
#define LSYNTH_CONFIGURATION_PATH_KEY               @"LSynth Configuration Path"
#define LSYNTH_SELECTION_TRANSPARENCY_KEY           @"LSynth Selection Transparency"
#define LSYNTH_SELECTION_COLOR_KEY                  @"LSynth Selection Color"
#define LSYNTH_SELECTION_MODE_KEY                   @"LSynth Selection Mode"
#define LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY           @"LSynth Save Synthesized Parts"

#define MINIFIGURE_HAS_HAT							@"Minifigure Has Hat"
#define MINIFIGURE_HAS_HEAD							@"Minifigure Has Head"
#define MINIFIGURE_HAS_NECK							@"Minifigure Has Neck"
#define MINIFIGURE_HAS_TORSO						@"Minifigure Has Torso"
#define MINIFIGURE_HAS_ARM_RIGHT					@"Minifigure Has Arm Right"
#define MINIFIGURE_HAS_ARM_LEFT						@"Minifigure Has Arm Left"
#define MINIFIGURE_HAS_HAND_RIGHT					@"Minifigure Has Hand Right"
#define MINIFIGURE_HAS_HAND_RIGHT_ACCESSORY			@"Minifigure Has Hand Right Accessory"
#define MINIFIGURE_HAS_HAND_LEFT					@"Minifigure Has Hand Left"
#define MINIFIGURE_HAS_HAND_LEFT_ACCESSORY			@"Minifigure Has Hand Left Accessory"
#define MINIFIGURE_HAS_HIPS							@"Minifigure Has Hips"
#define MINIFIGURE_HAS_LEG_RIGHT					@"Minifigure Has Leg Right"
#define MINIFIGURE_HAS_LEG_RIGHT_ACCESSORY			@"Minifigure Has Leg Right Accessory"
#define MINIFIGURE_HAS_LEG_LEFT						@"Minifigure Has Leg Left"
#define MINIFIGURE_HAS_LEG_LEFT_ACCESSORY			@"Minifigure Has Leg Left Accessory"

#define MINIFIGURE_PARTNAME_HAT						@"Minifigure Partname Hat"
#define MINIFIGURE_PARTNAME_HEAD					@"Minifigure Partname Head"
#define MINIFIGURE_PARTNAME_NECK					@"Minifigure Partname Neck"
#define MINIFIGURE_PARTNAME_TORSO					@"Minifigure Partname Torso"
#define MINIFIGURE_PARTNAME_ARM_RIGHT				@"Minifigure Partname Arm Right"
#define MINIFIGURE_PARTNAME_ARM_LEFT				@"Minifigure Partname Arm Left"
#define MINIFIGURE_PARTNAME_HAND_RIGHT				@"Minifigure Partname Hand Right"
#define MINIFIGURE_PARTNAME_HAND_RIGHT_ACCESSORY	@"Minifigure Partname Hand Right Accessory"
#define MINIFIGURE_PARTNAME_HAND_LEFT				@"Minifigure Partname Hand Left"
#define MINIFIGURE_PARTNAME_HAND_LEFT_ACCESSORY		@"Minifigure Partname Hand Left Accessory"
#define MINIFIGURE_PARTNAME_HIPS					@"Minifigure Partname Hips"
#define MINIFIGURE_PARTNAME_LEG_RIGHT				@"Minifigure Partname Leg Right"
#define MINIFIGURE_PARTNAME_LEG_RIGHT_ACCESSORY		@"Minifigure Partname Leg Right Accessory"
#define MINIFIGURE_PARTNAME_LEG_LEFT				@"Minifigure Partname Leg Left"
#define MINIFIGURE_PARTNAME_LEG_LEFT_ACCESSORY		@"Minifigure Partname Leg Left Accessory"

#define MINIFIGURE_ANGLE_HAT						@"Minifigure Angle Hat"
#define MINIFIGURE_ANGLE_HEAD						@"Minifigure Angle Head"
#define MINIFIGURE_ANGLE_NECK						@"Minifigure Angle Neck"
#define MINIFIGURE_ANGLE_TORSO						@"Minifigure Angle Torso"
#define MINIFIGURE_ANGLE_ARM_RIGHT					@"Minifigure Angle Arm Right"
#define MINIFIGURE_ANGLE_ARM_LEFT					@"Minifigure Angle Arm Left"
#define MINIFIGURE_ANGLE_HAND_RIGHT					@"Minifigure Angle Hand Right"
#define MINIFIGURE_ANGLE_HAND_RIGHT_ACCESSORY		@"Minifigure Angle Hand Right Accessory"
#define MINIFIGURE_ANGLE_HAND_LEFT					@"Minifigure Angle Hand Left"
#define MINIFIGURE_ANGLE_HAND_LEFT_ACCESSORY		@"Minifigure Angle Hand Left Accessory"
#define MINIFIGURE_ANGLE_HIPS						@"Minifigure Angle Hips"
#define MINIFIGURE_ANGLE_LEG_RIGHT					@"Minifigure Angle Leg Right"
#define MINIFIGURE_ANGLE_LEG_RIGHT_ACCESSORY		@"Minifigure Angle Leg Right Accessory"
#define MINIFIGURE_ANGLE_LEG_LEFT					@"Minifigure Angle Leg Left"
#define MINIFIGURE_ANGLE_LEG_LEFT_ACCESSORY			@"Minifigure Angle Leg Left Accessory"

#define MINIFIGURE_COLOR_HAT						@"Minifigure Color Hat"
#define MINIFIGURE_COLOR_HEAD						@"Minifigure Color Head"
#define MINIFIGURE_COLOR_NECK						@"Minifigure Color Neck"
#define MINIFIGURE_COLOR_TORSO						@"Minifigure Color Torso"
#define MINIFIGURE_COLOR_ARM_RIGHT					@"Minifigure Color Arm Right"
#define MINIFIGURE_COLOR_ARM_LEFT					@"Minifigure Color Arm Left"
#define MINIFIGURE_COLOR_HAND_RIGHT					@"Minifigure Color Hand Right"
#define MINIFIGURE_COLOR_HAND_RIGHT_ACCESSORY		@"Minifigure Color Hand Right Accessory"
#define MINIFIGURE_COLOR_HAND_LEFT					@"Minifigure Color Hand Left"
#define MINIFIGURE_COLOR_HAND_LEFT_ACCESSORY		@"Minifigure Color Hand Left Accessory"
#define MINIFIGURE_COLOR_HIPS						@"Minifigure Color Hips"
#define MINIFIGURE_COLOR_LEG_RIGHT					@"Minifigure Color Leg Right"
#define MINIFIGURE_COLOR_LEG_RIGHT_ACCESSORY		@"Minifigure Color Leg Right Accessory"
#define MINIFIGURE_COLOR_LEG_LEFT					@"Minifigure Color Leg Left"
#define MINIFIGURE_COLOR_LEG_LEFT_ACCESSORY			@"Minifigure Color Leg Left Accessory"

#define MINIFIGURE_HEAD_ELEVATION					@"Minifigure Head Elevation"


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Drawing Mask bits and Constants
//
////////////////////////////////////////////////////////////////////////////////
#define DRAW_NO_OPTIONS							0
#define DRAW_BOUNDS_ONLY						1 << 3

//Number of degrees to rotate in each grid mode.
#define GRID_ROTATION_FINE						15
#define GRID_ROTATION_MEDIUM					45
#define GRID_ROTATION_COARSE					90


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Notifications
//
////////////////////////////////////////////////////////////////////////////////

//The color which will be assigned to new parts has changed.
// Object is the new LDrawColorT, as an NSNumber. No userInfo.
#define LDrawColorDidChangeNotification					@"LDrawColorDidChangeNotification"

//the keys on the keyboard which were depressed just changed.
// Object is an NSEvent: keyUp, keyDown, or flagsChanged.
#define LDrawKeyboardDidChangeNotification				@"LDrawKeyboardDidChangeNotification"

//tool mode changed.
// Object is an NSNumber containing the new ToolModeT.
#define LDrawMouseToolDidChangeNotification				@"LDrawMouseToolDidChangeNotification"

//tablet pointing device changed.
// Object is an NSEvent: NSTabletProximity.
#define LDrawPointingDeviceDidChangeNotification		@"LDrawPointingDeviceDidChangeNotification"

//Part Browser should be shown a different way.
// Object is NSNumber of new style. No userInfo.
#define LDrawPartBrowserStyleDidChangeNotification		@"LDrawPartBrowserStyleDidChangeNotification"

//Syntax coloring changed in preferences.
// Object is the application. No userInfo.
#define LDrawSyntaxColorsDidChangeNotification			@"LDrawSyntaxColorsDidChangeNotification"

//Syntax coloring changed in preferences.
// Object is the new color. No userInfo.
#define LDrawViewBackgroundColorDidChangeNotification	@"LDrawViewBackgroundColorDidChangeNotification"

//A model was added to a document.  Note that the object
// for this notification is the LDrawFile that was edited!
#define LDrawMPDSubModelAdded							@"LDrawMPDSubModelAdded"

//The library was reloaded.  Documents need to tell their parts
// to re-resolve their references.
#define LDrawPartLibraryReloaded						@"LDrawPartLibraryReloaded"

// The LSynth selection criteria changed.  Selected LSynth
// parts need to update to reflect this
#define LSynthSelectionDisplayDidChangeNotification    @"LSynthSelectionDisplayDidChangeNotification"

////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Menu Tags
//
// Tags to look up menus with.
//
////////////////////////////////////////////////////////////////////////////////

typedef enum MenuTags
{
	// Application Menu
	applicationMenuTag				= 0,
	
	// File Menu
	fileMenuTag						= 1,
    revealInFinderTag               = 101,
	
	// Edit Menu
	editMenuTag						= 2,
	cutMenuTag						= 202,
	copyMenuTag						= 203,
	pasteMenuTag					= 204,
	deleteMenuTag					= 205,
	selectAllMenuTag				= 206,
	duplicateMenuTag				= 207,
	rotatePositiveXTag				= 220,
	rotateNegativeXTag				= 221,
	rotatePositiveYTag				= 222,
	rotateNegativeYTag				= 223,
	rotatePositiveZTag				= 224,
	rotateNegativeZTag				= 225,
	
	// Tools Menu
	toolsMenuTag					= 3,
	fileContentsMenuTag				= 302,
	showMouseToolsMenuTag			= 303,
	hideMouseToolsMenuTag			= 304,
	gridFineMenuTag					= 305,
	gridMediumMenuTag				= 306,
	gridCoarseMenuTag				= 307,
	
	// Views Menu
	viewsMenuTag					= 4,
	stepDisplayMenuTag				= 404,
	nextStepMenuTag					= 405,
	previousStepMenuTag				= 406,
	orientationMenuTag				= 407,
	useSelectionForSpinCenterMenuTag= 408,
	resetSpinCenterMenuTag			= 409,
	
	// Piece Menu
	pieceMenuTag					= 5,
	hidePieceMenuTag				= 501,
	showPieceMenuTag				= 502,
	snapToGridMenuTag				= 503,
	
	// Models Menu
	modelsMenuTag					= 6,
	addModelMenuTag					= 601,
	modelsSeparatorMenuTag			= 602,
	insertReferenceMenuTag			= 603,
	submodelReferenceMenuTag		= 604, //used for all items in the Insert Reference menu.
	rawCommandMenuTag               = 605,
    lsynthMenuTag                   = 606,
    lsynthPartMenuTag               = 607, // LSynth parts
    lsynthSynthesizableMenuTag      = 608, // LSynth synthesizable part: band, hose etc.
    lsynthConstraintMenuTag         = 609, // LSynth constraint items
    lsynthSurroundINSIDEOUTSIDETag  = 630,
    lsynthInvertINSIDEOUTSIDETag    = 631,
    lsynthInsertINSIDETag           = 632,
    lsynthInsertOUTSIDETag          = 633,
    lsynthInsertCROSSTag            = 634,


	// Window Menu
	windowMenuTag					= 7,
	
	// Contextual Menus
	partBrowserAddFavoriteTag		= 4001,
	partBrowserRemoveFavoriteTag	= 4002
	
} menuTagsT;


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Shared Datatypes
//
// Data types which would otherwise be homeless
//
////////////////////////////////////////////////////////////////////////////////

typedef enum MouseDragBehavior
{
	MouseDraggingOff									= 0,
	MouseDraggingBeginImmediately						= 1,
	MouseDraggingBeginAfterDelay						= 2,
	MouseDraggingImmediatelyInOrthoNeverInPerspective	= 3
	

} MouseDragBehaviorT;

typedef enum RightButtonBehavior
{
	RightButtonContextual								= 0,
	RightButtonRotates									= 1

} RightButtonBehaviorT;

typedef enum RotateMode {
	RotateModeTrackball									= 0,
	RotateModeTurntable									= 1

} RotateModeT;

typedef enum MouseWheelBeahvior {
	MouseWheelScrolls									= 0,
	MouseWheelZooms										= 1

} MouseWheelBeahviorT;

typedef enum PartBrowserStyle
{
	PartBrowserShowAsDrawer	= 0,
	PartBrowserShowAsPanel	= 1

} PartBrowserStyleT;


typedef enum SearchMode
{
	SearchModeAllCategories	= 0,
	SearchModeSelectedCategory = 1

} SearchModeT;


typedef enum SelectionMode {
	
	SelectionReplace		= 0,			// Normal drag - take new
	SelectionExtend			= 1,			// Shift drag - take old | new
	SelectionSubtract		= 2,			// Option drag - take old - new
	SelectionIntersection	= 3				// Option-shift drag - take old & new
	
} SelectionModeT;


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Pasteboards
//
// Names of pasteboard types that Bricksmith uses to transfer data internally.
//
////////////////////////////////////////////////////////////////////////////////

//Used for dragging within the File Contents outline. Contains an array of 
// LDrawDirectives stored as NSData objects. There should be no duplication of 
// objects.
#define LDrawDirectivePboardType				@"LDrawDirectivePboardType"

//Used for dragging parts around in or between viewports. Contains an array of 
// LDrawDirectives stored as NSData objects. There should be no duplication of 
// objects.
#define LDrawDraggingPboardType					@"LDrawDraggingPboardType"

// Contains a Vector3 as NSData indicating the offset between the click location 
// which originated the drag and the position of the first dragged directive. 
#define LDrawDraggingInitialOffsetPboardType	@"LDrawDraggingInitialOffsetPboardType"

// Contains a BOOL indicating the dragging directive has never been part of a 
// model before.  
#define LDrawDraggingIsUninitializedPboardType	@"LDrawDraggingIsUninitializedPboardType"

//Contains an array of indexes for the original objects being drug.
// Since the objects are converted to data when placed on the 
// LDrawDirectivePboardType (effectively copying them), these source indexes 
// must be used to delete the original objects after the copies have been 
// deposited in their new destination.
#define LDrawDragSourceRowsPboardType			@"LDrawDragSourceRowsPboardType"

#define LDrawDisallowDragToSourcePboardType		@"LDrawDisallowDragToSourcePboardType"

