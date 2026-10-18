import Testing

@testable import Stipple

@Test func kittyPlainLetterPress() {
    #expect(singleKey("\u{1B}[97u") == press(.character("a"), "a"))
}

@Test func kittyCtrlLetter() {
    #expect(singleKey("\u{1B}[97;5u") == press(.character("a"), "a", .control))
}

@Test func kittyModifierBits() {
    #expect(KittyKeys.modifiers(1).isEmpty)
    #expect(KittyKeys.modifiers(2) == .shift)
    #expect(KittyKeys.modifiers(3) == .option)
    #expect(KittyKeys.modifiers(5) == .control)
    #expect(KittyKeys.modifiers(9) == .command)
    #expect(KittyKeys.modifiers(17) == .hyper)
    #expect(KittyKeys.modifiers(33) == .option)
    #expect(KittyKeys.modifiers(65) == .capsLock)
    #expect(KittyKeys.modifiers(129) == .numLock)
    #expect(KittyKeys.modifiers(0).isEmpty)
    #expect(KittyKeys.modifiers(9 + 16 + 64).isSuperset(of: [.command, .hyper, .capsLock]))
}

@Test func kittySuperAndHyperAndLocks() {
    #expect(singleKey("\u{1B}[97;9u") == press(.character("a"), "a", .command))
    #expect(singleKey("\u{1B}[97;17u") == press(.character("a"), "a", .hyper))
    #expect(singleKey("\u{1B}[97;65u") == press(.character("a"), "a", .capsLock))
    #expect(singleKey("\u{1B}[97;129u") == press(.character("a"), "a", .numLock))
}

@Test func kittyAltIsOption() {
    #expect(singleKey("\u{1B}[97;3u") == press(.character("a"), "a", .option))
}

@Test func kittyCapsLockTextDoesNotImplyShift() {
    #expect(singleKey("\u{1B}[97;1;65u") == press(.character("a"), "A"))
}

@Test func kittyShiftWithTextField() {
    #expect(singleKey("\u{1B}[97;2;65u") == press(.character("a"), "A", .shift))
}

@Test func kittyTextFieldWithMultipleCodepoints() {
    #expect(singleKey("\u{1B}[97;1;104:105u") == press(.character("a"), "hi"))
}

@Test func kittyInvalidTextCodepointsAreSkipped() {
    #expect(singleKey("\u{1B}[97;1;55296u") == press(.character("a"), ""))
}

@Test func kittyEmptyTextFieldKeepsDefault() {
    #expect(singleKey("\u{1B}[97;1;u") == press(.character("a"), "a"))
}

@Test func kittyNonLowercaseCodepointIsLowercased() {
    #expect(singleKey("\u{1B}[65;2u") == press(.character("a"), "A", .shift))
}

@Test func kittyUnicodeCodepoint() {
    #expect(singleKey("\u{1B}[233u") == press(.character("é"), "é"))
    #expect(singleKey("\u{1B}[201;3u") == press(.character("é"), "É", .option))
}

@Test func kittyEscapeAndEnterAndTabAndBackspace() {
    #expect(singleKey("\u{1B}[27u") == press(.escape))
    #expect(singleKey("\u{1B}[13u") == press(.return, "\r"))
    #expect(singleKey("\u{1B}[9u") == press(.tab, "\t"))
    #expect(singleKey("\u{1B}[127u") == press(.backspace))
    #expect(singleKey("\u{1B}[9;5u") == press(.tab, "\t", .control))
}

@Test func kittyKeypadEnterIsReturn() {
    #expect(singleKey("\u{1B}[57414u") == press(.return, "\r"))
    #expect(singleKey("\u{1B}[57414;1:1u") == press(.return, "\r"))
}

@Test func kittySpaceIsSpace() {
    #expect(singleKey("\u{1B}[32u") == press(.character(" "), " "))
    #expect(singleKey("\u{1B}[32;5u") == press(.character(" "), " ", .control))
}

@Test func kittyKeypadDigitsAndSymbols() {
    #expect(singleKey("\u{1B}[57400u") == press(.character("1"), "1"))
    #expect(singleKey("\u{1B}[57409u") == press(.character("."), "."))
    #expect(singleKey("\u{1B}[57410u") == press(.character("/"), "/"))
    #expect(singleKey("\u{1B}[57411u") == press(.character("*"), "*"))
    #expect(singleKey("\u{1B}[57412u") == press(.character("-"), "-"))
    #expect(singleKey("\u{1B}[57413u") == press(.character("+"), "+"))
    #expect(singleKey("\u{1B}[57415u") == press(.character("="), "="))
    #expect(singleKey("\u{1B}[57416u") == press(.character(","), ","))
}

