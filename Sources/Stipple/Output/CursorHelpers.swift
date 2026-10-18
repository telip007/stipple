/// Where the terminal cursor rests, relative to the top row of a frame.
/// `x` is the column and `y` the row, both zero-based.
struct CursorPosition: Equatable, Sendable {
    /// Column, from the left.
    var x: Int
    /// Row, counted from the top of the frame.
    var y: Int
}

/// Escape sequences that place, move and erase the cursor around a frame.
/// Port of `cursor-helpers.ts`.
enum CursorHelpers {
    /// Whether two cursor positions differ. Two nil positions are equal.
    static func changed(_ lhs: CursorPosition?, _ rhs: CursorPosition?) -> Bool {
        lhs?.x != rhs?.x || lhs?.y != rhs?.y
    }

    /// Moves from the frame's bottom row to `cursorPosition` and shows the cursor.
    ///
    /// `bottomLine` is the row the writer left the cursor on, `lines.count - 1`
    /// for `lines = text.split("\n")`, with or without a trailing newline.
    static func suffix(bottomLine: Int, cursorPosition: CursorPosition?) -> String {
        guard let cursorPosition else { return "" }
        let moveUp = bottomLine - cursorPosition.y
        return (moveUp > 0 ? Escape.cursorUp(moveUp) : "")
            + Escape.cursorTo(cursorPosition.x)
            + Escape.showCursor
    }

    /// Moves from the cursor's current row back to the frame's bottom row, column 0.
    /// Must run before anything that assumes the cursor is at the bottom.
    static func returnToBottom(previousLineCount: Int, previousCursorPosition: CursorPosition?) -> String {
        guard let previousCursorPosition else { return "" }
        let down = previousLineCount - 1 - previousCursorPosition.y
        return (down > 0 ? Escape.cursorDown(down) : "") + Escape.cursorTo(0)
    }

    /// The sequence for a cursor-only update: the output is unchanged but the cursor moved.
    static func cursorOnly(
        cursorWasShown: Bool,
        previousLineCount: Int,
        previousCursorPosition: CursorPosition?,
        cursorPosition: CursorPosition?
    ) -> String {
        let hidePrefix = cursorWasShown ? Escape.hideCursor : ""
        return hidePrefix
            + returnToBottom(previousLineCount: previousLineCount, previousCursorPosition: previousCursorPosition)
            + suffix(bottomLine: previousLineCount - 1, cursorPosition: cursorPosition)
    }

    /// Hides the cursor and returns to the bottom before the frame is erased or rewritten.
    /// Empty when the cursor was not shown.
    static func returnToBottomPrefix(
        wasCursorShown: Bool,
        previousLineCount: Int,
        previousCursorPosition: CursorPosition?
    ) -> String {
        guard wasCursorShown else { return "" }
        return Escape.hideCursor
            + returnToBottom(previousLineCount: previousLineCount, previousCursorPosition: previousCursorPosition)
    }

    /// Erases the previous frame. With the cursor shown, the frame's top row is
    /// found relative to the cursor, because a terminal that loses rows drops
    /// the rows below the cursor before it scrolls anything.
    static func eraseFrame(previousLineCount: Int, previousCursorPosition: CursorPosition?) -> String {
        guard let previousCursorPosition else {
            return Escape.eraseLines(previousLineCount)
        }
        // `suffix` never moves below the bottom row, so a cursor set past the output sits on that row.
        let rowsBelowTop = min(previousCursorPosition.y, previousLineCount - 1)
        return Escape.hideCursor
            + Escape.cursorMove(x: 0, y: -rowsBelowTop)
            + Escape.cursorTo(0)
            + Escape.eraseDown
    }
}
