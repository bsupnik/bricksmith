//
// Created by rmacharg on 30/09/2012.
//
//
//


#import "LDrawLSynthDirective.h"
#import "LDrawContainer.h"

@implementation LDrawLSynthDirective

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== setSelected: ======================================================
//
// Purpose:		Inform the directive that it's been (de)selected.
//
//==============================================================================
- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];

    // would like LDrawContainer to be a protocol.  In its absence, respondsToSelector: works
    if ([[self enclosingDirective] respondsToSelector:@selector(setSubdirectiveSelected:)]) {
        [[self enclosingDirective] setSubdirectiveSelected:flag];
    }

}//end setSelected:

#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) browsingDescription
{
    if ([[self stringValue] isEqualToString:@"INSIDE"]) {
        return @"Inside";
    }
    else if ([[self stringValue] isEqualToString:@"OUTSIDE"]) {
        return @"Outside";
    }
    else if ([[self stringValue] isEqualToString:@"CROSS"]) {
        return @"Cross";
    }

    return @"Unknown LSynth Direction";
}//end browsingDescription

//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
    return @"LSynthDirection";
}//end iconName

#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//				Line format:
//				0 SYNTH [INSIDE|OUTSIDE]
//
//==============================================================================
- (NSString *) write
{
    return [NSString stringWithFormat:	@"0 SYNTH %@", [self stringValue]];
}//end write

@end