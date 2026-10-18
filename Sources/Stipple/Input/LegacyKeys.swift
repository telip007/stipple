/// A key named by a sequence, before the modifier parameter is applied.
struct NamedKey: Sendable {
    /// The key.
    let key: KeyEquivalent
    /// The text the key produces, if any. A kitty text field can replace it.
    var characters: String
    /// Modifiers implied by the sequence itself, such as rxvt Shift arrows.
    let modifiers: EventModifiers

    /// Creates a named key.
    init(_ key: KeyEquivalent, characters: String = "", modifiers: EventModifiers = []) {
        self.key = key
        self.characters = characters
        self.modifiers = modifiers
    }
}

/// Keys from xterm, VT and rxvt sequences (`ESC [`, `ESC O`) without the kitty protocol.
enum LegacyKeys {
    /// Decodes a complete CSI body and its final byte, where the body is the text between `ESC [` and the final byte.
    static func csiEvents(body: String, final: UInt8) -> [InputEvent] {
        if body.hasPrefix("?") {
            return final == InputBytes.kittyFinal ? KittyKeys.queryReply(body) : []
        }
        if body.isEmpty, final == UInt8(ascii: "I") {
            return [.focus(true)]
        }
        if body.isEmpty, final == UInt8(ascii: "O") {
            return [.focus(false)]
        }
        if final == InputBytes.kittyFinal {
            return KittyKeys.keyEvents(body: body)
        }
        let fields = splitFields(body)
        guard let named = csi[name(head: fields.head, final: final)] else { return [] }
        return [.key(KittyKeys.keyPress(named, modifierField: fields.modifiers))]
    }

    /// Decodes a complete SS3 body and its final byte, where the body holds only the modifier parameter.
    static func ss3Events(body: String, final: UInt8) -> [InputEvent] {
        let fields = splitFields(body)
        guard let named = ss3[String(Character(Unicode.Scalar(final)))] else { return [] }
        return [.key(KittyKeys.keyPress(named, modifierField: fields.modifiers))]
    }

    /// The first parameter and the modifier field (`modifiers[:event]`) of a sequence.
    static func splitFields(_ body: String) -> (head: Substring, modifiers: Substring) {
        let fields = body.split(separator: ";", omittingEmptySubsequences: false)
        return (fields.first ?? "", fields.count > 1 ? fields[1] : "")
    }

    /// The table key for a CSI with `head` as its first parameter. Tilde, `$` and `^` finals and
    /// Linux `ESC [ [` keys need the head; letter finals ignore it.
    static func name(head: Substring, final: UInt8) -> String {
        let letter = String(Character(Unicode.Scalar(final)))
        let needsHead = head.hasPrefix("[") || [InputBytes.tilde, InputBytes.dollar, InputBytes.caret].contains(final)
        return needsHead ? String(head) + letter : letter
    }

    /// CSI keys, keyed by the head parameter plus a tilde, `$` or `^` final, or by the bare letter.
    static let csi: [String: NamedKey] = [
        "A": NamedKey(.upArrow),
        "B": NamedKey(.downArrow),
        "C": NamedKey(.rightArrow),
        "D": NamedKey(.leftArrow),
        "F": NamedKey(.end),
        "H": NamedKey(.home),
        "P": NamedKey(.function(1)),
        "Q": NamedKey(.function(2)),
        "R": NamedKey(.function(3)),
        "S": NamedKey(.function(4)),
        "Z": NamedKey(.tab, characters: "\t", modifiers: .shift),
        "a": NamedKey(.upArrow, modifiers: .shift),
        "b": NamedKey(.downArrow, modifiers: .shift),
        "c": NamedKey(.rightArrow, modifiers: .shift),
        "d": NamedKey(.leftArrow, modifiers: .shift),
        "[A": NamedKey(.function(1)),
        "[B": NamedKey(.function(2)),
        "[C": NamedKey(.function(3)),
        "[D": NamedKey(.function(4)),
        "[E": NamedKey(.function(5)),
        "[5~": NamedKey(.pageUp),
        "[6~": NamedKey(.pageDown),
        "1~": NamedKey(.home),
        "2~": NamedKey(.insert),
        "3~": NamedKey(.delete),
        "4~": NamedKey(.end),
        "5~": NamedKey(.pageUp),
        "6~": NamedKey(.pageDown),
        "7~": NamedKey(.home),
        "8~": NamedKey(.end),
        "11~": NamedKey(.function(1)),
        "12~": NamedKey(.function(2)),
        "13~": NamedKey(.function(3)),
        "14~": NamedKey(.function(4)),
        "15~": NamedKey(.function(5)),
        "17~": NamedKey(.function(6)),
        "18~": NamedKey(.function(7)),
        "19~": NamedKey(.function(8)),
        "20~": NamedKey(.function(9)),
        "21~": NamedKey(.function(10)),
        "23~": NamedKey(.function(11)),
        "24~": NamedKey(.function(12)),
        "2$": NamedKey(.insert, modifiers: .shift),
        "3$": NamedKey(.delete, modifiers: .shift),
        "5$": NamedKey(.pageUp, modifiers: .shift),
        "6$": NamedKey(.pageDown, modifiers: .shift),
        "7$": NamedKey(.home, modifiers: .shift),
        "8$": NamedKey(.end, modifiers: .shift),
        "2^": NamedKey(.insert, modifiers: .control),
        "3^": NamedKey(.delete, modifiers: .control),
        "5^": NamedKey(.pageUp, modifiers: .control),
        "6^": NamedKey(.pageDown, modifiers: .control),
        "7^": NamedKey(.home, modifiers: .control),
        "8^": NamedKey(.end, modifiers: .control),
    ]

    /// SS3 keys, keyed by the final byte. The keypad Enter sends `ESC O M` and types a carriage return.
    static let ss3: [String: NamedKey] = [
        "A": NamedKey(.upArrow),
        "B": NamedKey(.downArrow),
        "C": NamedKey(.rightArrow),
        "D": NamedKey(.leftArrow),
        "F": NamedKey(.end),
        "H": NamedKey(.home),
        "M": NamedKey(.return, characters: "\r"),
        "P": NamedKey(.function(1)),
        "Q": NamedKey(.function(2)),
        "R": NamedKey(.function(3)),
        "S": NamedKey(.function(4)),
        "a": NamedKey(.upArrow, modifiers: .control),
        "b": NamedKey(.downArrow, modifiers: .control),
        "c": NamedKey(.rightArrow, modifiers: .control),
        "d": NamedKey(.leftArrow, modifiers: .control),
    ]
}
