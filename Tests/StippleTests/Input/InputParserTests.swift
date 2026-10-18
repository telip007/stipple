import Testing

@testable import Stipple

@Test func plainTextIsOneKeyPerCharacter() {
    let presses = keyPresses(decode("ab1"))
    #expect(presses == [press(.character("a"), "a"), press(.character("b"), "b"), press(.character("1"), "1")])
}

@Test func uppercaseLetterIsLowercaseKeyWithShift() {
    #expect(singleKey("A") == press(.character("a"), "A", .shift))
}

@Test func nonASCIIUppercaseAlsoGetsShift() {
    #expect(singleKey("É") == press(.character("é"), "É", .shift))
}

@Test func combiningMarksStayWithTheirBaseCharacter() {
    let presses = keyPresses(decode("e\u{301}x"))
    #expect(presses.count == 2)
    #expect(presses.first?.characters == "e\u{301}")
}

@Test func emojiIsOneKey() {
    #expect(singleKey("👍🏽") == press(.character("👍🏽"), "👍🏽"))
}

@Test func space() {
    #expect(singleKey(" ") == press(.character(" "), " "))
}

@Test func returnAndTab() {
    #expect(singleKey("\r") == press(.return, "\r"))
    #expect(singleKey("\t") == press(.tab, "\t"))
}

@Test func newlineIsReturn() {
    #expect(singleKey("\n") == press(.return, "\n"))
}

@Test func backspaceBytes() {
    #expect(singleKey("\u{7F}") == press(.backspace))
    #expect(singleKey("\u{08}") == press(.backspace))
}

@Test func ctrlLetterBytes() {
    #expect(singleKey("\u{03}") == press(.character("c"), "c", .control))
    #expect(singleKey("\u{01}") == press(.character("a"), "a", .control))
    #expect(singleKey("\u{1A}") == press(.character("z"), "z", .control))
}

@Test func ctrlSpaceIsSpaceWithControl() {
    #expect(singleKey("\u{00}") == press(.character(" "), " ", .control))
}

@Test func ctrlPunctuationBytes() {
    #expect(singleKey("\u{1C}") == press(.character("\\"), "\\", .control))
    #expect(singleKey("\u{1D}") == press(.character("]"), "]", .control))
    #expect(singleKey("\u{1E}") == press(.character("^"), "^", .control))
    #expect(singleKey("\u{1F}") == press(.character("_"), "_", .control))
}

@Test func lonEscapeIsHeldUntilFlushed() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}".utf8).isEmpty)
    #expect(parser.hasPendingInput)
    #expect(parser.flushPendingEscape() == [.key(press(.escape))])
    #expect(!parser.hasPendingInput)
}

@Test func flushWithNothingPendingIsEmpty() {
    var parser = InputParser()
    #expect(!parser.hasPendingInput)
    #expect(parser.flushPendingEscape().isEmpty)
}

@Test func doubleEscapeFlushesAsOptionEscape() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}\u{1B}".utf8).isEmpty)
    #expect(parser.flushPendingEscape() == [.key(press(.escape, "", .option))])
}

@Test func flushedEscapeBracketKeepsTheBracketAsText() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}[".utf8).isEmpty)
    #expect(parser.hasPendingInput)
    #expect(parser.flushPendingEscape() == [.key(press(.escape)), .key(press(.character("["), "["))])
}

@Test func escapeFollowedByLaterChunkIsNotFlushedAsEscape() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}".utf8).isEmpty)
    #expect(parser.parse("[A".utf8) == [.key(press(.upArrow))])
    #expect(!parser.hasPendingInput)
}

@Test func pasteStartPrefixIsNotFlushed() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}[200".utf8).isEmpty)
    #expect(!parser.hasPendingInput)
    #expect(parser.parse("~hi\u{1B}[201~".utf8) == [.paste("hi")])
}

@Test func partialPasteStartIsStillHeldAsEscape() {
    var parser = InputParser()
    _ = parser.parse("\u{1B}[20".utf8)
    #expect(parser.hasPendingInput)
}

@Test func escapeBeforeTextIsOptionKey() {
    #expect(singleKey("\u{1B}x") == press(.character("x"), "x", .option))
    #expect(singleKey("\u{1B}X") == press(.character("x"), "X", [.option, .shift]))
}

