import Testing

@testable import Stipple

@Suite struct EscapeTests {
    @Test func cursorMovesMatchAnsiEscapes() {
        #expect(Escape.cursorUp() == "\u{1B}[1A")
        #expect(Escape.cursorUp(0) == "\u{1B}[0A")
        #expect(Escape.cursorDown(3) == "\u{1B}[3B")
        #expect(Escape.cursorTo(0) == "\u{1B}[1G")
        #expect(Escape.cursorTo(4) == "\u{1B}[5G")
        #expect(Escape.cursorTo(0, row: 0) == "\u{1B}[1;1H")
        #expect(Escape.cursorTo(2, row: 3) == "\u{1B}[4;3H")
        #expect(Escape.cursorNextLine == "\u{1B}[E")
        #expect(Escape.cursorLeft == "\u{1B}[G")
    }

    @Test func relativeMoveSkipsZeroAndUsesSignedDirections() {
        #expect(Escape.cursorMove(x: 0, y: 0).isEmpty)
        #expect(Escape.cursorMove(x: -2, y: 3) == "\u{1B}[2D\u{1B}[3B")
        #expect(Escape.cursorMove(x: 4, y: -1) == "\u{1B}[4C\u{1B}[1A")
    }

    @Test func eraseLinesErasesEachRowAndEndsAtColumnZero() {
        #expect(Escape.eraseLines(0).isEmpty)
        #expect(Escape.eraseLines(1) == "\u{1B}[2K\u{1B}[G")
        #expect(Escape.eraseLines(3) == "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G")
    }

    @Test func fixedSequences() {
        #expect(Escape.hideCursor == Bytes.hide)
        #expect(Escape.showCursor == Bytes.show)
        #expect(Escape.enterAlternateScreen == "\u{1B}[?1049h")
        #expect(Escape.exitAlternateScreen == "\u{1B}[?1049l")
        #expect(Escape.beginSynchronizedUpdate == Bytes.begin)
        #expect(Escape.endSynchronizedUpdate == Bytes.end)
        #expect(Escape.eraseEndLine == "\u{1B}[K")
        #expect(Escape.eraseDown == "\u{1B}[J")
        #expect(Escape.homeAndEraseDown == "\u{1B}[1;1H\u{1B}[J")
    }
}

@Suite struct TextMetricsWidthTests {
    @Test func asciiIsOneColumnPerCharacter() {
        #expect(TextMetrics.width(of: "abc") == 3)
        #expect(TextMetrics.width(of: "") == 0)
    }

    @Test func wideCharactersTakeTwoColumns() {
        #expect(TextMetrics.width(of: "日本") == 4)
        #expect(TextMetrics.width(of: "👍") == 2)
        #expect(TextMetrics.width(of: "ｱ") == 1)
    }

    @Test func combiningMarksTakeNoColumns() {
        #expect(TextMetrics.width(of: "e\u{301}") == 1)
    }
}

@Suite struct FullClearTests {
    private func context(
        isTerminal: Bool = true,
        viewport: Int = 10,
        previousViewport: Int = 10,
        previousHeight: Int = 3,
        nextHeight: Int = 3,
        finishing: Bool = false
    ) -> FullClear.Context {
        FullClear.Context(
            isTerminal: isTerminal,
            viewportRows: viewport,
            previousViewportRows: previousViewport,
            previousOutputHeight: previousHeight,
            nextOutputHeight: nextHeight,
            isFinishing: finishing
        )
    }

    @Test func neverClearsOffTerminal() {
        #expect(!FullClear.isNeeded(context(isTerminal: false, previousHeight: 20, nextHeight: 20)))
    }

    @Test func clearsWhenAnOverflowingFrameWasDrawn() {
        #expect(FullClear.isNeeded(context(viewport: 10, previousHeight: 11, nextHeight: 3)))
    }

    @Test func clearsWhenAFrameStartsToOverflow() {
        #expect(FullClear.isNeeded(context(viewport: 10, previousHeight: 4, nextHeight: 11)))
        #expect(!FullClear.isNeeded(context(viewport: 10, previousHeight: 0, nextHeight: 11)))
    }

    @Test func clearsWhenLeavingFullscreen() {
        #expect(FullClear.isNeeded(context(viewport: 10, previousHeight: 10, nextHeight: 9)))
    }

    @Test func clearsWhenTheViewportShrinksUnderAFullscreenFrame() {
        #expect(FullClear.isNeeded(context(viewport: 8, previousViewport: 10, previousHeight: 10, nextHeight: 10)))
        #expect(!FullClear.isNeeded(context(viewport: 8, previousViewport: 10, previousHeight: 3, nextHeight: 3)))
    }

    @Test func finalFullscreenFrameClearsOnce() {
        #expect(FullClear.isNeeded(context(viewport: 10, previousHeight: 10, nextHeight: 10, finishing: true)))
        #expect(!FullClear.isNeeded(context(viewport: 10, previousHeight: 3, nextHeight: 3, finishing: true)))
    }
}
