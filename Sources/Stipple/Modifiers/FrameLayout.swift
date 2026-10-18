/// SwiftUI's frame modifiers: a fixed frame replaces the proposal in the
/// given dimensions; a flexible frame clamps it between a minimum and a
/// maximum and takes as much of the offered space as the maximum allows.
@MainActor
struct FrameLayout: SingleChildLayout {
    enum Dimension {
        case fixed(Int?)
        case flexible(min: Int?, ideal: Int?, max: Int?)

        /// What the content is offered.
        func childProposal(_ proposed: Int?) -> Int? {
            switch self {
            case .fixed(let length): return length ?? proposed
            case .flexible(let min, let ideal, let max):
                guard let proposed else { return ideal }
                return Swift.min(max ?? .infinity, Swift.max(min ?? 0, proposed))
            }
        }

        /// The frame's length, given what it was offered and what the content chose.
        func length(proposed: Int?, child: Int) -> Int {
            switch self {
            case .fixed(let length): return length ?? child
            case .flexible(let min, let ideal, let max):
                guard min != nil || max != nil else { return child }
                let lower = min ?? Swift.min(child, max ?? child)
                let upper = Swift.max(max ?? Swift.max(child, lower), lower)
                return Swift.min(upper, Swift.max(lower, proposed ?? ideal ?? child))
            }
        }
    }

    let width: Dimension
    let height: Dimension
    let alignment: Alignment

    private func childProposal(_ proposal: ProposedSize) -> ProposedSize {
        ProposedSize(width: width.childProposal(proposal.width), height: height.childProposal(proposal.height))
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let child = content(of: node).sizeThatFits(childProposal(proposal))
        return Size(
            width: width.length(proposed: proposal.width, child: child.width),
            height: height.length(proposed: proposal.height, child: child.height),
        )
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let content = content(of: node)
        let inner = childProposal(proposal)
        content.place(at: alignment.origin(of: content.sizeThatFits(inner), in: bounds), proposal: inner)
    }
}
