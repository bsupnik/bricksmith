//==============================================================================
//
// File:		LDrawPathNames.h
//
// Purpose:		Constant names of standard LDraw files or folders.
//
// Modified:	05/03/2011 Allen Smith. Creation Date.
//
//==============================================================================
#ifndef LDrawPathNames_h
#define LDrawPathNames_h

////////////////////////////////////////////////////////////////////////////////
//
// Folder Names
//
////////////////////////////////////////////////////////////////////////////////
#define LDRAW_DIRECTORY_NAME					@"LDraw"

#define PRIMITIVES_DIRECTORY_NAME				@"p"
	#define PRIMITIVES_48_DIRECTORY_NAME		@"48"

#define PARTS_DIRECTORY_NAME					@"parts" //match case of LDraw.org complete distribution zip package.
	#define SUBPARTS_DIRECTORY_NAME				@"s"
	
#define TEXTURES_DIRECTORY_NAME					@"textures"

#define UNOFFICIAL_DIRECTORY_NAME				@"Unofficial"


////////////////////////////////////////////////////////////////////////////////
//
// File Names
//
////////////////////////////////////////////////////////////////////////////////

#define LDCONFIG								@"LDConfig"
#define LDCONFIG_EXTENSION						@"ldr"
#define LDCONFIG_FILE_NAME						LDCONFIG @"." LDCONFIG_EXTENSION

#define MLCAD									@"MLCad"
#define MLCAD_EXTENSION							@"ini"
#define MLCAD_INI_FILE_NAME						MLCAD @"." MLCAD_EXTENSION

#define PART_CATALOG_NAME						@"Bricksmith Parts.plist"

#endif