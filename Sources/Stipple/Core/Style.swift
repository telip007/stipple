/// Text attributes a terminal can render (SGR parameters).
public struct TextAttributes: OptionSet, Hashable, Sendable {
    /// The raw bit mask.
    public let rawValue: UInt8

    /// Creates attributes from a raw bit mask.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Bold or increased intensity (SGR 1).
    public static let bold = Self(rawValue: 1 << 0)
    /// Faint or decreased intensity (SGR 2).
    public static let dim = Self(rawValue: 1 << 1)
    /// Italic (SGR 3).
    public static let italic = Self(rawValue: 1 << 2)
    /// Underline (SGR 4).
    public static let underline = Self(rawValue: 1 << 3)
    /// Swapped foreground and background (SGR 7).
    public static let inverse = Self(rawValue: 1 << 4)
    /// Crossed out (SGR 9).
    public static let strikethrough = Self(rawValue: 1 << 5)
}

/// How one terminal cell is painted: colors, attributes and an optional
/// hyperlink (OSC 8).
public struct Style: Hashable, Sendable {
    /// The text color; `nil` keeps the terminal default.
    public var foreground: Color?
    /// The cell color; `nil` keeps the terminal default.
    public var background: Color?
    /// Bold, italic, underline and friends.
    public var attributes: TextAttributes
    /// A URL the cell links to, if the terminal supports OSC 8 hyperlinks.
    public var link: String?

    /// The terminal's default style.
    public static let plain = Self()

    /// Creates a style.
    public init(
        foreground: Color? = nil,
        background: Color? = nil,
        attributes: TextAttributes = [],
        link: String? = nil,
    ) {
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
        self.link = link
    }
}

/// A run of text that shares one style. Text without newlines unless a
/// function says otherwise.
struct StyledRun: Hashable, Sendable {
    var text: String
    var style: Style
}
