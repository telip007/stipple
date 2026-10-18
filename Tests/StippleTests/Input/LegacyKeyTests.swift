import Testing

@testable import Stipple

@Test(arguments: [
    ("\u{1B}[A", KeyEquivalent.upArrow),
    ("\u{1B}[B", .downArrow),
    ("\u{1B}[C", .rightArrow),
    ("\u{1B}[D", .leftArrow),
    ("\u{1B}OA", .upArrow),
    ("\u{1B}OB", .downArrow),
    ("\u{1B}OC", .rightArrow),
    ("\u{1B}OD", .leftArrow),
    ("\u{1B}[H", .home),
    ("\u{1B}[F", .end),
    ("\u{1B}OH", .home),
    ("\u{1B}OF", .end),
    ("\u{1B}[1~", .home),
    ("\u{1B}[2~", .insert),
    ("\u{1B}[3~", .delete),
    ("\u{1B}[4~", .end),
    ("\u{1B}[5~", .pageUp),
    ("\u{1B}[6~", .pageDown),
    ("\u{1B}[7~", .home),
    ("\u{1B}[8~", .end),
])
func navigationKeys(sequence: String, key: KeyEquivalent) {
    #expect(singleKey(sequence) == press(key))
}

@Test(arguments: [
    ("\u{1B}OP", 1), ("\u{1B}OQ", 2), ("\u{1B}OR", 3), ("\u{1B}OS", 4),
    ("\u{1B}[11~", 1), ("\u{1B}[12~", 2), ("\u{1B}[13~", 3), ("\u{1B}[14~", 4), ("\u{1B}[15~", 5),
    ("\u{1B}[17~", 6), ("\u{1B}[18~", 7), ("\u{1B}[19~", 8), ("\u{1B}[20~", 9), ("\u{1B}[21~", 10),
    ("\u{1B}[23~", 11), ("\u{1B}[24~", 12),
    ("\u{1B}[[A", 1), ("\u{1B}[[B", 2), ("\u{1B}[[C", 3), ("\u{1B}[[D", 4), ("\u{1B}[[E", 5),
    ("\u{1B}[P", 1), ("\u{1B}[Q", 2), ("\u{1B}[S", 4),
])
func functionKeys(sequence: String, number: Int) {
    #expect(singleKey(sequence) == press(.function(number)))
}

@Test func linuxConsolePageKeys() {
    #expect(singleKey("\u{1B}[[5~") == press(.pageUp))
    #expect(singleKey("\u{1B}[[6~") == press(.pageDown))
}

@Test func shiftTabAndKeypadEnter() {
    #expect(singleKey("\u{1B}[Z") == press(.tab, "\t", .shift))
    #expect(singleKey("\u{1B}OM") == press(.return, "\r"))
}

@Test func modifiedArrowsCarryModifiers() {
    #expect(singleKey("\u{1B}[1;2A") == press(.upArrow, "", .shift))
    #expect(singleKey("\u{1B}[1;3A") == press(.upArrow, "", .option))
    #expect(singleKey("\u{1B}[1;5A") == press(.upArrow, "", .control))
    #expect(singleKey("\u{1B}[1;6D") == press(.leftArrow, "", [.shift, .control]))
    #expect(singleKey("\u{1B}[1;9B") == press(.downArrow, "", .command))
}

@Test func modifiedSS3ArrowsCarryModifiers() {
    #expect(singleKey("\u{1B}[1;5A") == press(.upArrow, "", .control))
}

@Test func modifiedEditingKeys() {
    #expect(singleKey("\u{1B}[3;5~") == press(.delete, "", .control))
    #expect(singleKey("\u{1B}[5;2~") == press(.pageUp, "", .shift))
    #expect(singleKey("\u{1B}[1;2H") == press(.home, "", .shift))
}

@Test func modifiedFunctionKeys() {
    #expect(singleKey("\u{1B}[1;5P") == press(.function(1), "", .control))
    #expect(singleKey("\u{1B}[15;2~") == press(.function(5), "", .shift))
    #expect(singleKey("\u{1B}O1;2Q") == press(.function(2), "", .shift))
}

@Test func rxvtShiftArrows() {
    #expect(singleKey("\u{1B}[a") == press(.upArrow, "", .shift))
    #expect(singleKey("\u{1B}[b") == press(.downArrow, "", .shift))
    #expect(singleKey("\u{1B}[c") == press(.rightArrow, "", .shift))
    #expect(singleKey("\u{1B}[d") == press(.leftArrow, "", .shift))
}

@Test func rxvtCtrlArrows() {
    #expect(singleKey("\u{1B}Oa") == press(.upArrow, "", .control))
    #expect(singleKey("\u{1B}Ob") == press(.downArrow, "", .control))
    #expect(singleKey("\u{1B}Oc") == press(.rightArrow, "", .control))
    #expect(singleKey("\u{1B}Od") == press(.leftArrow, "", .control))
}

@Test func rxvtShiftedEditingKeys() {
    #expect(singleKey("\u{1B}[2$") == press(.insert, "", .shift))
    #expect(singleKey("\u{1B}[3$") == press(.delete, "", .shift))
    #expect(singleKey("\u{1B}[5$") == press(.pageUp, "", .shift))
    #expect(singleKey("\u{1B}[6$") == press(.pageDown, "", .shift))
    #expect(singleKey("\u{1B}[7$") == press(.home, "", .shift))
    #expect(singleKey("\u{1B}[8$") == press(.end, "", .shift))
}

@Test func rxvtCtrlEditingKeys() {
    #expect(singleKey("\u{1B}[2^") == press(.insert, "", .control))
    #expect(singleKey("\u{1B}[3^") == press(.delete, "", .control))
    #expect(singleKey("\u{1B}[5^") == press(.pageUp, "", .control))
    #expect(singleKey("\u{1B}[6^") == press(.pageDown, "", .control))
    #expect(singleKey("\u{1B}[7^") == press(.home, "", .control))
    #expect(singleKey("\u{1B}[8^") == press(.end, "", .control))
}

@Test func rxvtShiftKeyEmitsWithoutWaitingForTheNextByte() {
    let events = decode("\u{1B}[3$x")
    #expect(keyPresses(events) == [press(.delete, "", .shift), press(.character("x"), "x")])
}

@Test func csiIntermediateBytesAreAccepted() {
    // A CSI with an intermediate byte (space, 0x20) before its final byte is decoded as a whole.
    #expect(decode("\u{1B}[1 q").isEmpty)
}

@Test func ss3WithNonDigitParameterIsInvalid() {
    let presses = keyPresses(decode("\u{1B}O:A"))
    #expect(presses.first == press(.escape))
}

@Test func csiOptionOnTextKeyIsDecoded() {
    // Alt-modified text uses the ESC prefix, not a CSI parameter.
    #expect(singleKey("\u{1B}d") == press(.character("d"), "d", .option))
}

@Test func csiKeyWithEventFieldInLegacyForm() {
    #expect(singleKey("\u{1B}[1;1:3A") == KeyPress(key: .upArrow, phase: .up))
}

@Test func focusInsideCSIIsNotAKey() {
    #expect(decode("\u{1B}[O").first == .focus(false))
}

@Test func keyPressInitializerDefaults() {
    let keyPress = KeyPress(key: .escape)
    #expect(keyPress.characters.isEmpty)
    #expect(keyPress.modifiers.isEmpty)
    #expect(keyPress.phase == .down)
}

@Test func namedKeyCarriesDefaults() {
    let named = NamedKey(.upArrow)
    #expect(named.characters.isEmpty)
    #expect(named.modifiers.isEmpty)
}
