import Testing

@testable import Stipple

@Test(
    arguments: [
        (KeyPress(key: .character("a"), characters: "a"), TextEditing.Command.insert("a")),
        (KeyPress(key: .character("A"), characters: "A", modifiers: .shift), .insert("A")),
        (KeyPress(key: .character("é"), characters: "é"), .insert("é")),
        (KeyPress(key: .character(" "), characters: " "), .insert(" ")),
        (KeyPress(key: .character("1")), .insert("1")),
        (KeyPress(key: .backspace), .deleteBackward),
        (KeyPress(key: .backspace, modifiers: .option), .deleteWordBackward),
        (KeyPress(key: .backspace, modifiers: .control), .deleteWordBackward),
        (KeyPress(key: .backspace, modifiers: .command), .deleteToStart),
        (KeyPress(key: .delete), .deleteForward),
        (KeyPress(key: .leftArrow), .moveLeft),
        (KeyPress(key: .rightArrow), .moveRight),
        (KeyPress(key: .leftArrow, modifiers: .option), .wordLeft),
        (KeyPress(key: .rightArrow, modifiers: .control), .wordRight),
        (KeyPress(key: .leftArrow, modifiers: .command), .moveToStart),
        (KeyPress(key: .rightArrow, modifiers: .command), .moveToEnd),
        (KeyPress(key: .home), .moveToStart),
        (KeyPress(key: .end), .moveToEnd),
        (KeyPress(key: .return), .submit),
        (KeyPress(key: .character("a"), characters: "a", modifiers: .control), .moveToStart),
        (KeyPress(key: .character("e"), characters: "e", modifiers: .control), .moveToEnd),
        (KeyPress(key: .character("b"), characters: "b", modifiers: .control), .moveLeft),
        (KeyPress(key: .character("f"), characters: "f", modifiers: .control), .moveRight),
        (KeyPress(key: .character("u"), characters: "u", modifiers: .control), .deleteToStart),
        (KeyPress(key: .character("k"), characters: "k", modifiers: .control), .deleteToEnd),
        (KeyPress(key: .character("w"), characters: "w", modifiers: .control), .deleteWordBackward),
        (KeyPress(key: .character("d"), characters: "d", modifiers: .control), .deleteForward),
        (KeyPress(key: .character("x"), characters: "x", modifiers: .control), nil),
        (KeyPress(key: .character("x"), characters: "x", modifiers: .option), nil),
        (KeyPress(key: .character("x"), characters: "x", modifiers: .command), nil),
        (KeyPress(key: .upArrow), nil),
        (KeyPress(key: .downArrow), nil),
        (KeyPress(key: .tab), nil),
        (KeyPress(key: .escape), nil),
        (KeyPress(key: .function(1)), nil),
        (KeyPress(key: .character("a"), characters: "a", modifiers: .capsLock), .insert("a")),
    ] as [(KeyPress, TextEditing.Command?)])
func keyPressesMapToEdits(press: KeyPress, command: TextEditing.Command?) {
    #expect(TextEditing.Command(press) == command)
}

@Test func characterWithoutTextUsesTheKey() {
    #expect(TextEditing.Command(KeyPress(key: .character("q"))) == .insert("q"))
}
