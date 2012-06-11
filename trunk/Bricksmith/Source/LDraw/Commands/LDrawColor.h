//==============================================================================
//
// File:		LDrawColor.h
//
// Purpose:		Defines a LDraw color code and its attributes. These come from 
//				parsing !COLOUR directives in ldconfig.ldr. 
//
// Modified:	3/16/08 Allen Smith.
//
//==============================================================================
#import <Foundation/Foundation.h>
#import OPEN_GL_HEADER

#import "LDrawMetaCommand.h"

////////////////////////////////////////////////////////////////////////////////
//
// Enumeration:	LDrawColorT
//
// Purpose:		Provides named symbols for many commenly-accepted/official LDraw 
//				color codes. 
//
// Notes:		LDraw colors are defined by the ldconfig.ldr file distributed 
//				with LDraw. 
//
//				The list below is mainly a relic from the days before Bricksmith 
//				supported dynamic !COLOUR definitions, but it has been given a 
//				stay of execution due to the fact that it makes debugging 
//				prettier. Its maintenance is not guaranteed. 
//
//				LDrawColorBogus is not defined by LDraw.org; it is a 
//				Bricksmithism used for uninitialized or error colors. 
//
////////////////////////////////////////////////////////////////////////////////
typedef enum
{	
	LDrawColorBogus				= -1, //used for uninitialized colors.
	LDrawColorCustomRGB			= -2,

	LDrawBlack					= 0,
	LDrawBlue					= 1,
	LDrawGreen					= 2,
	LDrawTeal					= 3,
	LDrawRed					= 4,
	LDrawDarkPink				= 5,
	LDrawBrown					= 6,
	LDrawGray					= 7,
	LDrawDarkGray				= 8,
	LDrawLightBlue				= 9,
	LDrawBrightGreen			= 10,
	LDrawTurquiose				= 11,
	LDrawLightRed				= 12,
	LDrawPink					= 13,
	LDrawYellow					= 14,
	LDrawWhite					= 15,
	LDrawCurrentColor			= 16, //special non-color takes hue of whatever the previous color was.
	LDrawLightGreen				= 17,
	LDrawLightYellow			= 18,
	LDrawTan					= 19,
	LDrawLightViolet			= 20,
	LDrawPhosphorWhite			= 21,
	LDrawViolet					= 22,
	LDrawVioletBlue				= 23,
	LDrawEdgeColor				= 24, //special non-color contrasts the current color.
	LDrawOrange					= 25,
	LDrawMagenta				= 26,
	LDrawLime					= 27,
	LDrawDarkTan				= 28,
	LDrawTransBlue				= 33,
	LDrawTransGreen				= 34,
	LDrawTransRed				= 36,
	LDrawTransViolet			= 37,
	LDrawTransGray				= 40,
	LDrawTransLightCyan			= 41,
	LDrawTransFluLime			= 42,
	LDrawTransPink				= 45,
	LDrawTransYellow			= 46,
	LDrawClear					= 47,
	LDrawTransFluOrange			= 57,
	LDrawReddishBrown			= 70,
	LDrawStoneGray				= 71,
	LDrawDarkStoneGray			= 72,
	LDrawPearlCopper			= 134,
	LDrawPearlGray				= 135,
	LDrawPearlSandBlue			= 137,
	LDrawPearlGold				= 142,
	LDrawRubberBlack			= 256,
	LDrawDarkBlue				= 272,
	LDrawRubberBlue				= 273,
	LDrawDarkGreen				= 288,
	LDrawDarkRed				= 320,
	LDrawRubberRed				= 324,
	LDrawChromeGold				= 334,
	LDrawSandRed				= 335,
	LDrawEarthOrange			= 366,
	LDrawSandViolet				= 373,
	LDrawRubberGray				= 375,
	LDrawSandGreen				= 378,
	LDrawSandBlue				= 379,
	LDrawChromeSilver			= 383,
	LDrawLightOrange			= 462,
	LDrawDarkOrange				= 484,
	LDrawElectricContact		= 494,
	LDrawLightGray				= 503,
	LDrawRubberWhite			= 511
	
} LDrawColorT;


typedef enum LDrawColorMaterial
{
	LDrawColorMaterialNone			= 0,
	LDrawColorMaterialChrome		= 1,
	LDrawColorMaterialPearlescent	= 2,
	LDrawColorMaterialRubber		= 3,
	LDrawColorMaterialMatteMetallic	= 4,
	LDrawColorMaterialMetal			= 5,
	LDrawColorMaterialCustom		= 6,

} LDrawColorMaterialT;


////////////////////////////////////////////////////////////////////////////////
//
// Class:	LDrawColor
//
// Notes:	This does NOT conform to LDrawColorable, because we do not want 
//			color picker changes affecting the values of these objects. 
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawColor : LDrawMetaCommand
{
	LDrawColorT			 colorCode;
	GLfloat				 colorRGBA[4];		// range [0.0 - 1.0]
	LDrawColorT			 edgeColorCode;		// == LDrawColorBogus if not used
	GLfloat				 edgeColorRGBA[4];
	BOOL				 hasExplicitAlpha;
	BOOL				 hasLuminance;
	uint8_t				 luminance;
	LDrawColorMaterialT	 material;
	NSString			*materialParameters;
	NSString			*name;
	
	LDrawColor			*fakeComplimentColor;	// synthesized, not according to !COLOUR rules
}

// Initialization
+ (LDrawColor *) blendedColorForCode:(LDrawColorT)colorCode;

// Accessors

- (LDrawColorT)			colorCode;
- (LDrawColor *)		complimentColor;
- (LDrawColorT)			edgeColorCode;
- (void)				getColorRGBA:(GLfloat *)inComponents;
- (void)				getEdgeColorRGBA:(GLfloat *)inComponents;
- (NSString *)			localizedName;
- (uint8_t)				luminance;
- (LDrawColorMaterialT)	material;
- (NSString *)			materialParameters;
- (NSString *)			name;

- (void) setColorCode:(LDrawColorT)newCode;
- (void) setColorRGBA:(GLfloat *)newComponents;
- (void) setEdgeColorCode:(LDrawColorT)newCode;
- (void) setEdgeColorRGBA:(GLfloat *)newComponents;
- (void) setLuminance:(uint8_t)newValue;
- (void) setMaterial:(LDrawColorMaterialT)newValue;
- (void) setMaterialParameters:(NSString *)newValue;
- (void) setName:(NSString *)newName;

// Utilities
- (NSComparisonResult) HSVACompare:(LDrawColor *)otherColor;
- (NSString *) hexStringForRGB:(GLfloat *)components;
- (BOOL) scanHexString:(NSScanner *)hexScanner intoRGB:(GLfloat *)components;

@end
