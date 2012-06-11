//==============================================================================
//
// File:		LDrawKeywords.h
//
// Purpose:		Strings which are absolute syntax of LDraw commands.
//
// Modified:	04/30/2011 Allen Smith. Creation Date.
//
//==============================================================================
#ifndef LDrawKeywords_h
#define LDrawKeywords_h

// Structure
#define LDRAW_MPD_FILE_START_MARKER				@"0 FILE"
#define LDRAW_MPD_FILE_END_MARKER				@"0 NOFILE"
#define LDRAW_STEP								@"0 STEP"

//Comment markers
#define LDRAW_COMMENT_WRITE						@"WRITE"
#define LDRAW_COMMENT_PRINT						@"PRINT"
#define LDRAW_COMMENT_SLASH						@"//"

// Color definition
#define LDRAW_COLOR_DEFINITION					@"!COLOUR"
#define LDRAW_COLOR_DEF_CODE					@"CODE"
#define LDRAW_COLOR_DEF_VALUE					@"VALUE"
#define LDRAW_COLOR_DEF_EDGE					@"EDGE"
#define LDRAW_COLOR_DEF_ALPHA					@"ALPHA"
#define LDRAW_COLOR_DEF_LUMINANCE				@"LUMINANCE"
#define LDRAW_COLOR_DEF_MATERIAL_CHROME			@"CHROME"
#define LDRAW_COLOR_DEF_MATERIAL_PEARLESCENT	@"PEARLESCENT"
#define LDRAW_COLOR_DEF_MATERIAL_RUBBER			@"RUBBER"
#define LDRAW_COLOR_DEF_MATERIAL_MATTE_METALLIC	@"MATTE_METALLIC"
#define LDRAW_COLOR_DEF_MATERIAL_METAL			@"METAL"
#define LDRAW_COLOR_DEF_MATERIAL_CUSTOM			@"MATERIAL"

// Model header
#define LDRAW_HEADER_NAME						@"Name:"
#define LDRAW_HEADER_AUTHOR						@"Author:"
#define LDRAW_HEADER_OFFICIAL_MODEL				@"LDraw.org Official Model Repository"
#define LDRAW_HEADER_UNOFFICIAL_MODEL			@"Unofficial Model"

// Rotation Steps
#define LDRAW_ROTATION_STEP						@"0 ROTSTEP"
#define LDRAW_ROTATION_END						@"END"
#define LDRAW_ROTATION_RELATIVE					@"REL"
#define LDRAW_ROTATION_ABSOLUTE					@"ABS"
#define LDRAW_ROTATION_ADDITIVE					@"ADD"

// Important Categories
#define LDRAW_MOVED_CATEGORY					@"Moved"
#define LDRAW_MOVED_DESCRIPTION_PREFIX			@"~Moved to"

#endif