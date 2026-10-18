/// ANSI escape sequences used by the frame writer. Each one produces the same
/// bytes as the `ansi-escapes` package that Ink uses, so output stays
/// byte-compatible with Ink's.
enum Escape {
    /// Hides the cursor (`?25l`).
    static let hideCursor = "\u{1B}[?25l"
    /// Shows the cursor (`?25h`).
    static let showCursor = "\u{1B}[?25h"
    /// Switches to the alternate screen buffer (`?1049h`).
    static let enterAlternateScreen = "\u{1B}[?1049h"
    /// Switches back to the primary screen buffer (`?1049l`).
    static let exitAlternateScreen = "\u{1B}[?1049l"
    /// Starts a synchronized update, so the terminal paints it in one go (`?2026h`).
    static let beginSynchronizedUpdate = "\u{1B}[?2026h"
    /// Ends a synchronized update (`?2026l`).
    static let endSynchronizedUpdate = "\u{1B}[?2026l"
    /// Erases from the cursor to the end of the line (`EL 0`).
    static let eraseEndLine = "\u{1B}[K"
    /// Erases the whole current line (`EL 2`).
    static let eraseLine = "\u{1B}[2K"
    /// Erases from the cursor to the end of the screen (`ED 0`).
    static let eraseDown = "\u{1B}[J"
    /// Moves to column 0 (`CHA` with no argument).
    static let cursorLeft = "\u{1B}[G"
    /// Moves to column 0 of the next line (`CNL`).
    static let cursorNextLine = "\u{1B}[E"
    /// Moves to the top left and erases to the end of the screen. Ink's full clear.
    static let homeAndEraseDown = cursorTo(0, row: 0) + eraseDown

    /// Moves up `count` rows (`CUU`). `count` is written as given, as `ansi-escapes` does.
    static func cursorUp(_ count: Int = 1) -> String {
        "\u{1B}[\(count)A"
    }

    /// Moves down `count` rows (`CUD`).
    static func cursorDown(_ count: Int = 1) -> String {
        "\u{1B}[\(count)B"
    }

    /// Moves to a zero-based column on the current row (`CHA`).
    static func cursorTo(_ column: Int) -> String {
        "\u{1B}[\(column + 1)G"
    }

    /// Moves to a zero-based column and row, counted from the top left (`CUP`).
    static func cursorTo(_ column: Int, row: Int) -> String {
        "\u{1B}[\(row + 1);\(column + 1)H"
    }

    /// Moves the cursor relative to where it is. Positive `x` is right, positive `y` is down.
    static func cursorMove(x: Int, y: Int) -> String {
        var sequence = ""
        if x < 0 {
            sequence += "\u{1B}[\(-x)D"
        } else if x > 0 {
            sequence += "\u{1B}[\(x)C"
        }
        if y < 0 {
            sequence += "\u{1B}[\(-y)A"
        } else if y > 0 {
            sequence += "\u{1B}[\(y)B"
        }
        return sequence
    }

    /// Erases `count` lines, leaving the cursor at column 0 of the top one. Empty for 0.
    static func eraseLines(_ count: Int) -> String {
        guard count > 0 else { return "" }
        var sequence = ""
        for index in 0..<count {
            sequence += eraseLine
            if index < count - 1 {
                sequence += cursorUp()
            }
        }
        return sequence + cursorLeft
    }
}