@Test func escapeBeforeMultiByteCharacter() {
    #expect(singleKey("\u{1B}é") == press(.character("é"), "é", .option))
}

@Test func escapeBeforeControlByte() {
    #expect(singleKey("\u{1B}\u{7F}") == press(.backspace, "", .option))
    #expect(singleKey("\u{1B}\r") == press(.return, "\r", .option))
    #expect(singleKey("\u{1B}\t") == press(.tab, "\t", .option))
    #expect(singleKey("\u{1B} ") == press(.character(" "), " ", .option))
    #expect(singleKey("\u{1B}\u{01}") == press(.character("a"), "a", [.option, .control]))
}

@Test func doubleEscapeWithKeyAddsOption() {
    #expect(singleKey("\u{1B}\u{1B}[A") == press(.upArrow, "", .option))
    #expect(singleKey("\u{1B}\u{1B}x") == press(.character("x"), "x", .option))
}

@Test func doubleEscapeWithPasteStartIsEscapeThenText() {
    let events = decode("\u{1B}\u{1B}[200~")
    #expect(events.first == .key(press(.escape, "", .option)))
}

@Test func escapeFollowedByDoubleEscapeWaitsForMore() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}\u{1B}\u{1B}".utf8).isEmpty)
    #expect(parser.hasPendingInput)
}

@Test func escapeOnlyAsWholeChunk() {
    var parser = InputParser()
    #expect(parser.parse("x\u{1B}".utf8) == [.key(press(.character("x"), "x"))])
    #expect(parser.hasPendingInput)
}

@Test func invalidCSIFallsBackToEscapeAndText() {
    let presses = keyPresses(decode("\u{1B}[\u{01}"))
    #expect(presses.first == press(.escape))
    #expect(presses.dropFirst().first == press(.character("["), "["))
}

@Test func invalidSS3FallsBackToEscapeAndText() {
    let presses = keyPresses(decode("\u{1B}O\u{01}"))
    #expect(presses.first == press(.escape))
    #expect(presses.dropFirst().first == press(.character("o"), "O", .shift))
}

@Test func utf8SplitAcrossChunks() {
    var parser = InputParser()
    let bytes = Array("é".utf8)
    #expect(parser.parse(bytes[0..<1]).isEmpty)
    #expect(!parser.hasPendingInput)
    #expect(parser.parse(bytes[1...]) == [.key(press(.character("é"), "é"))])
}

@Test func utf8ThreeByteSplitAcrossChunks() {
    var parser = InputParser()
    let bytes = Array("€".utf8)
    #expect(parser.parse(bytes[0..<2]).isEmpty)
    #expect(parser.parse(bytes[2...]) == [.key(press(.character("€"), "€"))])
}

@Test func utf8FourByteSplitAcrossChunks() {
    var parser = InputParser()
    let bytes = Array("🙂".utf8)
    #expect(parser.parse(bytes[0..<3]).isEmpty)
    #expect(parser.parse(bytes[3...]) == [.key(press(.character("🙂"), "🙂"))])
}

@Test func invalidUTF8BecomesReplacementCharacter() {
    let presses = keyPresses(decode(bytes: [0x61, 0xFF]))
    #expect(presses.count == 2)
    #expect(presses.last?.characters == "\u{FFFD}")
}

@Test func invalidUTF8ContinuationDoesNotSwallowFollowingByte() {
    // A lead byte that expects a continuation, followed by an ASCII letter.
    let presses = keyPresses(decode("\u{E0}b"))
    #expect(presses.last == press(.character("b"), "b"))
}

@Test func bytesAfterInvalidUTF8ContinuationAreKept() {
    var parser = InputParser()
    // A lead byte whose continuation has not arrived, then a non-continuation byte in the next chunk.
    #expect(parser.parse([0xE2]).isEmpty)
    let events = parser.parse(Array("x".utf8))
    #expect(events.count == 2)
    #expect(keyPresses(events).last == press(.character("x"), "x"))
}

@Test func incompleteUTF8AfterTextIsHeldAndTextIsEmitted() {
    var parser = InputParser()
    let events = parser.parse(Array("ab".utf8) + [0xE2])
    #expect(keyPresses(events) == [press(.character("a"), "a"), press(.character("b"), "b")])
    #expect(parser.parse([0x82, 0xAC]) == [.key(press(.character("€"), "€"))])
}

