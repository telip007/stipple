import Testing

@testable import Stipple

@Suite struct CursorHelpersTests {
    @Test func changedComparesBothCoordinatesAndNil() {
        #expect(!CursorHelpers.changed(nil, nil))
        #expect(CursorHelpers.changed(nil, CursorPosition(x: 0, y: 0)))
        #expect(CursorHelpers.changed(CursorPosition(x: 0, y: 0), nil))
        #expect(CursorHelpers.changed(CursorPosition(x: 1, y: 0), CursorPosition(x: 0, y: 0)))
        #expect(CursorHelpers.changed(CursorPosition(x: 0, y: 2), CursorPosition(x: 0, y: 0)))
        #expect(!CursorHelpers.changed(CursorPosition(x: 3, y: 4), CursorPosition(x: 3, y: 4)))
    }

    @Test func suffixIsEmptyWithoutACursor() {
        #expect(CursorHelpers.suffix(bottomLine: 2, cursorPosition: nil).isEmpty)
    }

    @Test func suffixMovesUpFromTheBottomRowAndShowsTheCursor() {
        let cursor = CursorPosition(x: 1, y: 0)
        #expect(
            CursorHelpers.suffix(bottomLine: 2, cursorPosition: cursor) == "\(Bytes.esc)2A\(Bytes.esc)2G\(Bytes.show)")
    }

    @Test func suffixOnTheBottomRowOnlyPositionsColumn() {
        let cursor = CursorPosition(x: 0, y: 1)
        #expect(CursorHelpers.suffix(bottomLine: 1, cursorPosition: cursor) == "\(Bytes.esc)1G\(Bytes.show)")
    }

    @Test func returnToBottomMovesDownFromTheCursorRow() {
        let cursor = CursorPosition(x: 0, y: 0)
        #expect(
            CursorHelpers.returnToBottom(previousLineCount: 3, previousCursorPosition: cursor)
                == "\(Bytes.esc)2B\(Bytes.esc)1G")
        #expect(CursorHelpers.returnToBottom(previousLineCount: 1, previousCursorPosition: cursor) == "\(Bytes.esc)1G")
        #expect(CursorHelpers.returnToBottom(previousLineCount: 3, previousCursorPosition: nil).isEmpty)
    }

    @Test func cursorOnlyHidesThenRepositions() {
        let sequence = CursorHelpers.cursorOnly(
            cursorWasShown: true,
            previousLineCount: 2,
            previousCursorPosition: CursorPosition(x: 1, y: 0),
            cursorPosition: CursorPosition(x: 2, y: 0)
        )
        #expect(sequence == Bytes.hide + "\(Bytes.esc)1B\(Bytes.esc)1G" + "\(Bytes.esc)1A\(Bytes.esc)3G" + Bytes.show)
    }

    @Test func returnToBottomPrefixOnlyWhenTheCursorWasShown() {
        let cursor = CursorPosition(x: 0, y: 0)
        #expect(
            CursorHelpers.returnToBottomPrefix(
                wasCursorShown: false, previousLineCount: 2, previousCursorPosition: cursor
            ).isEmpty)
        #expect(
            CursorHelpers.returnToBottomPrefix(
                wasCursorShown: true, previousLineCount: 2, previousCursorPosition: cursor)
                == Bytes.hide + "\(Bytes.esc)1B\(Bytes.esc)1G"
        )
    }

    @Test func eraseFrameWithoutCursorErasesLines() {
        #expect(CursorHelpers.eraseFrame(previousLineCount: 2, previousCursorPosition: nil) == Escape.eraseLines(2))
    }

    @Test func eraseFrameWithCursorWalksUpToTheTopRow() {
        let cursor = CursorPosition(x: 0, y: 5)
        // The cursor sits past the frame, so the walk stops at the bottom row (two rows up from the top of three).
        #expect(
            CursorHelpers.eraseFrame(previousLineCount: 3, previousCursorPosition: cursor)
                == Bytes.hide + "\(Bytes.esc)2A\(Bytes.esc)1G\(Bytes.esc)J"
        )
        #expect(
            CursorHelpers.eraseFrame(previousLineCount: 3, previousCursorPosition: CursorPosition(x: 0, y: 0))
                == Bytes.hide + "\(Bytes.esc)1G\(Bytes.esc)J"
        )
    }
}
