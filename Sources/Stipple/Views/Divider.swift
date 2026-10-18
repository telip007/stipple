/// A line across the enclosing stack: horizontal (`─`) in a `VStack` or
/// outside any stack, vertical (`│`) in an `HStack`.
public struct Divider: View, PrimitiveView {
    /// Creates a divider.
    public init() {}

    /// Never called: `Divider` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let axis: Axis = node.environment.stackAxis == .horizontal ? .vertical : .horizontal
        let style = node.environment.textStyle.resolved(background: node.environment.inheritedBackground)
        node.layout = DividerLayout(axis: axis, style: style)
        return []
    }
}

@MainActor
struct DividerLayout: NodeLayout {
    let axis: Axis
    let style: Style

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        .along(axis, proposal.dimension(axis) ?? 1, cross: 1)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {}

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        let frame = node.frame
        if axis == .horizontal {
            let line = String(repeating: "─", count: max(0, frame.size.width))
            canvas.write([StyledRun(text: line, style: style)], at: frame.origin, clip: clip)
        } else {
            for row in frame.minY..<frame.maxY {
                canvas.write([StyledRun(text: "│", style: style)], at: Point(x: frame.minX, y: row), clip: clip)
            }
        }
    }
}
