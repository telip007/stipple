/// One grapheme cluster with its style and display width. The unit that
/// wrapping and truncation work on.
struct StyledGrapheme: Equatable {
    var character: Character
    var style: Style
    var width: Int
}

extension StyledGrapheme {
    /// Splits runs into graphemes. Zero-width marks (accents, variation
    /// selectors) join the preceding grapheme and keep its style, as terminals
    /// draw them in the base character's cell. Other zero-width characters
    /// are dropped.
    static func graphemes(of runs: [StyledRun]) -> [Self] {
        var result: [Self] = []
        for run in runs {
            for character in run.text {
                let width = TextMetrics.width(of: character)
                if width > 0 {
                    result.append(Self(character: character, style: run.style, width: width))
                } else if let last = result.indices.last, let merged = merge(result[last].character, character) {
                    result[last].character = merged
                    result[last].width = max(result[last].width, TextMetrics.width(of: merged))
                }
            }
        }
        return result
    }

    /// `base` followed by a zero-width `mark`, if the two form one grapheme cluster.
    static func merge(_ base: Character, _ mark: Character) -> Character? {
        guard let first = mark.unicodeScalars.first, first.value >= 0xA0 else { return nil }
        let combined = String(base) + String(mark)
        return combined.count == 1 ? combined.first : nil
    }

    /// Joins graphemes back into runs, merging neighbours that share a style.
    static func runs(from graphemes: some Sequence<Self>) -> [StyledRun] {
        var result: [StyledRun] = []
        for grapheme in graphemes {
            if let last = result.indices.last, result[last].style == grapheme.style {
                result[last].text.append(grapheme.character)
            } else {
                result.append(StyledRun(text: String(grapheme.character), style: grapheme.style))
            }
        }
        return result
    }
}
