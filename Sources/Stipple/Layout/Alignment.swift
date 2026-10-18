/// Where to put a child horizontally inside a larger space.
public enum HorizontalAlignment: Hashable, Sendable {
    /// Against the left edge.
    case leading
    /// Centered; odd leftover cells go to the right.
    case center
    /// Against the right edge.
    case trailing

    func offset(child: Int, in space: Int) -> Int {
        switch self {
        case .leading: 0
        case .center: (space - child) / 2
        case .trailing: space - child
        }
    }
}

/// Where to put a child vertically inside a larger space.
public enum VerticalAlignment: Hashable, Sendable {
    /// Against the top edge.
    case top
    /// Centered; an odd leftover row goes below.
    case center
    /// Against the bottom edge.
    case bottom

    func offset(child: Int, in space: Int) -> Int {
        switch self {
        case .top: 0
        case .center: (space - child) / 2
        case .bottom: space - child
        }
    }
}

/// A horizontal and a vertical alignment.
public struct Alignment: Hashable, Sendable {
    /// The horizontal part.
    public var horizontal: HorizontalAlignment
    /// The vertical part.
    public var vertical: VerticalAlignment

    /// Combines a horizontal and a vertical alignment.
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Top left.
    public static let topLeading = Self(horizontal: .leading, vertical: .top)
    /// Top, centered horizontally.
    public static let top = Self(horizontal: .center, vertical: .top)
    /// Top right.
    public static let topTrailing = Self(horizontal: .trailing, vertical: .top)
    /// Left, centered vertically.
    public static let leading = Self(horizontal: .leading, vertical: .center)
    /// Centered both ways.
    public static let center = Self(horizontal: .center, vertical: .center)
    /// Right, centered vertically.
    public static let trailing = Self(horizontal: .trailing, vertical: .center)
    /// Bottom left.
    public static let bottomLeading = Self(horizontal: .leading, vertical: .bottom)
    /// Bottom, centered horizontally.
    public static let bottom = Self(horizontal: .center, vertical: .bottom)
    /// Bottom right.
    public static let bottomTrailing = Self(horizontal: .trailing, vertical: .bottom)

    /// Where a child of `size` goes inside `rect`.
    func origin(of size: Size, in rect: Rect) -> Point {
        Point(
            x: rect.minX + horizontal.offset(child: size.width, in: rect.size.width),
            y: rect.minY + vertical.offset(child: size.height, in: rect.size.height),
        )
    }
}
