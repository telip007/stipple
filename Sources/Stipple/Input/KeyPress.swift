/// A key on the keyboard, independent of modifiers.
public enum KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
    /// A printable character, lowercased for letters typed with Shift held
    /// only when the terminal reports Shift separately (kitty protocol).
    case character(Character)
    /// The up arrow.
    case upArrow
    /// The down arrow.
    case downArrow
    /// The left arrow.
    case leftArrow
    /// The right arrow.
    case rightArrow
    /// Return or Enter, including keypad Enter.
    case `return`
    /// Escape.
    case escape
    /// Tab. Shift-Tab arrives as `.tab` with `.shift`.
    case tab
    /// Backspace (deletes to the left).
    case backspace
    /// Forward delete.
    case delete
    /// Insert.
    case insert
    /// Home.
    case home
    /// End.
    case end
    /// Page up.
    case pageUp
    /// Page down.
    case pageDown
    /// A function key, F1 = `.function(1)`.
    case function(Int)

    /// The space bar.
    public static let space = Self.character(" ")

    /// Creates a character key from a literal: `.onKeyPress("q")`.
    public init(extendedGraphemeClusterLiteral value: Character) {
        self = .character(value)
    }
}

/// Modifier keys held during a key press.
public struct EventModifiers: OptionSet, Hashable, Sendable {
    /// The raw bit mask.
    public let rawValue: UInt8

    /// Creates modifiers from a raw bit mask.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Shift.
    public static let shift = Self(rawValue: 1 << 0)
    /// Control.
    public static let control = Self(rawValue: 1 << 1)
    /// Option (Alt, or "meta" in terminal parlance).
    public static let option = Self(rawValue: 1 << 2)
    /// Command (the kitty protocol's "super"); only reported with the kitty protocol.
    public static let command = Self(rawValue: 1 << 3)
    /// Hyper; only reported with the kitty protocol.
    public static let hyper = Self(rawValue: 1 << 4)
    /// Caps Lock is on; only reported with the kitty protocol.
    public static let capsLock = Self(rawValue: 1 << 5)
    /// Num Lock is on; only reported with the kitty protocol.
    public static let numLock = Self(rawValue: 1 << 6)
}

/// One key event read from the terminal.
public struct KeyPress: Hashable, Sendable {
    /// Whether the key went down, auto-repeated or was released.
    public enum Phase: Hashable, Sendable {
        /// The key was pressed. Legacy terminals only ever report this phase.
        case down
        /// The key is held and auto-repeating (kitty protocol only).
        case `repeat`
        /// The key was released (kitty protocol only).
        case up
    }

    /// The key.
    public var key: KeyEquivalent
    /// The text the key produced, e.g. `"A"` for Shift-a; empty for keys
    /// like arrows.
    public var characters: String
    /// Modifiers held during the press.
    public var modifiers: EventModifiers
    /// Down, repeat or up.
    public var phase: Phase

    /// Creates a key press.
    public init(
        key: KeyEquivalent,
        characters: String = "",
        modifiers: EventModifiers = [],
        phase: Phase = .down,
    ) {
        self.key = key
        self.characters = characters
        self.modifiers = modifiers
        self.phase = phase
    }
}

/// Something the input parser decoded from stdin.
enum InputEvent: Hashable, Sendable {
    /// A key press.
    case key(KeyPress)
    /// Text pasted while bracketed paste mode was on, delivered whole.
    case paste(String)
    /// The terminal gained (`true`) or lost focus (focus reporting mode).
    case focus(Bool)
    /// The terminal answered the kitty keyboard query (`CSI ? flags u`).
    case kittyKeyboardSupported(flags: Int)
    /// A mouse button, movement or wheel report (mouse reporting mode).
    case mouse(MouseEvent)
}
