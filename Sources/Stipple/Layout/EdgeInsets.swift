/// One side of a rectangle.
public enum Edge: Hashable, Sendable, CaseIterable {
    /// The top side.
    case top
    /// The left side.
    case leading
    /// The bottom side.
    case bottom
    /// The right side.
    case trailing

    /// A set of edges.
    public struct Set: OptionSet, Hashable, Sendable {
        /// The raw bit mask.
        public let rawValue: UInt8

        /// Creates a set from a raw bit mask.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// The top edge.
        public static let top = Self(rawValue: 1 << 0)
        /// The left edge.
        public static let leading = Self(rawValue: 1 << 1)
        /// The bottom edge.
        public static let bottom = Self(rawValue: 1 << 2)
        /// The right edge.
        public static let trailing = Self(rawValue: 1 << 3)
        /// Left and right.
        public static let horizontal: Self = [.leading, .trailing]
        /// Top and bottom.
        public static let vertical: Self = [.top, .bottom]
        /// Every edge.
        public static let all: Self = [.horizontal, .vertical]
    }
}

/// Distances inward from each edge, in cells.
public struct EdgeInsets: Hashable, Sendable {
    /// Rows above.
    public var top: Int
    /// Columns to the left.
    public var leading: Int
    /// Rows below.
    public var bottom: Int
    /// Columns to the right.
    public var trailing: Int

    /// Creates insets.
    public init(top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// The same length on the given edges.
    init(_ edges: Edge.Set, _ length: Int) {
        self.init(
            top: edges.contains(.top) ? length : 0,
            leading: edges.contains(.leading) ? length : 0,
            bottom: edges.contains(.bottom) ? length : 0,
            trailing: edges.contains(.trailing) ? length : 0,
        )
    }

    var horizontal: Int { leading + trailing }
    var vertical: Int { top + bottom }
}
