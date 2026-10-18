/// Progressive-enhancement flags of the kitty keyboard protocol.
///
/// Pass them to ``Terminal/pushKittyKeyboard(_:)``. See
/// <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>.
public struct KittyKeyboardFlags: OptionSet, Hashable, Sendable {
    /// The raw bit mask sent to the terminal.
    public let rawValue: Int

    /// Creates flags from a raw bit mask.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Report ambiguous keys (Escape, Ctrl-letter, modified keys) as unambiguous `CSI u` sequences.
    public static let disambiguateEscapeCodes = Self(rawValue: 1)
    /// Report key press, repeat and release events.
    public static let reportEventTypes = Self(rawValue: 2)
    /// Report shifted and base-layout key codes alongside the primary one.
    public static let reportAlternateKeys = Self(rawValue: 4)
    /// Report every key, including plain text, as an escape code.
    public static let reportAllKeysAsEscapeCodes = Self(rawValue: 8)
    /// Include the text a key produces in its escape code. Needs ``reportAllKeysAsEscapeCodes``.
    public static let reportAssociatedText = Self(rawValue: 16)

    /// The flags as they are sent on the wire: associated text is only defined
    /// when all keys are reported, so it implies ``reportAllKeysAsEscapeCodes``
    /// (Ink's `resolveFlags`).
    var resolved: Self {
        contains(.reportAssociatedText) ? union(.reportAllKeysAsEscapeCodes) : self
    }
}
