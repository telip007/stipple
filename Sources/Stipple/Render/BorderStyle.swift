/// The characters a border is drawn with (Ink's `cli-boxes` sets).
public struct BorderStyle: Hashable, Sendable {
    /// The top-left corner.
    public var topLeft: Character
    /// The top edge.
    public var top: Character
    /// The top-right corner.
    public var topRight: Character
    /// The left edge.
    public var left: Character
    /// The right edge.
    public var right: Character
    /// The bottom-left corner.
    public var bottomLeft: Character
    /// The bottom edge.
    public var bottom: Character
    /// The bottom-right corner.
    public var bottomRight: Character

    /// Creates a custom border from its eight characters. Each should be one cell wide.
    public init(
        topLeft: Character,
        top: Character,
        topRight: Character,
        left: Character,
        right: Character,
        bottomLeft: Character,
        bottom: Character,
        bottomRight: Character,
    ) {
        self.topLeft = topLeft
        self.top = top
        self.topRight = topRight
        self.left = left
        self.right = right
        self.bottomLeft = bottomLeft
        self.bottom = bottom
        self.bottomRight = bottomRight
    }

    /// Which sides of a border are drawn. These are physical sides, not layout directions.
    public struct Edges: OptionSet, Hashable, Sendable {
        /// The raw bit mask.
        public let rawValue: UInt8

        /// Creates edges from a raw bit mask.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// The top side.
        public static let top = Self(rawValue: 1 << 0)
        /// The left side.
        public static let left = Self(rawValue: 1 << 1)
        /// The bottom side.
        public static let bottom = Self(rawValue: 1 << 2)
        /// The right side.
        public static let right = Self(rawValue: 1 << 3)
        /// All four sides.
        public static let all: Self = [.top, .left, .bottom, .right]
    }

    /// The style each side is drawn in. Corners take the style of their horizontal side.
    public struct Colors: Hashable, Sendable {
        /// Style of the top side and its corners.
        public var top: Style
        /// Style of the left side.
        public var left: Style
        /// Style of the bottom side and its corners.
        public var bottom: Style
        /// Style of the right side.
        public var right: Style

        /// Creates per-side styles.
        public init(top: Style = .plain, left: Style = .plain, bottom: Style = .plain, right: Style = .plain) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }

        /// Draws all sides in one style.
        public init(_ style: Style) {
            self.init(top: style, left: style, bottom: style, right: style)
        }
    }

    /// `┌─┐│ │└─┘`
    public static let single = Self(
        topLeft: "┌", top: "─", topRight: "┐", left: "│", right: "│", bottomLeft: "└", bottom: "─", bottomRight: "┘",
    )
    /// `╔═╗║ ║╚═╝`
    public static let double = Self(
        topLeft: "╔", top: "═", topRight: "╗", left: "║", right: "║", bottomLeft: "╚", bottom: "═", bottomRight: "╝",
    )
    /// `╭─╮│ │╰─╯`
    public static let rounded = Self(
        topLeft: "╭", top: "─", topRight: "╮", left: "│", right: "│", bottomLeft: "╰", bottom: "─", bottomRight: "╯",
    )
    /// `┏━┓┃ ┃┗━┛` (Ink's `bold`).
    public static let heavy = Self(
        topLeft: "┏", top: "━", topRight: "┓", left: "┃", right: "┃", bottomLeft: "┗", bottom: "━", bottomRight: "┛",
    )
    /// Single horizontal lines with double vertical lines.
    public static let singleDouble = Self(
        topLeft: "╓", top: "─", topRight: "╖", left: "║", right: "║", bottomLeft: "╙", bottom: "─", bottomRight: "╜",
    )
    /// Double horizontal lines with single vertical lines.
    public static let doubleSingle = Self(
        topLeft: "╒", top: "═", topRight: "╕", left: "│", right: "│", bottomLeft: "╘", bottom: "═", bottomRight: "╛",
    )
    /// ASCII only: `+-+| |+-+`.
    public static let classic = Self(
        topLeft: "+", top: "-", topRight: "+", left: "|", right: "|", bottomLeft: "+", bottom: "-", bottomRight: "+",
    )
    /// Arrows pointing inward.
    public static let arrow = Self(
        topLeft: "↘", top: "↓", topRight: "↙", left: "→", right: "←", bottomLeft: "↗", bottom: "↑", bottomRight: "↖",
    )
}
