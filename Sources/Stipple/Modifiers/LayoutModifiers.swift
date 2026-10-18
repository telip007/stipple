extension View {
    /// Adds space around the view: `length` cells on every edge.
    public func padding(_ length: Int = 1) -> some View {
        padding(.all, length)
    }

    /// Adds `length` cells of space on the given edges.
    public func padding(_ edges: Edge.Set, _ length: Int = 1) -> some View {
        padding(EdgeInsets(edges, length))
    }

    /// Adds space inside each edge.
    public func padding(_ insets: EdgeInsets) -> some View {
        layout(InsetLayout(insets: insets))
    }

    /// Gives the view a fixed width and/or height; the content is aligned inside.
    public func frame(width: Int? = nil, height: Int? = nil, alignment: Alignment = .center) -> some View {
        layout(FrameLayout(width: .fixed(width), height: .fixed(height), alignment: alignment))
    }

    /// Constrains the view's size. Pass `.infinity` as a maximum to fill the offered space.
    public func frame(
        minWidth: Int? = nil,
        idealWidth: Int? = nil,
        maxWidth: Int? = nil,
        minHeight: Int? = nil,
        idealHeight: Int? = nil,
        maxHeight: Int? = nil,
        alignment: Alignment = .center,
    ) -> some View {
        layout(
            FrameLayout(
                width: .flexible(min: minWidth, ideal: idealWidth, max: maxWidth),
                height: .flexible(min: minHeight, ideal: idealHeight, max: maxHeight),
                alignment: alignment,
            )
        )
    }

    /// Clips content that overflows the view's frame (Ink's `overflow="hidden"`).
    public func clipped() -> some View {
        layout(ClipLayout())
    }

    /// Draws the view shifted by `x` columns and `y` rows without changing layout.
    public func offset(x: Int = 0, y: Int = 0) -> some View {
        layout(OffsetLayout(offset: Point(x: x, y: y)))
    }

    /// Uses the view's ideal size along the given axes, ignoring the offered size.
    public func fixedSize(horizontal: Bool = true, vertical: Bool = true) -> some View {
        layout(FixedSizeLayout(horizontal: horizontal, vertical: vertical))
    }

    /// Makes stacks offer space to this view before views with a lower priority.
    public func layoutPriority(_ value: Double) -> some View {
        modified { node, _ in
            node.layout = PassThroughLayout()
            node.layoutPriority = value
        }
    }
}

/// Forwards size and placement to the content unchanged.
@MainActor
struct PassThroughLayout: SingleChildLayout {
    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: proposal)
    }
}

@MainActor
struct InsetLayout: SingleChildLayout {
    let insets: EdgeInsets

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let inner = content(of: node).sizeThatFits(proposal.inset(by: insets))
        return Size(width: inner.width + insets.horizontal, height: inner.height + insets.vertical)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let origin = Point(x: bounds.minX + insets.leading, y: bounds.minY + insets.top)
        content(of: node).place(at: origin, proposal: proposal.inset(by: insets))
    }
}

@MainActor
struct ClipLayout: SingleChildLayout {
    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: proposal)
    }

    func childClip(_ node: ViewNode, clip: Rect) -> Rect {
        clip.intersection(node.frame)
    }
}

@MainActor
struct OffsetLayout: SingleChildLayout {
    let offset: Point

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: Point(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: proposal)
    }
}

@MainActor
struct FixedSizeLayout: SingleChildLayout {
    let horizontal: Bool
    let vertical: Bool

    private func childProposal(_ proposal: ProposedSize) -> ProposedSize {
        ProposedSize(width: horizontal ? nil : proposal.width, height: vertical ? nil : proposal.height)
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(childProposal(proposal))
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: childProposal(proposal))
    }
}
