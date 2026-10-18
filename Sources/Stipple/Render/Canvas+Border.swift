extension Canvas {
    /// Draws a border along the edge of `rect`, in one style.
    mutating func drawBorder(
        _ border: BorderStyle,
        in rect: Rect,
        edges: Edge.Set = .all,
        style: Style,
        clip: Rect? = nil,
    ) {
        drawBorder(border, in: rect, edges: edges, colors: BorderStyle.Colors(style), clip: clip)
    }

    /// Draws a border along the edge of `rect` with a style per side.
    ///
    /// A hidden side is skipped and its corners drop out, as in Ink: the top
    /// row then starts with the top edge character instead of the corner.
    /// Draw order is top, left, right, bottom.
    mutating func drawBorder(
        _ border: BorderStyle,
        in rect: Rect,
        edges: Edge.Set = .all,
        colors: BorderStyle.Colors,
        clip: Rect? = nil,
    ) {
        guard !rect.isEmpty else { return }
        let hasLeft = edges.contains(.leading)
        let hasRight = edges.contains(.trailing)
        let inner = max(0, rect.size.width - (hasLeft ? 1 : 0) - (hasRight ? 1 : 0))
        func horizontal(_ corners: (Character, Character), _ edge: Character) -> String {
            (hasLeft ? String(corners.0) : "") + String(repeating: edge, count: inner)
                + (hasRight ? String(corners.1) : "")
        }
        let hasTop = edges.contains(.top)
        let hasBottom = edges.contains(.bottom)
        if hasTop {
            let line = horizontal((border.topLeft, border.topRight), border.top)
            write([StyledRun(text: line, style: colors.top)], at: rect.origin, clip: clip)
        }
        let first = rect.minY + (hasTop ? 1 : 0)
        let last = rect.maxY - (hasBottom ? 1 : 0)
        for row in first..<max(first, last) {
            if hasLeft {
                let left = StyledRun(text: String(border.left), style: colors.left)
                write([left], at: Point(x: rect.minX, y: row), clip: clip)
            }
            if hasRight {
                let right = StyledRun(text: String(border.right), style: colors.right)
                write([right], at: Point(x: rect.maxX - 1, y: row), clip: clip)
            }
        }
        if hasBottom {
            let line = horizontal((border.bottomLeft, border.bottomRight), border.bottom)
            write([StyledRun(text: line, style: colors.bottom)], at: Point(x: rect.minX, y: rect.maxY - 1), clip: clip)
        }
    }
}
