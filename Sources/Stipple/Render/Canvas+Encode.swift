extension Canvas {
    /// The canvas as ANSI text, one string per row.
    ///
    /// Styles are switched with minimal SGR transitions and closed at the end
    /// of each row, so rows are independent. Trailing unstyled spaces are
    /// trimmed (Ink's `trimEnd`); styled trailing cells are kept. Hyperlinks
    /// use OSC 8 and are closed at the end of the row too. Colors are
    /// reduced to `colorDepth`.
    func encodedLines(colorDepth: ColorDepth = .trueColor) -> [String] {
        var encoder = RowEncoder(styles: styles.map { $0.reduced(to: colorDepth) })
        return (0..<height).map { encodeRow($0, encoder: &encoder) }
    }

    private func encodeRow(_ row: Int, encoder: inout RowEncoder) -> String {
        let base = row * width
        var end = width
        while end > 0, isTrimmable(cells[base + end - 1]) { end -= 1 }
        var line = ""
        var current: UInt32 = 0
        for index in base..<(base + end) where !cells[index].isContinuation {
            let next = cells[index].styleID
            if next != current {
                line += encoder.transition(from: current, to: next)
                current = next
            }
            line.append(cells[index].grapheme)
        }
        line += encoder.transition(from: current, to: 0)
        return line
    }

    private func isTrimmable(_ storage: Storage) -> Bool {
        storage.styleID == 0 && storage.grapheme == " "
    }
}

/// SGR transitions between the canvas's style ids, cached per pair.
private struct RowEncoder {
    let styles: [Style]
    var cache: [UInt64: String] = [:]

    mutating func transition(from old: UInt32, to new: UInt32) -> String {
        guard old != new else { return "" }
        let key = UInt64(old) << 32 | UInt64(new)
        if let cached = cache[key] { return cached }
        let sequence = SGR.transition(from: styles[Int(old)], to: styles[Int(new)])
        cache[key] = sequence
        return sequence
    }
}
