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

// MPD
#define LDRAW_MPD_SUBMODEL_START				@"FILE"
#define LDRAW_MPD_SUBMODEL_END					@"NOFILE"

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
#define LDRAW_CATEGORY							@"!CATEGORY"
#define LDRAW_KEYWORDS							@"!KEYWORDS"
#define LDRAW_ORG								@"!LDRAW_ORG"

// Steps and Rotation Steps
#define LDRAW_STEP_TERMINATOR					@"STEP"
#define LDRAW_ROTATION_STEP_TERMINATOR			@"ROTSTEP"
#define LDRAW_ROTATION_END						@"END"
#define LDRAW_ROTATION_RELATIVE					@"REL"
#define LDRAW_ROTATION_ABSOLUTE					@"ABS"
#define LDRAW_ROTATION_ADDITIVE					@"ADD"

// Textures
#define LDRAW_TEXTURE							@"!TEXMAP"
#define LDRAW_TEXTURE_GEOMETRY					@"!:"
#define LDRAW_TEXTURE_METHOD_PLANAR				@"PLANAR"
#define LDRAW_TEXTURE_START						@"START"
#define LDRAW_TEXTURE_NEXT						@"NEXT"
#define LDRAW_TEXTURE_FALLBACK					@"FALLBACK"
#define LDRAW_TEXTURE_END						@"END"
#define LDRAW_TEXTURE_GLOSSMAP					@"GLOSSMAP"

// Important Categories
#define LDRAW_MOVED_CATEGORY					@"Moved"
#define LDRAW_MOVED_DESCRIPTION_PREFIX			@"~Moved to"

// LSynth
#define LSYNTH_COMMAND                          @"SYNTH"
#define LSYNTH_SHOW                             @"SHOW"
#define LSYNTH_BEGIN                            @"BEGIN"
#define LSYNTH_END                              @"END"
#define LSYNTH_SYNTHESIZED                      @"SYNTHESIZED"

#endif