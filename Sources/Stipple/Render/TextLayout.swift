/// Where `…` goes when a line is too long, with SwiftUI's
/// `Text.TruncationMode` names.
public enum TruncationMode: Hashable, Sendable {
    /// Cut the start: `…world`.
    case head
    /// Cut the middle: `hel…ld`.
    case middle
    /// Cut the end: `hello…`.
    case tail
}

/// Line splitting, word wrapping and truncation of styled text (the
/// behaviour of Ink's `wrap-text`, `wrap-ansi` and `cli-truncate`).
enum TextLayout {
    /// The ellipsis that marks cut text.
    static let ellipsis: Character = "…"

    /// Splits runs on `\n`. Styles carry across the break. Empty input and
    /// text without a newline give one line, which may be empty.
    static func lines(_ runs: [StyledRun]) -> [[StyledRun]] {
        var result: [[StyledRun]] = [[]]
        for run in runs {
            let pieces = run.text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, piece) in pieces.enumerated() {
                if index > 0 { result.append([]) }
                guard !piece.isEmpty else { continue }
                let text = String(piece)
                if let last = result[result.count - 1].last, last.style == run.style {
                    result[result.count - 1][result[result.count - 1].count - 1].text += text
                } else {
                    result[result.count - 1].append(StyledRun(text: text, style: run.style))
                }
            }
        }
        return result
    }

    /// Word-wraps runs into lines of at most `width` cells.
    ///
    /// This is `wrap-ansi` with `hard: true, trim: false`, the way Ink calls it.
    /// Words break at spaces, words wider than a line are cut, and spaces at
    /// a break stay on the line they ended (so `"hello world"` at width 5 is
    /// `hello`, a line holding one space, and `world`). Existing `\n` start new
    /// lines. A width below 1 returns the lines unwrapped.
    static func wrap(_ runs: [StyledRun], width: Int) -> [[StyledRun]] {
        let lines = lines(runs)
        guard width > 0 else { return lines }
        return lines.flatMap { line in
            let graphemes = StyledGrapheme.graphemes(of: line)
            return wrapLine(graphemes, width: width).map { StyledGrapheme.runs(from: $0) }
        }
    }

    /// Cuts one line to `width` cells and marks the cut with `…`, which takes
    /// the style of the character next to it. A line that fits is returned
    /// unchanged. A width of 1 leaves only the ellipsis; below 1 leaves nothing.
    /// Newlines are not handled: call ``lines(_:)`` first.
    static func truncate(_ runs: [StyledRun], width: Int, mode: TruncationMode) -> [StyledRun] {
        guard width >= 1 else { return [] }
        let graphemes = StyledGrapheme.graphemes(of: runs)
        let total = graphemes.reduce(0) { $0 + $1.width }
        guard total > width else { return runs }
        let kept: [StyledGrapheme]
        switch mode {
        case .tail:
            let head = slice(graphemes, from: 0, to: width - 1)
            kept = head + [ellipsisGrapheme(next: head.last ?? graphemes.first)]
        case .head:
            let tail = slice(graphemes, from: total - width + 1, to: total)
            kept = [ellipsisGrapheme(next: tail.first ?? graphemes.last)] + tail
        case .middle:
            let half = width / 2
            let head = slice(graphemes, from: 0, to: half)
            let tail = slice(graphemes, from: total - (width - half) + 1, to: total)
            kept = head + [ellipsisGrapheme(next: head.last ?? tail.first)] + tail
        }
        return StyledGrapheme.runs(from: kept)
    }

    // MARK: - Internals

    private static func ellipsisGrapheme(next: StyledGrapheme?) -> StyledGrapheme {
        StyledGrapheme(character: ellipsis, style: next?.style ?? .plain, width: 1)
    }

    /// The graphemes lying completely inside the columns `from..<to`.
    private static func slice(_ graphemes: [StyledGrapheme], from: Int, to: Int) -> [StyledGrapheme] {
        var column = 0
        var result: [StyledGrapheme] = []
        for grapheme in graphemes {
            let start = column
            column += grapheme.width
            if start >= from && column <= to { result.append(grapheme) }
            if column >= to { break }
        }
        return result
    }

    private static func wrapLine(_ graphemes: [StyledGrapheme], width: Int) -> [[StyledGrapheme]] {
        var rows: [[StyledGrapheme]] = [[]]
        var rowWidth = 0
        for word in split(graphemes) {
            let wordWidth = word.items.reduce(0) { $0 + $1.width }
            if let space = word.separator {
                if rowWidth >= width {
                    rows.append([])
                    rowWidth = 0
                }
                rows[rows.count - 1].append(space)
                rowWidth += 1
            }
            if wordWidth > width {
                let remaining = width - rowWidth
                let breaksThisLine = 1 + (wordWidth - remaining - 1) / width
                let breaksNextLine = (wordWidth - 1) / width
                if breaksNextLine < breaksThisLine { rows.append([]) }
                breakWord(word.items, into: &rows, width: width)
                rowWidth = rows[rows.count - 1].reduce(0) { $0 + $1.width }
                continue
            }
            if rowWidth + wordWidth > width && rowWidth > 0 && wordWidth > 0 {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(contentsOf: word.items)
            rowWidth += wordWidth
        }
        return rows
    }

    /// Fills rows with a word wider than a line, one full row at a time.
    private static func breakWord(_ word: [StyledGrapheme], into rows: inout [[StyledGrapheme]], width: Int) {
        var visible = rows[rows.count - 1].reduce(0) { $0 + $1.width }
        for (index, grapheme) in word.enumerated() {
            if visible + grapheme.width <= width || rows[rows.count - 1].isEmpty {
                rows[rows.count - 1].append(grapheme)
            } else {
                rows.append([grapheme])
                visible = 0
            }
            visible += grapheme.width
            if visible >= width && index < word.count - 1 {
                rows.append([])
                visible = 0
            }
        }
    }

    private typealias Word = (separator: StyledGrapheme?, items: [StyledGrapheme])

    /// Words with the space that precedes each one (the first has none).
    private static func split(_ graphemes: [StyledGrapheme]) -> [Word] {
        var words: [Word] = [(nil, [])]
        for grapheme in graphemes {
            if grapheme.character == " " {
                words.append((grapheme, []))
            } else {
                words[words.count - 1].items.append(grapheme)
            }
        }
        return words
    }
}
