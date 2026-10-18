extension Canvas {
    /// Draws one line of text with its top-left at `origin`.
    ///
    /// Everything outside `clip` (and the canvas) is dropped. A wide
    /// character that sticks out of the clip leaves spaces in its visible
    /// columns. A write that lands inside a wide character blanks the half it
    /// does not cover. Zero-width marks join the previous character. Newlines
    /// and other control characters draw nothing.
    mutating func write(_ runs: [StyledRun], at origin: Point, clip: Rect? = nil) {
        let area = visibleArea(Rect(x: 0, y: 0, width: width, height: height), clip: clip)
        guard origin.y >= area.minY, origin.y < area.maxY else { return }
        var cursor = LineCursor(row: origin.y * width, x: origin.x, area: area)
        for run in runs {
            let styleID = intern(run.style)
            for character in run.text {
                if cursor.x >= area.maxX { break }
                put(character, styleID: styleID, cursor: &cursor)
            }
        }
        // The write may have ended inside a wide character that was there before.
        if cursor.startChecked, cursor.x < width, cells[cursor.row + cursor.x].isContinuation {
            blank(cursor.row + cursor.x)
        }
    }

    struct LineCursor {
        let row: Int
        var x: Int
        let area: Rect
        var startChecked = false
        /// Index and width of the last cell holding a glyph, for attaching marks.
        var lead: (index: Int, width: Int)?

        init(row: Int, x: Int, area: Rect) {
            self.row = row
            self.x = x
            self.area = area
        }
    }

    private mutating func put(_ character: Character, styleID: UInt32, cursor: inout LineCursor) {
        let glyphWidth = TextMetrics.width(of: character)
        guard glyphWidth > 0 else {
            attachMark(character, cursor: &cursor)
            return
        }
        let start = cursor.x
        let end = start + glyphWidth
        cursor.x = end
        let area = cursor.area
        guard end > area.minX else { return }
        beginWriting(at: max(start, area.minX), cursor: &cursor)
        if start < area.minX || end > area.maxX {
            // Only part of the glyph is visible: draw its visible columns as spaces.
            for column in max(start, area.minX)..<min(end, area.maxX) {
                set(cursor.row + column, " ", styleID)
            }
            cursor.lead = nil
            return
        }
        set(cursor.row + start, character, styleID)
        if glyphWidth == 2 { setContinuation(cursor.row + start + 1, styleID) }
        cursor.lead = (cursor.row + start, glyphWidth)
    }

    /// The first visible cell of a write may be the right half of a wide character.
    private mutating func beginWriting(at column: Int, cursor: inout LineCursor) {
        guard !cursor.startChecked else { return }
        cursor.startChecked = true
        if column > 0, cells[cursor.row + column].isContinuation { blank(cursor.row + column - 1) }
    }

    private mutating func attachMark(_ mark: Character, cursor: inout LineCursor) {
        guard let lead = cursor.lead,
            let merged = StyledGrapheme.merge(cells[lead.index].grapheme, mark)
        else { return }
        cells[lead.index].grapheme = merged
        let grown = TextMetrics.width(of: merged)
        // A variation selector can turn a narrow glyph into a wide one.
        if grown > lead.width, cursor.x < cursor.area.maxX {
            setContinuation(cursor.row + cursor.x, cells[lead.index].styleID)
            cursor.x += 1
            cursor.lead = (lead.index, grown)
        }
    }

    private mutating func set(_ index: Int, _ character: Character, _ styleID: UInt32) {
        cells[index] = Storage(grapheme: character, styleID: styleID, isContinuation: false)
    }

    private mutating func setContinuation(_ index: Int, _ styleID: UInt32) {
        cells[index] = Storage(grapheme: " ", styleID: styleID, isContinuation: true)
    }
}
