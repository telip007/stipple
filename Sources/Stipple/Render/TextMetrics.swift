/// Display width of text in terminal cells (the behaviour of Ink's
/// `string-width`, `widest-line` and `measure-text`).
///
/// Width is measured per grapheme cluster: East Asian wide and fullwidth
/// characters and emoji take two cells; combining marks, zero-width characters
/// and control characters take none. Input is plain text. Escape sequences
/// are not interpreted, so parse them with ``ANSIText`` first.
public enum TextMetrics {
    /// The number of terminal cells `text` occupies on one line.
    ///
    /// Newlines are control characters and count as zero, so measure each
    /// line on its own.
    public static func width(of text: some StringProtocol) -> Int {
        var total = 0
        for byte in text.utf8 {
            if byte >= 0x80 { return text.reduce(0) { $0 + width(of: $1) } }
            if byte >= 0x20 && byte != 0x7F { total += 1 }
        }
        return total
    }

    /// The number of terminal cells one grapheme cluster occupies: 0, 1 or 2.
    public static func width(of character: Character) -> Int {
        if let ascii = character.asciiValue {
            return ascii >= 0x20 && ascii != 0x7F ? 1 : 0
        }
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return 0 }
        if scalars.count == 1 { return scalarWidth(first) }
        return clusterWidth(scalars)
    }

    /// The width and height of `text` when laid out without wrapping: the
    /// widest line and the number of lines. Empty text is 0 by 0.
    public static func measure(_ text: String) -> Size {
        guard !text.isEmpty else { return .zero }
        var widest = 0
        var height = 0
        for line in text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false) {
            widest = max(widest, width(of: String(line)))
            height += 1
        }
        return Size(width: widest, height: height)
    }

    /// Like ``measure(_:)-(String)`` for styled runs.
    static func measure(_ runs: [StyledRun]) -> Size {
        guard runs.contains(where: { !$0.text.isEmpty }) else { return .zero }
        let lines = TextLayout.lines(runs)
        let widest = lines.map { $0.reduce(0) { $0 + width(of: $1.text) } }.max() ?? 0
        return Size(width: widest, height: lines.count)
    }

    // MARK: - Scalars and clusters

    private static func scalarWidth(_ scalar: Unicode.Scalar) -> Int {
        let value = scalar.value
        if value < 0x300 {
            return value >= 0xA0 && value != 0xAD ? 1 : 0
        }
        if isNonPrinting(scalar) { return 0 }
        if EastAsianWidth.isWide(value) { return 2 }
        return !isRegionalIndicator(value) && scalar.properties.isEmojiPresentation ? 2 : 1
    }

    private static func clusterWidth(_ scalars: String.UnicodeScalarView) -> Int {
        guard let start = scalars.firstIndex(where: { !isNonPrinting($0) }) else { return 0 }
        let base = scalars[start]
        let rest = scalars[scalars.index(after: start)...]
        if isEmojiCluster(base, rest: rest) { return 2 }
        var total = EastAsianWidth.isWide(base.value) ? 2 : 1
        // Halfwidth and fullwidth forms combine into one cluster (for example
        // a halfwidth katakana with its voiced sound mark) and keep their width.
        for scalar in rest where (0xFF00...0xFFEF).contains(scalar.value) {
            total += EastAsianWidth.isWide(scalar.value) ? 2 : 1
        }
        return total
    }

    private static func isEmojiCluster(_ base: Unicode.Scalar, rest: Substring.UnicodeScalarView) -> Bool {
        if isRegionalIndicator(base.value) { return rest.contains { isRegionalIndicator($0.value) } }
        if base.properties.isEmojiPresentation { return true }
        return base.properties.isEmoji && rest.contains { $0.value == 0xFE0F }
    }

    private static func isRegionalIndicator(_ value: UInt32) -> Bool {
        (0x1F1E6...0x1F1FF).contains(value)
    }

    /// Controls, marks and format characters take no cell of their own.
    private static func isNonPrinting(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value < 0x20 || (0x7F..<0xA0).contains(scalar.value) { return true }
        if scalar.properties.isDefaultIgnorableCodePoint { return true }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .format, .control, .surrogate: return true
        default: return false
        }
    }
}
