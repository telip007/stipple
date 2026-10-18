extension View {
    /// Draws `content` on top of this view, aligned within its frame. The
    /// overlay is offered this view's size and doesn't change it.
    public func overlay<Overlay: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Overlay) -> some View
    {
        Layered(primary: self, secondary: content(), alignment: alignment, secondaryOnTop: true)
    }

    /// Draws `content` behind this view, aligned within its frame.
    public func background<Background: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Background,
    ) -> some View {
        Layered(primary: self, secondary: content(), alignment: alignment, secondaryOnTop: false)
    }
}

/// A view with a second view layered over or under it.
struct Layered<Primary: View, Secondary: View>: View, PrimitiveView {
    let primary: Primary
    let secondary: Secondary
    let alignment: Alignment
    let secondaryOnTop: Bool

    typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = LayeredLayout(alignment: alignment, primaryIndex: secondaryOnTop ? 0 : 1)
        // Each layer becomes exactly one layout child; children draw in order.
        let primaryChild = ChildView(id: 0, view: primary.layout(PassThroughLayout()), environment: node.environment)
        let secondaryChild = ChildView(
            id: 1, view: secondary.layout(PassThroughLayout()), environment: node.environment)
        return secondaryOnTop ? [primaryChild, secondaryChild] : [secondaryChild, primaryChild]
    }
}

@MainActor
struct LayeredLayout: NodeLayout {
    let alignment: Alignment
    let primaryIndex: Int

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let children = node.layoutChildren
        return children.indices.contains(primaryIndex) ? children[primaryIndex].sizeThatFits(proposal) : .zero
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let children = node.layoutChildren
        guard children.indices.contains(primaryIndex) else { return }
        children[primaryIndex].place(at: bounds.origin, proposal: proposal)
        let secondaryProposal = ProposedSize(bounds.size)
        for (index, child) in children.enumerated() where index != primaryIndex {
            child.place(
                at: alignment.origin(of: child.sizeThatFits(secondaryProposal), in: bounds), proposal: secondaryProposal
            )
        }
    }
}
