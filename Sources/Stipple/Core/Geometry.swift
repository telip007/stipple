/// A size in terminal cells.
public struct Size: Hashable, Sendable {
    /// Width in columns.
    public var width: Int
    /// Height in rows.
    public var height: Int

    /// Zero columns by zero rows.
    public static let zero = Self(width: 0, height: 0)

    /// Creates a size from a width and a height in cells.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// A position in terminal cells. `x` is the column, `y` the row; both start at 0.
public struct Point: Hashable, Sendable {
    /// Column, from the left.
    public var x: Int
    /// Row, from the top.
    public var y: Int

    /// The origin, top left.
    public static let zero = Self(x: 0, y: 0)

    /// Creates a point from a column and a row.
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// A rectangle of terminal cells.
public struct Rect: Hashable, Sendable {
    /// The top-left corner.
    public var origin: Point
    /// The extent.
    public var size: Size

    /// Creates a rectangle from its top-left corner and size.
    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle from coordinates and dimensions.
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    /// The leftmost column inside the rectangle.
    public var minX: Int { origin.x }
    /// The topmost row inside the rectangle.
    public var minY: Int { origin.y }
    /// One past the rightmost column inside the rectangle.
    public var maxX: Int { origin.x + size.width }
    /// One past the bottom row inside the rectangle.
    public var maxY: Int { origin.y + size.height }
    /// Whether the rectangle covers no cells.
    public var isEmpty: Bool { size.width <= 0 || size.height <= 0 }

    /// Whether the cell at `point` lies inside the rectangle.
    public func contains(_ point: Point) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    /// The cells both rectangles cover; empty (with zero size) if they don't overlap.
    public func intersection(_ other: Self) -> Self {
        let left = max(minX, other.minX)
        let top = max(minY, other.minY)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        return Self(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }
}
