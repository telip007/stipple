/// The kitty keyboard protocol: `CSI codepoint[:shifted[:base]] ; modifiers[:event] ; text u`.
///
/// The modifier and event parameters also appear in legacy `CSI 1 ; modifiers X` sequences, so
/// those helpers live here too. Modifier values are `1 + bitmask`.
enum KittyKeys {
    /// Modifier bits, as the protocol numbers them. Alt and Meta are both Option here; Super is Command.
    private static let modifierBits: [(bit: Int, modifier: EventModifiers)] = [
        (1, .shift),
        (2, .option),
        (4, .control),
        (8, .command),
        (16, .hyper),
        (32, .option),
        (64, .capsLock),
        (128, .numLock),
    ]

    /// The modifiers for a modifier parameter. A missing or invalid parameter means none.
    static func modifiers(_ parameter: Int) -> EventModifiers {
        let bits = max(parameter - 1, 0)
        return modifierBits.reduce(into: EventModifiers()) { result, entry in
            if bits & entry.bit != 0 {
                result.insert(entry.modifier)
            }
        }
    }

    /// The phase for an event parameter: 1 press, 2 repeat, 3 release. A missing parameter is a press.
    static func phase(_ event: Int) -> KeyPress.Phase {
        switch event {
        case 2: return .`repeat`
        case 3: return .up
        default: return .down
        }
    }

    /// Builds a key press from a named key and the `modifiers[:event]` field of its sequence.
    static func keyPress(_ named: NamedKey, modifierField: Substring) -> KeyPress {
        let parts = modifierField.split(separator: ":", omittingEmptySubsequences: false)
        let parameter = parts.first.flatMap { Int($0) } ?? 1
        let event = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        return KeyPress(
            key: named.key,
            characters: named.characters,
            modifiers: named.modifiers.union(modifiers(parameter)),
            phase: phase(event),
        )
    }

    /// The events for a kitty `CSI … u` body (the text between `ESC [` and `u`).
    static func keyEvents(body: String) -> [InputEvent] {
        let fields = body.split(separator: ";", omittingEmptySubsequences: false)
        guard let codepoint = Int(fields[0].prefix(while: { $0 != ":" })),
            var named = namedKey(for: codepoint)
        else { return [] }
        if fields.count > 2, !fields[2].isEmpty {
            named.characters = decodeText(fields[2])
        }
        return [.key(keyPress(named, modifierField: fields.count > 1 ? fields[1] : ""))]
    }

    /// The events for a kitty keyboard query reply, `CSI ? flags u`.
    static func queryReply(_ body: String) -> [InputEvent] {
        guard let flags = Int(body.dropFirst()) else { return [] }
        return [.kittyKeyboardSupported(flags: flags)]
    }

    /// The text of a `codepoint:codepoint` field.
    static func decodeText(_ field: Substring) -> String {
        var text = ""
        for part in field.split(separator: ":") {
            if let value = UInt32(part), let scalar = Unicode.Scalar(value) {
                text.unicodeScalars.append(scalar)
            }
        }
        return text
    }

    /// The key for a codepoint. Codepoints that name no key (modifiers, lock keys, media keys,
    /// other control codes) return `nil`.
    static func namedKey(for codepoint: Int) -> NamedKey? {
        if let named = specialKeys[codepoint] {
            return named
        }
        if (57376...57398).contains(codepoint) {
            return NamedKey(.function(codepoint - 57363))
        }
        return printableKey(for: codepoint)
    }

    /// Named keys for codepoints outside the printable range.
    private static let specialKeys: [Int: NamedKey] = {
        var keys: [Int: NamedKey] = [
            9: NamedKey(.tab, characters: "\t"),
            13: NamedKey(.return, characters: "\r"),
            27: NamedKey(.escape),
            32: NamedKey(.character(" "), characters: " "),
            57414: NamedKey(.return, characters: "\r"),
            57417: NamedKey(.leftArrow),
            57418: NamedKey(.rightArrow),
            57419: NamedKey(.upArrow),
            57420: NamedKey(.downArrow),
            57421: NamedKey(.pageUp),
            57422: NamedKey(.pageDown),
            57423: NamedKey(.home),
            57424: NamedKey(.end),
            57425: NamedKey(.insert),
            57426: NamedKey(.delete),
            127: NamedKey(.backspace),
        ]
        for (offset, digit) in "0123456789".enumerated() {
            keys[57399 + offset] = NamedKey(.character(digit), characters: String(digit))
        }
        let symbols: [(Int, String)] = [
            (57409, "."), (57410, "/"), (57411, "*"), (57412, "-"), (57413, "+"), (57415, "="), (57416, ","),
        ]
        for (codepoint, symbol) in symbols {
            keys[codepoint] = NamedKey(.character(Character(symbol)), characters: symbol)
        }
        return keys
    }()

    /// A printable key. The key is the lowercase character; Shift comes only from the modifiers.
    private static func printableKey(for codepoint: Int) -> NamedKey? {
        guard codepoint >= 32, !(127...159).contains(codepoint), !(57344...63743).contains(codepoint),
            let value = UInt32(exactly: codepoint), let scalar = Unicode.Scalar(value)
        else { return nil }
        let character = Character(scalar)
        return NamedKey(.character(InputDecoder.lowercased(character)), characters: String(character))
    }
}
