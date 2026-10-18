/// A size a parent offers a child during layout. A `nil` dimension asks for
/// the child's ideal size in that dimension.
struct ProposedSize: Hashable, Sendable {
    var width: Int?
    var height: Int?

    /// Ask for the ideal size.
    static let unspecified = Self(width: nil, height: nil)
    /// Ask for the minimum size.
    static let zero = Self(width: 0, height: 0)
    /// Ask for the maximum size.
    static let infinity = Self(width: .infinity, height: .infinity)

    init(width: Int?, height: Int?) {
        self.width = width
        self.height = height
    }

    init(_ size: Size) {
        self.init(width: size.width, height: size.height)
    }

    /// The proposal with `insets` taken away, never below zero.
    func inset(by insets: EdgeInsets) -> Self {
        Self(
            width: width.map { max(0, $0 - insets.leading - insets.trailing) },
            height: height.map { max(0, $0 - insets.top - insets.bottom) },
        )
    }

    func dimension(_ axis: Axis) -> Int? {
        axis == .horizontal ? width : height
    }

    static func along(_ axis: Axis, _ main: Int?, cross: Int?) -> Self {
        axis == .horizontal ? Self(width: main, height: cross) : Self(width: cross, height: main)
    }
}

extension Int {
    /// A length meaning "as much as offered", for `.frame(maxWidth: .infinity)`.
    /// Large enough to exceed any terminal, small enough not to overflow when summed.
    public static let infinity = 1 << 32
}

/// Horizontal or vertical.
public enum Axis: Hashable, Sendable {
    /// Left to right.
    case horizontal
    /// Top to bottom.
    case vertical

    /// A set of axes, as in SwiftUI.
    public struct Set: OptionSet, Hashable, Sendable {
        /// The raw bit mask.
        public let rawValue: UInt8

        /// Creates a set from a raw bit mask.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// The horizontal axis.
        public static let horizontal = Self(rawValue: 1 << 0)
        /// The vertical axis.
        public static let vertical = Self(rawValue: 1 << 1)
    }
}

extension Size {
    func dimension(_ axis: Axis) -> Int {
        axis == .horizontal ? width : height
    }

    static func along(_ axis: Axis, _ main: Int, cross: Int) -> Self {
        axis == .horizontal ? Self(width: main, height: cross) : Self(width: cross, height: main)
    }
}
