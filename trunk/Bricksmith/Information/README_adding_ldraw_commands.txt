Adding a new LDraw command
==========================

This note details the basics of adding a new LDraw command to Bricksmith.

 1. Create a new class in Bricksmith/Classes/LDraw/Commands/.
    Decide on the type (LDrawDirective, LDrawDrawableElement, LDrawContainer etc), and adopted
    protocols, and update the interface, e.g.

        @interface LDrawNewCommand : LDrawDirective <NSCoding, LDrawObserver>

 2. Add appropriate code to detect the LDraw command to

        LDrawUtilities/+(Class) classForDirectiveBeginningWithLine:(NSString *)line

 3. Add a lineIsNewCommandBeginning: and lineIsNewCommandTerminator: methods to LDrawNewCommand.

 4. Update Bricksmith/Classes/LDraw/Support/LDrawKeywords.h with any command-specific keywords, e.g.

        // NewCommand
        #define NEWCOMMAND_COMMAND                          @"NEWCOMMAND"
        #define NEWCOMMAND_BEGIN                            @"BEGIN"
        #define NEWCOMMAND_END                              @"END"

 5. In LDrawNewCommand implement

        + (NSRange) rangeOfDirectiveBeginningAtIndex:(NSUInteger)index
                                             inLines:(NSArray *)lines
                                            maxIndex:(NSUInteger)maxIndex;

    (Inherited from LDrawDirective)

 6. In LDrawNewCommand implement

        - (id) initWithLines:(NSArray *)lines
                     inRange:(NSRange)range
                 parentGroup:(dispatch_group_t)parentGroup;

    This should be fleshed out later to parse the line, or block of lines comprising a single
    instance of the new command.

 7. In LDrawNewCommand implement browsingDescription.

 8. In LDrawNewCommand implement iconName.  Ensure that it matches a 12x12 .tiff file (minus
    the .tiff extension) in e.g. Bricksmith/Resources/Graphics/Badges/

 8. In LDrawDocument update formatDirective:withStringRepresentation: to correctly color the
    new command in the document tree.

 9. You'll likely want to create an Inspector specific to the new command.  Add an -inspectorClassName
    method to the LDrawNewCommand class.  Create a new inspectionNewCommand class in
    Bricksmith/Classes/Application/Inspector as well as a suitable .xib.

10. You may also need to create a specific Preferences panel related to the new command.  Follow
    the instructions in Bricksmith/Source/Application/General/PreferencesDialogController.m

11. Create a sample file in Bricksmith/Information/Samples/NewCommand and start to flesh out
    initWithLines:inRange:parentGroup:, adding to the Inspector and Preferences as required.

12. Some methods are required for specific pieces of functionality, e.g.

        Creation      - initWithLines:inRange:parentGroup:
        Icon          - iconName
        Description   - browsingDescription
        Drag and Drop - encodeWithCoder: and initWithCoder:
        Inspector     - inspectorClassName
        Part identification - rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:,
                        lineIsScriptBeginning: and lineIsScriptTerminator:
        Save to Disk  - write

13. You may need to touch other areas of the application.  For instance:
    - Altering global menus can be done from
          LDrawDocument/partChanged:,
          LDrawDocument/outlineViewSelectionDidChange:,
          LDrawDocument/setActiveModel: etc.
