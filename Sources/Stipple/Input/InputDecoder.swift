/// The outcome of decoding the bytes at the start of the buffer.
enum InputToken {
    /// The bytes do not yet decide what the token is; keep them for the next chunk.
    case incomplete
    /// The token spans `length` bytes. `events` is empty for sequences Stipple does not map.
    case consumed(length: Int, events: [InputEvent])
    /// `ESC [ 2 0 0 ~` opened a bracketed paste; the token spans `length` bytes.
    case pasteStart(length: Int)
}

/// Byte values the decoder compares against.
enum InputBytes {
    static let escape: UInt8 = 0x1B
    static let bracket = UInt8(ascii: "[")
    static let semicolon = UInt8(ascii: ";")
    static let dollar = UInt8(ascii: "$")
    static let caret = UInt8(ascii: "^")
    static let tilde = UInt8(ascii: "~")
    static let ss3 = UInt8(ascii: "O")
    static let kittyFinal = UInt8(ascii: "u")
    /// `ESC [ M` starts an X10 mouse report.
    static let x10Mouse = UInt8(ascii: "M")
    /// Bytes that identify the start of a bracketed paste marker.
    static let pasteStartPrefix: [UInt8] = Array("\u{1B}[200".utf8)
    /// The marker that ends a bracketed paste.
    static let pasteEnd: [UInt8] = Array("\u{1B}[201~".utf8)
}

/// Decodes one token at a time from a byte buffer.
enum InputDecoder {
    /// Decodes the token that starts at `start`. `start` must index a byte of `input`.
    static func token(in input: [UInt8], at start: Int) -> InputToken {
        let byte = input[start]
        if byte == InputBytes.escape {
            return escapeToken(in: input, at: start)
        }
        if isControl(byte) {
            return .consumed(length: 1, events: [.key(ControlKeys.press(for: byte))])
        }
        return textToken(in: input, at: start)
    }

    /// Whether `byte` is a C0 control or DEL. Such bytes are never part of a text run.
    static func isControl(_ byte: UInt8) -> Bool {
        byte < 0x20 || byte == 0x7F
    }

    /// Decodes a run of printable text up to the next control byte, one key press per grapheme.
    /// An incomplete UTF-8 character at the very end of the buffer is left for the next chunk.
    static func textToken(in input: [UInt8], at start: Int) -> InputToken {
        var end = start
        while end < input.count, !isControl(input[end]) {
            end += 1
        }
        let complete = end == input.count ? end - incompleteUTF8Tail(in: input, from: start, to: end) : end
        guard complete > start else { return .incomplete }
        let text = Self.utf8String(input[start..<complete])
        return .consumed(length: complete - start, events: text.map { InputEvent.key(keyPress(for: $0)) })
    }

    /// The key press for one typed character. An uppercase letter is reported as its lowercase key
    /// with Shift, and `characters` keeps the typed letter, as Ink does.
    static func keyPress(for character: Character, modifiers: EventModifiers = []) -> KeyPress {
        var modifiers = modifiers
        if character.isUppercase {
            modifiers.insert(.shift)
        }
        return KeyPress(key: .character(lowercased(character)), characters: String(character), modifiers: modifiers)
    }

    /// The lowercase form of `character` when it is a single character, otherwise `character` itself.
    static func lowercased(_ character: Character) -> Character {
        let lowered = character.lowercased()
        return lowered.count == 1 ? Character(lowered) : character
    }

    /// Decodes UTF-8 bytes; invalid sequences become U+FFFD, as `String(decoding:as:)` does.
    static func utf8String(_ bytes: some Collection<UInt8>) -> String {
        var text = ""
        var decoder = UTF8()
        var iterator = bytes.makeIterator()
        while true {
            switch decoder.decode(&iterator) {
            case .scalarValue(let scalar): text.unicodeScalars.append(scalar)
            case .emptyInput: return text
            case .error: text.unicodeScalars.append("\u{FFFD}")
            }
        }
    }

    /// The first index of `needle` in `haystack` at or after `start`.
    static func firstIndex(of needle: [UInt8], in haystack: [UInt8], from start: Int) -> Int? {
        var index = start
        while index + needle.count <= haystack.count {
            if haystack[index..<(index + needle.count)].elementsEqual(needle) {
                return index
            }
            index += 1
        }
        return nil
    }

    /// The byte length of the UTF-8 sequence that starts at `index`, or `nil` when the buffer ends
    /// before it is complete. An invalid sequence counts as one byte, which decodes to U+FFFD.
    static func utf8SequenceLength(in input: [UInt8], at index: Int) -> Int? {
        let needed = expectedUTF8Length(input[index])
        for offset in 1..<needed where index + offset < input.count {
            if input[index + offset] & 0xC0 != 0x80 {
                return 1
            }
        }
        return index + needed <= input.count ? needed : nil
    }

    /// How many bytes at the end of `input[start..<end]` form a UTF-8 character that is not finished yet.
    static func incompleteUTF8Tail(in input: [UInt8], from start: Int, to end: Int) -> Int {
        var lead = end - 1
        while lead > start, end - lead < 4, input[lead] & 0xC0 == 0x80 {
            lead -= 1
        }
        let available = end - lead
        return expectedUTF8Length(input[lead]) > available ? available : 0
    }

    /// The length of a UTF-8 sequence from its lead byte. Continuation bytes and invalid leads count as 1.
    static func expectedUTF8Length(_ lead: UInt8) -> Int {
        switch lead {
        case 0xC0..<0xE0: return 2
        case 0xE0..<0xF0: return 3
        case 0xF0..<0xF8: return 4
        default: return 1
        }
    }
}

/// Control bytes that stand for keys. Ctrl+letter bytes are 0x01 to 0x1A.
enum ControlKeys {
    /// The key for a control byte. `option` adds Option, for an ESC-prefixed byte.
    static func press(for byte: UInt8, option: Bool = false) -> KeyPress {
        let named = named(for: byte)
        let optionModifier: EventModifiers = option ? [.option] : []
        return KeyPress(key: named.key, characters: named.characters, modifiers: named.modifiers.union(optionModifier))
    }

    /// The key, its text and modifiers. Tab, Return and Backspace keep their own names, as in Ink.
    private static func named(for byte: UInt8) -> NamedKey {
        switch byte {
        case 0x00: return NamedKey(.character(" "), characters: " ", modifiers: .control)
        case 0x08, 0x7F: return NamedKey(.backspace)
        case 0x09: return NamedKey(.tab, characters: "\t")
        case 0x0A: return NamedKey(.return, characters: "\n")
        case 0x0D: return NamedKey(.return, characters: "\r")
        case 0x01...0x1A:
            let letter = Character(Unicode.Scalar(byte + 0x60))
            return NamedKey(.character(letter), characters: String(letter), modifiers: .control)
        default:
            // 0x1C to 0x1F, which Ctrl turns into `\`, `]`, `^` and `_`.
            let symbol = Character(Unicode.Scalar(byte + 0x40))
            return NamedKey(.character(symbol), characters: String(symbol), modifiers: .control)
        }
    }
}
