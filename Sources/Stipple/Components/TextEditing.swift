/// The text and insertion point of a single-line field, and the edits that
/// key presses ask for. The cursor counts grapheme clusters, as `String.count` does.
struct TextEditing: Equatable {
    /// One edit or movement.
    enum Command: Equatable {
        /// Inserts text at the cursor.
        case insert(String)
        /// Deletes the character before the cursor.
        case deleteBackward
        /// Deletes the character after the cursor.
        case deleteForward
        /// Deletes back to the start of the previous word.
        case deleteWordBackward
        /// Deletes everything before the cursor.
        case deleteToStart
        /// Deletes everything after the cursor.
        case deleteToEnd
        /// Moves the cursor one character left.
        case moveLeft
        /// Moves the cursor one character right.
        case moveRight
        /// Moves the cursor to the start of the previous word.
        case wordLeft
        /// Moves the cursor to the end of the next word.
        case wordRight
        /// Moves the cursor to the start of the text.
        case moveToStart
        /// Moves the cursor to the end of the text.
        case moveToEnd
        /// Asks the field to submit. Changes nothing.
        case submit
    }

    private(set) var text: String
    private(set) var cursor: Int

    /// Creates an editor. A cursor outside the text is clamped into it.
    init(text: String, cursor: Int) {
        self.text = text
        self.cursor = min(max(cursor, 0), text.count)
    }

    /// Applies `command`.
    mutating func apply(_ command: Command) {
        switch command {
        case .insert(let string): replace(cursor..<cursor, with: string)
        case .deleteBackward: replace((cursor - 1)..<cursor, with: "", when: cursor > 0)
        case .deleteForward: replace(cursor..<(cursor + 1), with: "", when: cursor < text.count)
        case .deleteWordBackward: replace(wordStart..<cursor, with: "")
        case .deleteToStart: replace(0..<cursor, with: "")
        case .deleteToEnd: replace(cursor..<text.count, with: "")
        case .moveLeft: cursor = max(0, cursor - 1)
        case .moveRight: cursor = min(text.count, cursor + 1)
        case .wordLeft: cursor = wordStart
        case .wordRight: cursor = wordEnd
        case .moveToStart: cursor = 0
        case .moveToEnd: cursor = text.count
        case .submit: break
        }
    }

    /// Replaces `range` with `insertion` and leaves the cursor after it.
    private mutating func replace(_ range: Range<Int>, with insertion: String, when condition: Bool = true) {
        guard condition else { return }
        let characters = Array(text)
        let before = String(characters[..<range.lowerBound])
        let after = String(characters[range.upperBound...])
        let joined = before + insertion
        text = joined + after
        cursor = joined.count
    }

    /// Where the previous word starts: whitespace before the cursor is skipped, then the word.
    private var wordStart: Int {
        let characters = Array(text)
        var position = cursor
        while position > 0, characters[position - 1].isWhitespace {
            position -= 1
        }
        while position > 0, !characters[position - 1].isWhitespace {
            position -= 1
        }
        return position
    }

    /// Where the next word ends: whitespace after the cursor is skipped, then the word.
    private var wordEnd: Int {
        let characters = Array(text)
        var position = cursor
        while position < characters.count, characters[position].isWhitespace {
            position += 1
        }
        while position < characters.count, !characters[position].isWhitespace {
            position += 1
        }
        return position
    }
}
