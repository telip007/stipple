/// Terminal column width of text, used by the line diff to find where a
/// changed line starts.
///
/// This is a compact stand-in for `string-width`: wide East Asian and emoji
/// characters take two columns, and combining or format scalars take none.
enum DisplayWidth {
    /// The number of terminal columns `text` occupies.
    static func of(_ text: String) -> Int {
        text.reduce(0) { $0 + width(of: $1) }
    }

    private static func width(of character: Character) -> Int {
        guard let first = character.unicodeScalars.first else { return 0 }
        if isZeroWidth(first) {
            return 0
        }
        return isWide(first) ? 2 : 1
    }

    private static func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format, .control:
            true
        default:
            false
        }
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isEmojiPresentation {
            return true
        }
        return wideRanges.contains { $0.contains(scalar.value) }
    }

    private static let wideRanges: [ClosedRange<UInt32>] = [
        0x1100...0x115F,
        0x2E80...0xA4CF,
        0xAC00...0xD7A3,
        0xF900...0xFAFF,
        0xFE30...0xFE4F,
        0xFF00...0xFF60,
        0xFFE0...0xFFE6,
        0x1F300...0x1F64F,
        0x1F900...0x1F9FF,
        0x20000...0x3FFFD,
    ]
}
