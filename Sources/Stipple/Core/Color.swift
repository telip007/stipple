/// A terminal color: one of the 16 named ANSI colors, an entry of the
/// 256-color palette, or a 24-bit RGB value.
///
/// Named colors follow the user's terminal theme. RGB colors are exact on
/// truecolor terminals and are approximated elsewhere.
public struct Color: Hashable, Sendable {
    /// How the color is encoded on the wire.
    public enum Representation: Hashable, Sendable {
        /// One of the 16 ANSI colors: 0–7 normal, 8–15 bright.
        case ansi(UInt8)
        /// An index into the xterm 256-color palette.
        case palette(UInt8)
        /// A 24-bit color.
        case rgb(red: UInt8, green: UInt8, blue: UInt8)
    }

    /// The wire encoding of this color.
    public let representation: Representation

    /// Creates a color from its wire encoding.
    public init(_ representation: Representation) {
        self.representation = representation
    }

    /// Creates a 24-bit color from components in 0...255.
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.init(.rgb(red: red, green: green, blue: blue))
    }

    /// Creates a 24-bit color from `#rgb` or `#rrggbb` (the `#` is optional).
    /// Returns `nil` for anything else.
    public init?(hex: String) {
        var digits = Substring(hex)
        if digits.first == "#" { digits = digits.dropFirst() }
        if digits.count == 3 { digits = Substring(digits.flatMap { [$0, $0] }) }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: UInt8(truncatingIfNeeded: value >> 16),
            green: UInt8(truncatingIfNeeded: value >> 8),
            blue: UInt8(truncatingIfNeeded: value),
        )
    }

    /// An entry of the xterm 256-color palette.
    public static func palette(_ index: UInt8) -> Self { Self(.palette(index)) }

    /// ANSI black.
    public static let black = Self(.ansi(0))
    /// ANSI red.
    public static let red = Self(.ansi(1))
    /// ANSI green.
    public static let green = Self(.ansi(2))
    /// ANSI yellow.
    public static let yellow = Self(.ansi(3))
    /// ANSI blue.
    public static let blue = Self(.ansi(4))
    /// ANSI magenta.
    public static let magenta = Self(.ansi(5))
    /// ANSI cyan.
    public static let cyan = Self(.ansi(6))
    /// ANSI white (light gray on most themes).
    public static let white = Self(.ansi(7))
    /// ANSI bright black, shown as gray.
    public static let gray = Self(.ansi(8))
    /// ANSI bright red.
    public static let brightRed = Self(.ansi(9))
    /// ANSI bright green.
    public static let brightGreen = Self(.ansi(10))
    /// ANSI bright yellow.
    public static let brightYellow = Self(.ansi(11))
    /// ANSI bright blue.
    public static let brightBlue = Self(.ansi(12))
    /// ANSI bright magenta.
    public static let brightMagenta = Self(.ansi(13))
    /// ANSI bright cyan.
    public static let brightCyan = Self(.ansi(14))
    /// ANSI bright white.
    public static let brightWhite = Self(.ansi(15))
}
