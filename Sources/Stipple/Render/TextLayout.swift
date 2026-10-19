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
    /// text without a newline give one line, which may be empty. Tabs are
    /// expanded to spaces up to the next multiple of 8 columns, counted from
    /// the start of the line, so measuring and drawing agree.
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
        return result.map(expandTabs)
    }

    /// Replaces each tab with the spaces that reach the next 8-column tab stop.
    private static func expandTabs(_ line: [StyledRun]) -> [StyledRun] {
        guard line.contains(where: { $0.text.contains("\t") }) else { return line }
        var column = 0
        return line.map { run in
            var text = ""
            for character in run.text {
                if character == "\t" {
                    let spaces = 8 - column % 8
                    text += String(repeating: " ", count: spaces)
                    column += spaces
                } else {
                    text.append(character)
                    column += TextMetrics.width(of: character)
                }
            }
            return StyledRun(text: text, style: run.style)
        }
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
        var wrapper = LineWrapper(width: width, row: [])
        for word in split(graphemes) {
            wrapper.add(word)
        }
        return wrapper.rows
    }

    /// Greedy word wrapping of one line, a word at a time. Its whole state is
    /// the rows so far, and only the last row affects where later words go,
    /// so wrapping can stop between words and resume from the open row.
    private struct LineWrapper {
        let width: Int
        var rows: [[StyledGrapheme]]
        var rowWidth: Int

        init(width: Int, row: [StyledGrapheme]) {
            self.width = width
            rows = [row]
            rowWidth = row.reduce(0) { $0 + $1.width }
        }

        mutating func add(_ word: Word) {
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
                TextLayout.breakWord(word.items, into: &rows, width: width)
                rowWidth = rows[rows.count - 1].reduce(0) { $0 + $1.width }
                return
            }
            if rowWidth + wordWidth > width && rowWidth > 0 && wordWidth > 0 {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(contentsOf: word.items)
            rowWidth += wordWidth
        }
    }

    /// Fills rows with a word wider than a line, one full row at a time.
    fileprivate static func breakWord(_ word: [StyledGrapheme], into rows: inout [[StyledGrapheme]], width: Int) {
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

    fileprivate typealias Word = (separator: StyledGrapheme?, items: [StyledGrapheme])

    /// Words with the space that precedes each one (the first has none).
    fileprivate static func split(_ graphemes: [StyledGrapheme]) -> [Word] {
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

/// Where word-wrapping a text at one width stopped: before the last word of
/// its last line. The same text with more appended, as a reply being
/// streamed, carries on from here instead of wrapping from the start.
struct WrapCheckpoint {
    /// The text that was wrapped.
    var runs: [StyledRun]
    /// Rows that appending can't change: those of the earlier lines, and the
    /// last line's rows before the open one.
    var finished: [[StyledRun]]
    /// The last line's open row, before its last word.
    var row: [StyledGrapheme]
    /// The last word, with the space before it.
    var lastWord: [StyledGrapheme]
}

extension TextLayout {
    /// Word-wraps `runs` to `width` (at least 1) like ``wrap(_:width:)``,
    /// continuing from `checkpoint` when `runs` is its text with more
    /// appended, and returns where to continue next time.
    static func wrap(
        _ runs: [StyledRun], width: Int, resuming checkpoint: WrapCheckpoint?,
    ) -> (lines: [[StyledRun]], checkpoint: WrapCheckpoint) {
        var finished: [[StyledRun]]
        var open: (row: [StyledGrapheme], lastWord: [StyledGrapheme])
        var pending: [[StyledRun]]
        if let checkpoint, let appended = appended(to: checkpoint.runs, in: runs) {
            finished = checkpoint.finished
            open = (checkpoint.row, checkpoint.lastWord)
            pending = lines(appended)
            // The first appended line continues the open one.
            let first = pending.removeFirst()
            open.lastWord += StyledGrapheme.graphemes(of: first)
        } else {
            finished = []
            open = ([], [])
            pending = lines(runs)
            open.lastWord = StyledGrapheme.graphemes(of: pending.removeFirst())
        }
        for line in pending {
            // A newline closes the open line.
            finished += place(open.lastWord, after: open.row, width: width).map(StyledGrapheme.runs)
            open = ([], StyledGrapheme.graphemes(of: line))
        }
        // Place every word of the open line but the last, which may still grow.
        var words = split(open.lastWord)
        let last = words.removeLast()
        var wrapper = LineWrapper(width: width, row: open.row)
        for word in words {
            wrapper.add(word)
        }
        let row = wrapper.rows.removeLast()
        finished += wrapper.rows.map(StyledGrapheme.runs)
        let lastWord = (last.separator.map { [$0] } ?? []) + last.items
        let tail = place(lastWord, after: row, width: width).map(StyledGrapheme.runs)
        return (finished + tail, WrapCheckpoint(runs: runs, finished: finished, row: row, lastWord: lastWord))
    }

    /// The rows `graphemes` take after `row`.
    private static func place(
        _ graphemes: [StyledGrapheme], after row: [StyledGrapheme], width: Int
    )
        -> [[StyledGrapheme]]
    {
        var wrapper = LineWrapper(width: width, row: row)
        for word in split(graphemes) {
            wrapper.add(word)
        }
        return wrapper.rows
    }

    /// What `runs` adds to `old`, when `runs` is `old` with text appended
    /// that can be wrapped on its own: no tab, whose columns depend on the
    /// line before it, and no character that joins the last one of `old`.
    private static func appended(to old: [StyledRun], in runs: [StyledRun]) -> [StyledRun]? {
        guard let lastOld = old.last, runs.count >= old.count else { return nil }
        let shared = old.count - 1
        guard runs.prefix(shared).elementsEqual(old.prefix(shared)) else { return nil }
        let grown = runs[shared]
        guard grown.style == lastOld.style, grown.text.hasPrefix(lastOld.text) else { return nil }
        let rest = String(grown.text.utf8.dropFirst(lastOld.text.utf8.count)) ?? ""
        var added = [StyledRun(text: rest, style: grown.style)] + runs.dropFirst(old.count)
        added.removeAll { $0.text.isEmpty }
        guard !added.contains(where: { $0.text.contains("\t") }) else { return nil }
        if let end = old.last(where: { !$0.text.isEmpty })?.text.last, let start = added.first?.text.first {
            guard (String(end) + String(start)).count == 2 else { return nil }
        }
        return added.isEmpty ? [StyledRun(text: "", style: grown.style)] : added
    }
}

/// What word wrapping looks at in a text: each word's width and whether a
/// space comes before it, worked out once so the text can be measured at any
/// width without laying out its lines. Measuring a long scrollback at a new
/// width (a resize) then costs a pass over word widths per text, and only the
/// text on screen is laid out.
struct WrapMetrics {
    fileprivate struct Word {
        var hasSpace: Bool
        /// The width wrapping counts.
        var width: Int
        /// The width the laid-out row shows (`TextMetrics` of its text).
        var shownWidth: Int
        /// Where its graphemes' widths are in ``Line/graphemeWidths``, for
        /// breaking a word wider than a line.
        var graphemes: Range<Int>
    }

    fileprivate struct Line {
        var words: [Word]
        var graphemeWidths: [Int]
        var shownWidths: [Int]
    }

    private let lines: [Line]

    init(_ runs: [StyledRun]) {
        lines = TextLayout.lines(runs).map { line in
            var words: [Word] = []
            var widths: [Int] = []
            var shown: [Int] = []
            var current = Word(hasSpace: false, width: 0, shownWidth: 0, graphemes: 0..<0)
            for grapheme in StyledGrapheme.graphemes(of: line) {
                if grapheme.character == " " {
                    words.append(current)
                    current = Word(hasSpace: true, width: 0, shownWidth: 0, graphemes: widths.count..<widths.count)
                    continue
                }
                widths.append(grapheme.width)
                shown.append(TextMetrics.width(of: grapheme.character))
                current.width += grapheme.width
                current.shownWidth += shown[shown.count - 1]
                current.graphemes = current.graphemes.lowerBound..<widths.count
            }
            words.append(current)
            return Line(words: words, graphemeWidths: widths, shownWidths: shown)
        }
    }

    /// The size ``TextLayout/wrap(_:width:)`` lays the text out in at
    /// `width` (at least 1): the widest row and the number of rows.
    func size(width: Int) -> Size {
        var measurer = RowMeasurer(width: width)
        for line in lines {
            measurer.startLine()
            for word in line.words {
                measurer.add(word, in: line)
            }
        }
        measurer.finish()
        return Size(width: measurer.widest, height: measurer.rows)
    }
}

/// ``TextLayout``'s line wrapper, counting rows and their widths instead of
/// filling them; it must decide every break the same way.
private struct RowMeasurer {
    let width: Int
    var rows = 0
    var widest = 0
    /// The open row's width as wrapping counts it, and as it is shown.
    var rowWidth = 0
    var rowShown = 0

    init(width: Int) {
        self.width = width
    }

    mutating func startLine() {
        if rows > 0 { closeRow() }
        rows += 1
    }

    mutating func finish() {
        widest = max(widest, rowShown)
    }

    private mutating func closeRow() {
        widest = max(widest, rowShown)
        rowWidth = 0
        rowShown = 0
    }

    private mutating func newRow() {
        closeRow()
        rows += 1
    }

    mutating func add(_ word: WrapMetrics.Word, in line: WrapMetrics.Line) {
        if word.hasSpace {
            if rowWidth >= width { newRow() }
            rowWidth += 1
            rowShown += 1
        }
        if word.width > width {
            let remaining = width - rowWidth
            let breaksThisLine = 1 + (word.width - remaining - 1) / width
            let breaksNextLine = (word.width - 1) / width
            if breaksNextLine < breaksThisLine { newRow() }
            breakWord(word, in: line)
            return
        }
        if rowWidth + word.width > width && rowWidth > 0 && word.width > 0 { newRow() }
        rowWidth += word.width
        rowShown += word.shownWidth
    }

    /// As `TextLayout.breakWord`: fills rows a grapheme at a time.
    private mutating func breakWord(_ word: WrapMetrics.Word, in line: WrapMetrics.Line) {
        var visible = rowWidth
        for index in word.graphemes {
            let graphemeWidth = line.graphemeWidths[index]
            if visible + graphemeWidth <= width || rowWidth == 0 {
                rowWidth += graphemeWidth
                rowShown += line.shownWidths[index]
            } else {
                newRow()
                rowWidth = graphemeWidth
                rowShown = line.shownWidths[index]
                visible = 0
            }
            visible += graphemeWidth
            if visible >= width && index < word.graphemes.upperBound - 1 {
                newRow()
                visible = 0
            }
        }
    }
}
