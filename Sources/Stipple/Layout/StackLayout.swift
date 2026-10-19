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
        // Loops rather than `map` and `reduce` here and below: closures in
        // this main-actor type are checked for the actor on every call, which
        // costs more than the layout itself on a long stack.
        var main = totalSpacing(children.count)
        var crossLength = 0
        for size in distribute(children, proposal: proposal) {
            main += size.dimension(axis)
            crossLength = max(crossLength, size.dimension(cross))
        }
        return .along(axis, main, cross: crossLength)
    }

    func place(_ children: [ViewNode], in bounds: Rect, proposal: ProposedSize) {
        // Children are placed at the stack's final cross size, so views that
        // fill the offered space (`.frame(maxWidth: .infinity)`) stretch to the
        // widest sibling even when the stack itself was sized ideally.
        let crossLength = bounds.size.dimension(cross)
        let sizes = distribute(children, proposal: proposal)
        var cursor = axis == .horizontal ? bounds.minX : bounds.minY
        for (child, size) in zip(children, sizes) {
            let childProposal = ProposedSize.along(axis, size.dimension(axis), cross: crossLength)
            let placed = child.sizeThatFits(childProposal)
            let origin: Point
            if axis == .horizontal {
                origin = Point(
                    x: cursor, y: bounds.minY + alignment.vertical.offset(child: placed.height, in: crossLength))
            } else {
                origin = Point(
                    x: bounds.minX + alignment.horizontal.offset(child: placed.width, in: crossLength), y: cursor)
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
            return idealSizes(of: children, cross: crossProposal)
        }
        let lengths = lengths(of: children, cross: crossProposal)
        var lowerMinimum = 0
        var flexibilities: [Int] = []
        flexibilities.reserveCapacity(lengths.count)
        for length in lengths {
            lowerMinimum += length.minimum
            flexibilities.append(length.flexibility)
        }
        var remaining = available - totalSpacing(children.count)
        var sizes = [Size](repeating: .zero, count: children.count)
        for group in Self.priorityGroups(children) {
            let members = Self.sorted(group, by: flexibilities)
            var groupMinimum = 0
            for index in members {
                groupMinimum += lengths[index].minimum
            }
            lowerMinimum -= groupMinimum
            var groupRemaining = max(0, remaining - lowerMinimum)
            var unprocessedMinimum = groupMinimum
            for (position, index) in members.enumerated() {
                unprocessedMinimum -= lengths[index].minimum
                // An equal share, or the child's ideal length if that still
                // leaves the others their minimum: a word next to spacers
                // keeps its natural width instead of wrapping.
                let share = groupRemaining / (members.count - position)
                let affordable = min(lengths[index].ideal, groupRemaining - unprocessedMinimum)
                let offer = max(0, max(share, affordable))
                let size = children[index].sizeThatFits(.along(axis, offer, cross: crossProposal))
                sizes[index] = size
                groupRemaining -= size.dimension(axis)
                remaining -= size.dimension(axis)
            }
        }
        return sizes
    }

    /// Every child at its ideal size along the axis.
    private func idealSizes(of children: [ViewNode], cross crossProposal: Int?) -> [Size] {
        var sizes: [Size] = []
        sizes.reserveCapacity(children.count)
        for child in children {
            sizes.append(child.sizeThatFits(.along(axis, nil, cross: crossProposal)))
        }
        return sizes
    }

    private func lengths(of children: [ViewNode], cross crossProposal: Int?) -> [Lengths] {
        var lengths: [Lengths] = []
        lengths.reserveCapacity(children.count)
        for child in children {
            lengths.append(measure(child, cross: crossProposal))
        }
        return lengths
    }

    /// The children's indices by layout priority, highest first. Nearly
    /// always every child has the same priority, which needs no grouping.
    private static func priorityGroups(_ children: [ViewNode]) -> [[Int]] {
        var isMixed = false
        if let first = children.first?.layoutPriority {
            for child in children where child.layoutPriority != first {
                isMixed = true
                break
            }
        }
        guard isMixed else { return [Array(children.indices)] }
        let groups = Dictionary(grouping: children.indices) { children[$0].layoutPriority }
        return groups.keys.sorted(by: >).map { groups[$0, default: []] }
    }

    /// `indices` ordered by their `keys`, least first, keeping ties in order.
    nonisolated private static func sorted(_ indices: [Int], by keys: [Int]) -> [Int] {
        indices.enumerated().sorted { lhs, rhs in
            keys[lhs.element] != keys[rhs.element] ? keys[lhs.element] < keys[rhs.element] : lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    private struct Lengths {
        var minimum: Int
        var ideal: Int
        var maximum: Int
        var flexibility: Int { maximum - minimum }
    }

    /// A child's minimum, ideal and maximum length along the axis. The
    /// minimum is the smaller of the lengths offered 0 and 1 cell, because
    /// text offered 0 doesn't wrap (as in Ink) but can shrink to one column.
    private func measure(_ child: ViewNode, cross crossProposal: Int?) -> Lengths {
        let zero = child.sizeThatFits(.along(axis, 0, cross: crossProposal)).dimension(axis)
        let one = child.sizeThatFits(.along(axis, 1, cross: crossProposal)).dimension(axis)
        return Lengths(
            minimum: min(zero, one),
            ideal: child.sizeThatFits(.along(axis, nil, cross: crossProposal)).dimension(axis),
            maximum: child.sizeThatFits(.along(axis, .infinity, cross: crossProposal)).dimension(axis),
        )
    }
}

/// Overlays children on top of each other, aligned in the largest child's frame.
@MainActor
struct OverlayLayout: NodeLayout {
    let alignment: Alignment

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        var result = Size(width: 0, height: 0)
        for child in node.layoutChildren {
            let size = child.sizeThatFits(proposal)
            result = Size(width: max(result.width, size.width), height: max(result.height, size.height))
        }
        return result
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        for child in node.layoutChildren {
            child.place(at: alignment.origin(of: child.sizeThatFits(proposal), in: bounds), proposal: proposal)
        }
    }
}
