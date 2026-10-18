/// A point in a view's space as fractions of its size, as in SwiftUI:
/// `(0, 0)` is the top-left corner and `(1, 1)` the bottom-right one.
public struct UnitPoint: Hashable, Sendable {
    /// The horizontal fraction, from the leading edge.
    public var x: Double
    /// The vertical fraction, from the top edge.
    public var y: Double

    /// Creates a unit point from fractions of the width and the height.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The top-left corner.
    public static let zero = Self(x: 0, y: 0)
    /// The middle.
    public static let center = Self(x: 0.5, y: 0.5)
    /// The middle of the leading edge.
    public static let leading = Self(x: 0, y: 0.5)
    /// The middle of the trailing edge.
    public static let trailing = Self(x: 1, y: 0.5)
    /// The middle of the top edge.
    public static let top = Self(x: 0.5, y: 0)
    /// The middle of the bottom edge.
    public static let bottom = Self(x: 0.5, y: 1)
    /// The top-left corner.
    public static let topLeading = Self(x: 0, y: 0)
    /// The top-right corner.
    public static let topTrailing = Self(x: 1, y: 0)
    /// The bottom-left corner.
    public static let bottomLeading = Self(x: 0, y: 1)
    /// The bottom-right corner.
    public static let bottomTrailing = Self(x: 1, y: 1)
}
