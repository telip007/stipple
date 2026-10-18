/// A grid of terminal cells that views draw into (the port of Ink's `Output`).
///
/// Each cell holds one grapheme cluster and a style. A wide character takes
/// two cells: the first holds the glyph and the second is marked as its
/// continuation. Drawing never leaves half of a wide character behind: when a
/// write, fill or clip edge cuts one, the remaining cell becomes a space that
/// keeps its own style.
struct Canvas: Sendable {
    /// A cell as seen from outside the canvas.
    struct Cell: Hashable, Sendable {
        /// The grapheme cluster, or a space for blanks and continuations.
        var grapheme: Character
        /// How the cell is painted.
        var style: Style
        /// Whether this is the right half of a wide character.
        var isContinuation: Bool
    }

    struct Storage: Sendable {
        var grapheme: Character
        var styleID: UInt32
        var isContinuation: Bool
    }

    /// Columns.
    let width: Int
    /// Rows.
    let height: Int
    var cells: [Storage]
    /// Interned styles; cells refer to them by index. Index 0 is `.plain`.
    var styles: [Style] = [.plain]
    var styleIDs: [Style: UInt32] = [.plain: 0]

    /// Creates a canvas of blank, unstyled cells. Negative sizes become 0.
    init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        cells = Array(
            repeating: Storage(grapheme: " ", styleID: 0, isContinuation: false),
            count: self.width * self.height,
        )
    }

    /// The area the canvas covers.
    var bounds: Rect { Rect(x: 0, y: 0, width: width, height: height) }

    /// The cell at a column and row, or `nil` outside the canvas.
    func cell(x: Int, y: Int) -> Cell? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let storage = cells[y * width + x]
        let style = styles[Int(storage.styleID)]
        return Cell(grapheme: storage.grapheme, style: style, isContinuation: storage.isContinuation)
    }

    /// The text of every row without styling, continuation cells skipped.
    /// Trailing spaces are kept.
    func plainLines() -> [String] {
        (0..<height).map { row in
            var line = ""
            for index in (row * width)..<((row + 1) * width) where !cells[index].isContinuation {
                line.append(cells[index].grapheme)
            }
            return line
        }
    }

    // MARK: - Fill

    /// Sets the background of every cell in `rect` (limited to `clip` and the canvas)
    /// and keeps their characters and other style properties.
    ///
    /// A wide character cut by the rectangle's left or right edge becomes
    /// two spaces, so no glyph is half colored.
    mutating func fill(_ rect: Rect, background: Color, clip: Rect? = nil) {
        let area = visibleArea(rect, clip: clip)
        guard !area.isEmpty else { return }
        for row in area.minY..<area.maxY {
            let base = row * width
            if area.minX > 0, cells[base + area.minX].isContinuation {
                blank(base + area.minX - 1)
                blank(base + area.minX)
            }
            if area.maxX < width, cells[base + area.maxX].isContinuation {
                blank(base + area.maxX)
                blank(base + area.maxX - 1)
            }
            var lastOld: UInt32?
            var lastNew: UInt32 = 0
            for index in (base + area.minX)..<(base + area.maxX) {
                let old = cells[index].styleID
                if old != lastOld {
                    var style = styles[Int(old)]
                    style.background = background
                    lastNew = intern(style)
                    lastOld = old
                }
                cells[index].styleID = lastNew
            }
        }
    }

    // MARK: - Helpers

    /// `rect` limited to the canvas and to `clip`.
    func visibleArea(_ rect: Rect, clip: Rect?) -> Rect {
        let inside = rect.intersection(bounds)
        return clip.map { inside.intersection($0) } ?? inside
    }

    mutating func intern(_ style: Style) -> UInt32 {
        if let id = styleIDs[style] { return id }
        let id = UInt32(styles.count)
        styles.append(style)
        styleIDs[style] = id
        return id
    }

    /// Replaces a cell's glyph with a space and keeps its style.
    mutating func blank(_ index: Int) {
        cells[index].grapheme = " "
        cells[index].isContinuation = false
    }
}
