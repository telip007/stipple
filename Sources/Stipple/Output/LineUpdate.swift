/// Builds the update for one changed line. When the line's identical styled
/// prefix can stay on screen, only the rest is repainted. Port of `line-update.ts`.
///
/// Lines are compared by grapheme cluster (`Character`), where Ink compares
/// UTF-16 code units. The results match for the text the frame writer sees.
func lineUpdate(previous: String, next: String, columns: Int) -> String {
    // Erase from column 0 before painting. This clears sparse gaps as well.
    let full = Escape.cursorTo(0) + Escape.eraseEndLine + next
    guard columns >= 1 else { return full }

    let previousChars = Array(previous)
    let nextChars = Array(next)
    let commonLength = commonPrefixLength(previousChars, nextChars)
    guard commonLength > 0 else { return full }

    let previousMatches = sgrMatches(previousChars)
    let nextMatches = sgrMatches(nextChars)
    let previousText = removing(previousMatches, from: previousChars)
    let nextText = removing(nextMatches, from: nextChars)
    guard !hasControl(previousText), !hasControl(nextText) else { return full }

    // A difference inside an SGR sequence must repaint from before that sequence.
    var textLimit = commonLength
    for match in nextMatches where match.start < commonLength {
        textLimit -= min(match.length, commonLength - match.start)
    }

    let textLength = matchingTextLength(previousText, nextText, limit: textLimit)
    let column = DisplayWidth.of(String(nextText.prefix(textLength)))

    // CHA clamps at the last cell. It cannot reproduce a wrap-pending cursor after
    // a full-width prefix, so such lines are repainted whole.
    let tailWidths = (
        previous: DisplayWidth.of(String(previousText.dropFirst(textLength))),
        next: DisplayWidth.of(String(nextText.dropFirst(textLength)))
    )
    if column == 0 || column >= columns || column + tailWidths.previous > columns || column + tailWidths.next > columns
    {
        return full
    }

    // Replay the exact SGR history so nested resets and extended colors match a full write.
    let (offset, styles) = replayedStyles(nextMatches, start: textLength, commonLength: commonLength)
    let partial = Escape.cursorTo(column) + Escape.eraseEndLine + styles + String(nextChars.dropFirst(offset))
    return partial.utf16.count < full.utf16.count ? partial : full
}

/// An SGR sequence (`ESC [ digits or ; m`) found in a line, in grapheme units.
private struct SGRMatch {
    /// Index of the `ESC` character.
    let start: Int
    /// Number of characters, including the `ESC` and the final `m`.
    let length: Int
    /// The sequence itself.
    let text: String
}

/// Finds every SGR sequence in `characters`.
private func sgrMatches(_ characters: [Character]) -> [SGRMatch] {
    var matches: [SGRMatch] = []
    var index = 0
    while index + 1 < characters.count {
        guard characters[index] == "\u{1B}", characters[index + 1] == "[" else {
            index += 1
            continue
        }
        var end = index + 2
        while end < characters.count, characters[end].isASCIIDigitOrSemicolon {
            end += 1
        }
        guard end < characters.count, characters[end] == "m" else {
            index += 1
            continue
        }
        let text = String(characters[index...end])
        matches.append(SGRMatch(start: index, length: end - index + 1, text: text))
        index = end + 1
    }
    return matches
}

/// `characters` with the SGR sequences in `matches` removed.
private func removing(_ matches: [SGRMatch], from characters: [Character]) -> [Character] {
    var plain: [Character] = []
    var index = 0
    for match in matches {
        plain += characters[index..<match.start]
        index = match.start + match.length
    }
    plain += characters[index...]
    return plain
}

/// The number of leading characters both lines share.
private func commonPrefixLength(_ lhs: [Character], _ rhs: [Character]) -> Int {
    var length = 0
    while length < lhs.count, length < rhs.count, lhs[length] == rhs[length] {
        length += 1
    }
    return length
}

/// Whether any scalar in `characters` is a control character. Controls other
/// than SGR could move the cursor, so such lines are repainted whole.
private func hasControl(_ characters: [Character]) -> Bool {
    characters.contains { character in
        character.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}

/// The length of the plain text that matches on both sides, up to `limit`.
/// Only whole grapheme clusters count.
private func matchingTextLength(_ previous: [Character], _ next: [Character], limit: Int) -> Int {
    var length = 0
    for index in next.indices {
        guard index + 1 <= limit, index < previous.count, previous[index] == next[index] else { break }
        length = index + 1
    }
    return length
}

/// The offset in `next` up to which SGR sequences are replayed, and their concatenated text.
///
/// The offset starts at the plain text length, as Ink does, and walks the SGR
/// matches that lie before the common prefix.
private func replayedStyles(_ matches: [SGRMatch], start: Int, commonLength: Int) -> (Int, String) {
    var offset = start
    var styles = ""
    for match in matches {
        if match.start > offset || match.start + match.length > commonLength {
            break
        }
        offset += match.length
        styles += match.text
    }
    return (offset, styles)
}

extension Character {
    /// `0`–`9`, `;`. The bytes SGR parameters are made of.
    fileprivate var isASCIIDigitOrSemicolon: Bool {
        self == ";" || ("0"..."9").contains(self)
    }
}