@Test func emptyChunkKeepsPendingState() {
    var parser = InputParser()
    _ = parser.parse("\u{1B}".utf8)
    #expect(parser.parse([]).isEmpty)
    #expect(parser.hasPendingInput)
}

@Test func mixedTextAndControlInOneChunk() {
    let events = decode("hi\u{7F}\u{03}")
    #expect(
        keyPresses(events) == [
            press(.character("h"), "h"),
            press(.character("i"), "i"),
            press(.backspace),
            press(.character("c"), "c", .control),
        ])
}

@Test func pastedCarriageReturnAndTabAreKeys() {
    #expect(keyPresses(decode("\r\t")) == [press(.return, "\r"), press(.tab, "\t")])
}

@Test func bracketedPasteIsOneEvent() {
    #expect(decode("\u{1B}[200~hello\nworld\u{1B}[201~") == [.paste("hello\nworld")])
}

@Test func bracketedPasteKeepsEscapeSequencesVerbatim() {
    #expect(decode("\u{1B}[200~\u{1B}[A\u{7F}\u{1B}[201~") == [.paste("\u{1B}[A\u{7F}")])
}

@Test func bracketedPasteAroundKeys() {
    let events = decode("a\u{1B}[200~p\u{1B}[201~b")
    #expect(
        events == [
            .key(press(.character("a"), "a")),
            .paste("p"),
            .key(press(.character("b"), "b")),
        ])
}

@Test func emptyBracketedPaste() {
    #expect(decode("\u{1B}[200~\u{1B}[201~") == [.paste("")])
}

@Test func twoPastesInOneChunk() {
    #expect(decode("\u{1B}[200~a\u{1B}[201~\u{1B}[200~b\u{1B}[201~") == [.paste("a"), .paste("b")])
}

@Test func pasteSpanningChunks() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}[200~one ".utf8).isEmpty)
    #expect(parser.parse("two \u{1B}[20".utf8).isEmpty)
    #expect(parser.parse("1".utf8).isEmpty)
    #expect(parser.parse("~".utf8) == [.paste("one two ")])
}

@Test func pasteEndSplitAfterEscape() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}[200~x\u{1B}".utf8).isEmpty)
    #expect(parser.parse("[201~y".utf8) == [.paste("x"), .key(press(.character("y"), "y"))])
}

@Test func pasteStartSplitBeforeTilde() {
    var parser = InputParser()
    #expect(parser.parse("\u{1B}[200".utf8).isEmpty)
    #expect(parser.parse("~a\u{1B}[201~".utf8) == [.paste("a")])
}

@Test func focusEvents() {
    #expect(decode("\u{1B}[I") == [.focus(true)])
    #expect(decode("\u{1B}[O") == [.focus(false)])
}

@Test func keyUnknownToTheTableIsDropped() {
    #expect(decode("\u{1B}[99~").isEmpty)
    #expect(decode("\u{1B}OZ").isEmpty)
    #expect(decode("\u{1B}[E").isEmpty)
}

@Test func unexpectedPasteEndOutsidePasteIsDropped() {
    #expect(decode("\u{1B}[201~").isEmpty)
}

@Test func kittyQueryReplyIsDecoded() {
    #expect(decode("\u{1B}[?31u") == [.kittyKeyboardSupported(flags: 31)])
    #expect(decode("\u{1B}[?u").isEmpty)
    #expect(decode("\u{1B}[?1c").isEmpty)
}

@Test func unknownQuestionMarkSequenceIsDropped() {
    #expect(decode("\u{1B}[?25h").isEmpty)
}

@Test func tokensAcrossManyChunksReassemble() {
    var parser = InputParser()
    var events: [InputEvent] = []
    for byte in Array("\u{1B}[1;5A".utf8) {
        events += parser.parse([byte])
    }
    #expect(events == [.key(press(.upArrow, "", .control))])
}

@Test func byteRangeHasNoCrashes() {
    var parser = InputParser()
    for start in 0..<256 {
        _ = parser.parse([0x1B, UInt8(start)])
        _ = parser.flushPendingEscape()
        _ = parser.parse([0x1B, 0x5B, UInt8(start)])
        _ = parser.flushPendingEscape()
        _ = parser.parse([0x1B, 0x4F, UInt8(start)])
        _ = parser.flushPendingEscape()
    }
    #expect(!parser.hasPendingInput)
}
