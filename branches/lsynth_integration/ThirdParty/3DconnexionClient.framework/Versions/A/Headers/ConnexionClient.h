//==============================================================================

#ifndef _H_connexionclient
#define _H_connexionclient

//==============================================================================
#ifdef __cplusplus
extern "C" {
#endif
//==============================================================================
#pragma pack(push,2)
//==============================================================================
// Client registration modes

// Use kConnexionClientWildcard ('****') as the application signature in the
// RegisterConnexionClient API to take over the device system-wide in all
// applications:

#define kConnexionClientWildcard		0x2A2A2A2A

// There are two plugin operating modes: one takes over the device
// and disables all built-in driver assignments, the other complements
// the driver by only executing commands that are meant for plugins:

enum {
	kConnexionClientModeTakeOver		= 1,		// take over device completely, driver no longer executes assignments
	kConnexionClientModePlugin			= 2			// receive plugin assignments only, let driver take care of its own
};

//==============================================================================
// Client commands

// The following assignments must be executed by the client:

enum {
	kConnexionCmdNone					= 0,
	kConnexionCmdHandleRawData			= 1,
	kConnexionCmdHandleButtons			= 2,
	kConnexionCmdHandleAxis				= 3,
	
	kConnexionCmdAppSpecific			= 10
};

//==============================================================================
// Messages

// IOServiceOpen and newUserClient client type:

#define kConnexionUserClientType		'3dUC'		// used to create our user client when needed, and the IOHIDDevice one otherwise

// The following messages are sent from the Kernel driver to user space clients:

#define kConnexionMsgDeviceState		'3dSR'		// forwarded device state data
#define kConnexionMsgPrefsChanged		'3dPC'		// notify clients that the current app prefs have changed
#define kConnexionMsgDoAction			'3dDA'		// execute an action through the user space helper (should be ignored by clients)

// Control messages for the kernel driver sent via the ConnexionControl API:

#define kConnexionCtlSetLEDState		'3dsl'		// set the LED state, param = (UInt8)ledState
#define kConnexionCtlGetDeviceID		'3did'		// get vendorID and productID in the high and low words of the result
#define kConnexionCtlTypeKeystroke		'3dke'		// type a keystroke, param = ((modifiers << 16) | (keyCode << 8) | charCode)
#define kConnexionCtlRollWheel			'3dro'		// roll the mouse wheel, param = ((modifiers << 16) | (direction << 8) | amount) - note that modifier keys are NOT released
#define kConnexionCtlReleaseMods		'3dre'		// release modifier keys, param = (modifiers << 16)
#define kConnexionCtlCalibrate			'3dca'		// calibrate the device with the current axes values (same as executing the calibrate assignment)
#define kConnexionCtlUncalibrate		'3dde'		// uncalibrate the device (i.e. reset calibration to 0,0,0,0,0,0)

#define kConnexionCtlOpenPrefPane		'3dop'		// open the 3dconnexion preference pane in System Preferences
#define kConnexionCtlSetSwitches		'3dss'		// set the current state of the client-controlled feature switches (bitmap, see masks below)

// Client capability mask constants (this mask defines which buttons and controls should be sent to clients, the others are handled by the driver)

#define kConnexionMaskButton1			0x0001
#define kConnexionMaskButton2			0x0002
#define kConnexionMaskButton3			0x0004
#define kConnexionMaskButton4			0x0008
#define kConnexionMaskButton5			0x0010
#define kConnexionMaskButton6			0x0020
#define kConnexionMaskButton7			0x0040
#define kConnexionMaskButton8			0x0080

#define kConnexionMaskAxis1				0x0100
#define kConnexionMaskAxis2				0x0200
#define kConnexionMaskAxis3				0x0400
#define kConnexionMaskAxis4				0x0800
#define kConnexionMaskAxis5				0x1000
#define kConnexionMaskAxis6				0x2000

#define kConnexionMaskButtons			0x00FF
#define kConnexionMaskAxisTrans			0x0700
#define kConnexionMaskAxisRot			0x3800
#define kConnexionMaskAxis				0x3F00
#define kConnexionMaskAll				0x3FFF

// Masks for client-controlled feature switches

#define kConnexionSwitchZoomOnY			0x0001
#define kConnexionSwitchDominant		0x0002
#define kConnexionSwitchEnableAxis1		0x0004
#define kConnexionSwitchEnableAxis2		0x0008
#define kConnexionSwitchEnableAxis3		0x0010
#define kConnexionSwitchEnableAxis4		0x0020
#define kConnexionSwitchEnableAxis5		0x0040
#define kConnexionSwitchEnableAxis6		0x0080
#define kConnexionSwitchReverseAxis1	0x0100
#define kConnexionSwitchReverseAxis2	0x0200
#define kConnexionSwitchReverseAxis3	0x0400
#define kConnexionSwitchReverseAxis4	0x0800
#define kConnexionSwitchReverseAxis5	0x1000
#define kConnexionSwitchReverseAxis6	0x2000

#define kConnexionSwitchEnableTrans		0x001C
#define kConnexionSwitchEnableRot		0x00E0
#define kConnexionSwitchEnableAll		0x00FC
#define kConnexionSwitchReverseTrans	0x0700
#define kConnexionSwitchReverseRot		0x3800
#define kConnexionSwitchReverseAll		0x3F00

#define kConnexionSwitchesDisabled		0x80000000	// use driver defaults instead of client-controlled switches

//==============================================================================
// Device state record

// Structure type and current version:

#define kConnexionDeviceStateType		0x4D53		// 'MS' (Connexion State)
#define kConnexionDeviceStateVers		0x6D32		// 'm2' (version 2)

// This structure is used to forward device data and commands from the kext to the client:

typedef struct {
// header
	UInt16		version;							// kConnexionDeviceStateVers
	UInt16		client;								// identifier of the target client when sending a state message to all user clients
// command
	UInt16		command;							// command for the user-space client
	SInt16		param;								// optional parameter for the specified command
	SInt32		value;								// optional value for the specified command
	UInt64		time;								// timestamp for this message (clock_get_uptime)
// raw report
	UInt8		report[8];							// raw USB report from the device
// processed data
	UInt16		buttons;							// buttons
	SInt16		axis[6];							// x, y, z, rx, ry, rz
// reserved for future use
	UInt16		address;							// USB device address, used to tell one device from the other
	UInt32		reserved2;							// set to 0
} ConnexionDeviceState, *ConnexionDeviceStatePtr;

// Size of the above structure:

#define kConnexionDeviceStateSize (sizeof(ConnexionDeviceState))

//==============================================================================
// Device IDs for 3Dconnexion devices with separate and different preferences

#define kDevID_SpaceNavigator			0x00
#define kDevID_SpaceNavigatorNB			0x01
#define kDevID_SpaceExplorer			0x02
#define kDevID_Count					3			// number of device IDs
#define kDevID_AnyDevice				0x7FFF		// widcard used to specify any available device

//==============================================================================
// Device prefs record

// Structure type and current version:

#define kConnexionDevicePrefsType		0x4D50		// 'MP' (Connexion Prefs)
#define kConnexionDevicePrefsVers		0x7031		// 'p1' (version 1)

// This structure is used to retrieve the current device prefs from the helper:

typedef struct {
// header
	UInt16					type;					// kConnexionDevicePrefsType
	UInt16					version;				// kConnexionDevicePrefsVers
	UInt16					deviceID;				// device ID (SpaceNavigator, SpaceNavigatorNB, SpaceExplorer...)
	UInt16					reserved1;				// set to 0
// target application
	UInt32					appSignature;			// target application signature
	UInt32					reserved2;				// set to 0
	UInt8					appName[64];			// target application name (Pascal string with length byte at the beginning)
// device preferences
	UInt8					mainSpeed;				// overall speed
	UInt8					zoomOnY;				// use Y axis for zoom, Z axis for un/down pan
	UInt8					dominant;				// only respond to the largest one of all 6 axes values at any given time
	UInt8					reserved3;				// set to 0
	SInt8					mapV[6];				// axes mapping when Zoom direction is on vertical axis (zoomOnY = 0)
	SInt8					mapH[6];				// axes mapping when Zoom direction is on horizontal axis (zoomOnY != 0)
	UInt8					enabled[6];				// enable or disable individual axes
	UInt8					reversed[6];			// reverse individual axes
	UInt8					speed[6];				// speed for individual axes (min 0, max 200, reserved 201-255)
	UInt8					sensitivity[6];			// sensitivity for individual axes (min 0, max 200, reserved 201-255)
	SInt32					scale[6];				// 10000 * scale and "natural" reverse state for individual axes
// reserved for future use
	UInt32					reserved4;				// set to 0
	UInt32					reserved5;				// set to 0
} ConnexionDevicePrefs, *ConnexionDevicePrefsPtr;

// Size of the above structure:

#define kConnexionDevicePrefsSize (sizeof(ConnexionDevicePrefs))

//==============================================================================
#pragma pack(pop)
//==============================================================================
#ifdef __cplusplus
}
#endif
//==============================================================================

#endif	// _H_connexionclient

//==============================================================================