@Test func kittyKeypadAssociatedTextIsPrintable() {
    #expect(singleKey("\u{1B}[57400;1;49u") == press(.character("1"), "1"))
}

@Test func kittyNavigationKeys() {
    #expect(singleKey("\u{1B}[57417u") == press(.leftArrow))
    #expect(singleKey("\u{1B}[57418u") == press(.rightArrow))
    #expect(singleKey("\u{1B}[57419u") == press(.upArrow))
    #expect(singleKey("\u{1B}[57420u") == press(.downArrow))
    #expect(singleKey("\u{1B}[57421u") == press(.pageUp))
    #expect(singleKey("\u{1B}[57422u") == press(.pageDown))
    #expect(singleKey("\u{1B}[57423u") == press(.home))
    #expect(singleKey("\u{1B}[57424u") == press(.end))
    #expect(singleKey("\u{1B}[57425u") == press(.insert))
    #expect(singleKey("\u{1B}[57426u") == press(.delete))
}

@Test func kittyFunctionKeysAboveTwelve() {
    #expect(singleKey("\u{1B}[57376u") == press(.function(13)))
    #expect(singleKey("\u{1B}[57398u") == press(.function(35)))
}

@Test func kittyNonPrintableKeysAreDropped() {
    #expect(decode("\u{1B}[57358u").isEmpty)
    #expect(decode("\u{1B}[57441u").isEmpty)
    #expect(decode("\u{1B}[57428u").isEmpty)
    #expect(decode("\u{1B}[57427u").isEmpty)
    #expect(decode("\u{1B}[1u").isEmpty)
    #expect(decode("\u{1B}[127;1u").first == .key(press(.backspace)))
    #expect(decode("\u{1B}[128u").isEmpty)
    #expect(decode("\u{1B}[1114112u").isEmpty)
    #expect(decode("\u{1B}[99999999999999999999u").isEmpty)
    #expect(decode("\u{1B}[-1u").isEmpty)
}

@Test func kittyEventPhases() {
    #expect(singleKey("\u{1B}[97;1:1u") == KeyPress(key: .character("a"), characters: "a", phase: .down))
    #expect(singleKey("\u{1B}[97;1:2u") == KeyPress(key: .character("a"), characters: "a", phase: .repeat))
    #expect(singleKey("\u{1B}[97;1:3u") == KeyPress(key: .character("a"), characters: "a", phase: .up))
    #expect(singleKey("\u{1B}[97;1:9u") == KeyPress(key: .character("a"), characters: "a", phase: .down))
}

@Test func kittyFunctionalKeyEventPhase() {
    #expect(singleKey("\u{1B}[1;1:3A") == KeyPress(key: .upArrow, phase: .up))
    #expect(singleKey("\u{1B}[3;1:2~") == KeyPress(key: .delete, phase: .repeat))
}

@Test func kittyFunctionalKeyWithModifiersAndPhase() {
    #expect(singleKey("\u{1B}[1;5:1A") == press(.upArrow, "", .control))
    #expect(singleKey("\u{1B}[1;6:3D") == KeyPress(key: .leftArrow, modifiers: [.shift, .control], phase: .up))
}

@Test func kittyReleaseOfCtrlLetter() {
    #expect(
        singleKey("\u{1B}[97;5:3u") == KeyPress(key: .character("a"), characters: "a", modifiers: .control, phase: .up))
}

@Test func kittyMissingEventFieldDefaultsToPress() {
    #expect(singleKey("\u{1B}[97;5u") == KeyPress(key: .character("a"), characters: "a", modifiers: .control))
}

@Test func kittyCodepointWithAlternateKeysUsesPrimary() {
    // `CSI code:shifted:base ; mods u` still reports the primary code point.
    #expect(singleKey("\u{1B}[97:65:97;2u") == press(.character("a"), "a", .shift))
}

@Test func kittyEmptyCodepointIsDropped() {
    #expect(decode("\u{1B}[;5u").isEmpty)
}

@Test func kittyQueryReplyParsesFlags() {
    #expect(decode("\u{1B}[?0u") == [.kittyKeyboardSupported(flags: 0)])
    #expect(decode("\u{1B}[?1;2u").isEmpty)
    #expect(KittyKeys.queryReply("?x").isEmpty)
}

@Test func kittyDecodeTextSkipsEmptyParts() {
    #expect(KittyKeys.decodeText("::104") == "h")
}

@Test func kittyKeyWithUnusedNamedKeyCharacters() {
    #expect(KittyKeys.keyPress(NamedKey(.upArrow, characters: "x"), modifierField: "").characters == "x")
}
