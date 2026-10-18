/// SwiftUI's stack algorithm along one axis: children are offered the
/// remaining space in order of layout priority (highest first) and, within a
/// priority, least flexible first, so fixed-size children get what they need
/// and flexible ones share the rest.
@MainActor
struct StackLayout: NodeLayout {
    let axis: Axis
    let alignment: Alignment
    let spacing: Int

    init(axis: Axis, alignment: Alignment, spacing: Int) {
        self.axis = axis
        self.alignment = alignment
        self.spacing = spacing
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        size(of: node.layoutChildren, proposal: proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        place(node.layoutChildren, in: bounds, proposal: proposal)
    }

    func size(of children: [ViewNode], proposal: ProposedSize) -> Size {
        let sizes = distribute(children, proposal: proposal)
        let main = sizes.reduce(0) { $0 + $1.dimension(axis) } + totalSpacing(children.count)
        let crossLength = sizes.map { $0.dimension(cross) }.max() ?? 0
        return .along(axis, main, cross: crossLength)
    }

    func place(_ children: [ViewNode], in bounds: Rect, proposal: ProposedSize) {
        let crossProposal = proposal.dimension(cross)
        let sizes = distribute(children, proposal: proposal)
        var cursor = axis == .horizontal ? bounds.minX : bounds.minY
        for (child, size) in zip(children, sizes) {
            let childProposal = ProposedSize.along(axis, size.dimension(axis), cross: crossProposal)
            let origin: Point
            if axis == .horizontal {
                origin = Point(
                    x: cursor, y: bounds.minY + alignment.vertical.offset(child: size.height, in: bounds.size.height))
            } else {
                origin = Point(
                    x: bounds.minX + alignment.horizontal.offset(child: size.width, in: bounds.size.width), y: cursor)
            }
            child.place(at: origin, proposal: childProposal)
            cursor += size.dimension(axis) + spacing
        }
    }

    private var cross: Axis { axis == .horizontal ? .vertical : .horizontal }

    private func totalSpacing(_ count: Int) -> Int {
        max(0, count - 1) * spacing
    }

    /// The size each child takes for `proposal`, in child order.
    private func distribute(_ children: [ViewNode], proposal: ProposedSize) -> [Size] {
        let crossProposal = proposal.dimension(cross)
        guard let available = proposal.dimension(axis) else {
            // Ideal size: every child at its ideal size.
            return children.map { $0.sizeThatFits(.along(axis, nil, cross: crossProposal)) }
        }
        let minimums = children.map { $0.sizeThatFits(.along(axis, 0, cross: crossProposal)).dimension(axis) }
        let maximums = children.map { $0.sizeThatFits(.along(axis, .infinity, cross: crossProposal)).dimension(axis) }
        var remaining = available - totalSpacing(children.count)
        var sizes = [Size](repeating: .zero, count: children.count)
        let groups = Dictionary(grouping: children.indices) { children[$0].layoutPriority }
        var lowerMinimum = minimums.reduce(0, +)
        for priority in groups.keys.sorted(by: >) {
            let members = groups[priority, default: []].sorted {
                maximums[$0] - minimums[$0] < maximums[$1] - minimums[$1]
            }
            lowerMinimum -= members.reduce(0) { $0 + minimums[$1] }
            var groupRemaining = max(0, remaining - lowerMinimum)
            for (position, index) in members.enumerated() {
                let offer = max(0, groupRemaining / (members.count - position))
                let size = children[index].sizeThatFits(.along(axis, offer, cross: crossProposal))
                sizes[index] = size
                groupRemaining -= size.dimension(axis)
                remaining -= size.dimension(axis)
            }
        }
        return sizes
    }
}

/// Overlays children on top of each other, aligned in the largest child's frame.
@MainActor
struct OverlayLayout: NodeLayout {
    let alignment: Alignment

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let sizes = node.layoutChildren.map { $0.sizeThatFits(proposal) }
        return Size(width: sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).max() ?? 0)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        for child in node.layoutChildren {
            child.place(at: alignment.origin(of: child.sizeThatFits(proposal), in: bounds), proposal: proposal)
        }
    }
}
