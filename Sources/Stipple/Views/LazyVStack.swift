/// Arranges children top to bottom, like ``VStack``, and inside a scroll
/// view pinned to its bottom (a chat) measures what is near the viewport
/// first, as SwiftUI's `LazyVStack`.
///
/// When the width changes (a resize), the rows near the bottom are laid out
/// at once and the rest keep the height they had until they are measured,
/// a few each frame: the bottom-anchored scroll view keeps what is in view
/// still while the rows above it settle. Anywhere else (not in a scroll view,
/// scrolled away from the bottom, scrolling to a view by id) it lays out like
/// a `VStack`.
///
/// ```swift
/// ScrollView {
///     LazyVStack {
///         ForEach(messages) { message in Text(message.text) }
///     }
/// }
/// .defaultScrollAnchor(.bottom)
/// ```
public struct LazyVStack<Content: View>: View, PrimitiveView {
    let alignment: HorizontalAlignment
    let spacing: Int
    let content: Content

    /// Creates a lazy vertical stack.
    public init(alignment: HorizontalAlignment = .leading, spacing: Int = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    /// Never called: `LazyVStack` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = LazyStackLayout(
            stack: StackLayout(
                axis: .vertical, alignment: Alignment(horizontal: alignment, vertical: .top), spacing: spacing),
            alignment: alignment,
            spacing: spacing,
            scroll: node.environment.enclosingScroll?.state,
            memory: node.storage(at: 0) { LazyStackMemory() },
        )
        var environment = node.environment
        environment.stackAxis = .vertical
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

/// What a lazy stack worked out in its last pass.
@MainActor
final class LazyStackMemory {
    /// The children whose size is a stand-in, by the width it stands in at.
    var estimated: [Int: Set<ObjectIdentifier>] = [:]
    /// The rows of the last placement, in order, with their tops and
    /// heights relative to the stack: where the first row in view is, without
    /// reading frames (moving the stack moves them all alike).
    var placedRows: [ObjectIdentifier] = []
    var placedTops: [Int] = []
    var placedHeights: [Int] = []
}

@MainActor
struct LazyStackLayout: NodeLayout {
    /// How many viewports of rows from the bottom are measured exactly.
    static let exactViewports = 2
    /// Time a pass spends measuring rows that stood in, so they settle over
    /// a few frames without making one slow.
    static let settleBudget = Duration.milliseconds(4)

    let stack: StackLayout
    let alignment: HorizontalAlignment
    let spacing: Int
    let scroll: ScrollState?
    let memory: LazyStackMemory

    /// Placement depends on the scroll view only through stand-ins, and a
    /// pass that leaves any asks for the next one itself.
    var placesPurely: Bool { true }

    /// How a pass may stand in for sizes.
    private enum Mode {
        /// Every row measured.
        case exact
        /// Pinned to the bottom of a scroll view that keeps the bottom as
        /// content changes: rows from the bottom up are measured first.
        case bottom
        /// Resting `offset` rows from the top: the first row in view stays
        /// where it is on screen, and rows from it down are measured first.
        /// At the top the offset stays 0 instead.
        case anchored(offset: Int, keepsOffset: Bool)
    }

    /// Unlimited height, inside a scroll view that has been laid out, not
    /// moving by lines or to a view by id.
    private func mode(_ proposal: ProposedSize) -> Mode {
        guard proposal.height == nil, proposal.width != nil, let scroll, scroll.hasLaidOut, scroll.viewportHeight > 0
        else { return .exact }
        let position = scroll.binding?.wrappedValue ?? scroll.position
        guard position.delta == 0 else { return .exact }
        switch position.target {
        case .id:
            return .exact
        case .edge(.bottom):
            return scroll.anchors.sizeChanges?.y == 1 ? .bottom : .exact
        case .y(let offset):
            return .anchored(offset: offset, keepsOffset: true)
        case .edge, nil:
            if scroll.offset >= scroll.maxOffset, scroll.anchors.sizeChanges?.y == 1 { return .bottom }
            return scroll.offset <= 0 ? .anchored(offset: 0, keepsOffset: false) : .exact
        }
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let children = node.layoutChildren
        // With a height to fill, it is a `VStack`. Otherwise it sizes and
        // places rows the same way lazy or not, so moving between the two
        // (scrolling away from the bottom and back) keeps every placement.
        guard proposal.height == nil, let width = proposal.width else {
            return stack.size(of: children, proposal: proposal)
        }
        let mode = mode(proposal)
        let sizes: [Size]
        if let known = Self.knownSizes(of: children, width: width) {
            // Nothing changed at this width: nothing to measure or keep in place.
            sizes = known
        } else {
            // A width a parent probes with (none, one column, unlimited)
            // shows nothing, so nothing needs keeping in place for it.
            let isProbe = width <= 1 || width >= TextNodeLayout.unlimitedWidth
            let anchor = isProbe ? nil : self.anchor(in: children, mode: mode)
            sizes = self.sizes(of: children, width: width, mode: mode, anchor: anchor)
        }
        var height = max(0, children.count - 1) * spacing
        var widest = 0
        for size in sizes {
            height += size.height
            widest = max(widest, size.width)
        }
        return Size(width: widest, height: height)
    }

    /// Each child's size: exact for the rows already known and for a few
    /// viewports of rows from where the view is (the bottom, or the first row
    /// in view down), a stand-in for the rest, some of which are measured for
    /// real in each pass.
    private func sizes(of children: [ViewNode], width: Int, mode: Mode, anchor: Anchor?) -> [Size] {
        let childProposal = ProposedSize(width: width, height: nil)
        // Rows settle only at the width the content was last shown at, not
        // at the widths a parent probes with.
        let settles = width == scroll?.viewport.size.width
        var sizes = [Size](repeating: .zero, count: children.count)
        var isKnown = [Bool](repeating: false, count: children.count)
        var estimated: Set<ObjectIdentifier> = []
        let exactLimit = (scroll?.viewportHeight ?? 0) * Self.exactViewports
        let order = Self.measuringOrder(children, from: anchor?.index)
        let clock = ContinuousClock()
        let start = clock.now
        var exactHeight = 0
        for index in order {
            let child = children[index]
            if let known = child.cachedSize(for: childProposal) {
                sizes[index] = known
            } else if case .exact = mode {
                sizes[index] = child.sizeThatFits(childProposal)
            } else if exactHeight < exactLimit || (settles && clock.now - start < Self.settleBudget) {
                sizes[index] = child.sizeThatFits(childProposal)
            } else if let standIn = child.lastKnownSize {
                sizes[index] = Size(width: min(standIn.width, width), height: standIn.height)
                estimated.insert(ObjectIdentifier(child))
            } else {
                sizes[index] = child.sizeThatFits(childProposal)
            }
            isKnown[index] = true
            exactHeight += sizes[index].height
        }
        memory.estimated[width] = estimated.isEmpty ? nil : estimated
        if case .anchored(_, keepsOffset: true) = mode, let anchor {
            // Where the first row in view now starts, so the scroll view can
            // keep it at the same place on screen.
            var top = 0
            for index in 0..<anchor.index {
                top += sizes[index].height + spacing
            }
            scroll?.anchoredOffsets[width] = top + anchor.above
        }
        return sizes
    }

    /// Every child's size at `width`, if all are known.
    private static func knownSizes(of children: [ViewNode], width: Int) -> [Size]? {
        let proposal = ProposedSize(width: width, height: nil)
        var sizes: [Size] = []
        sizes.reserveCapacity(children.count)
        for child in children {
            guard let size = child.cachedSize(for: proposal) else { return nil }
            sizes.append(size)
        }
        return sizes
    }

    /// The first row in view and how many of its rows are above the view.
    private struct Anchor {
        var index: Int
        var above: Int
    }

    /// The first row in view at the offset the view rests at, from where
    /// the last placement put the rows relative to the stack.
    private func anchor(in children: [ViewNode], mode: Mode) -> Anchor? {
        guard case .anchored(let offset, _) = mode, !memory.placedTops.isEmpty else { return nil }
        // The last row starting at or above the offset, by halving.
        var low = 0
        var high = memory.placedTops.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if memory.placedTops[middle] <= offset {
                low = middle
            } else {
                high = middle - 1
            }
        }
        if memory.placedTops[low] + memory.placedHeights[low] <= offset, low + 1 < memory.placedTops.count {
            low += 1
        }
        let row = memory.placedRows[low]
        guard let index = Self.index(of: row, in: children, near: low) else { return nil }
        return Anchor(index: index, above: offset - memory.placedTops[low])
    }

    /// Where the node `row` is among `children`: at `near` unless rows came
    /// or went since it was placed. A loop: a closure in this main-actor type
    /// is checked for the actor on every call.
    private static func index(of row: ObjectIdentifier, in children: [ViewNode], near: Int) -> Int? {
        if near < children.count, ObjectIdentifier(children[near]) == row { return near }
        for (index, child) in children.enumerated() where ObjectIdentifier(child) == row {
            return index
        }
        return nil
    }

    /// The order rows are measured in: from the bottom up, or from the first
    /// row in view down and then up, so the rows in view are measured first.
    private static func measuringOrder(_ children: [ViewNode], from anchor: Int?) -> [Int] {
        guard let anchor else { return Array(children.indices.reversed()) }
        return Array(anchor..<children.count) + Array((0..<anchor).reversed())
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let children = node.layoutChildren
        guard proposal.height == nil, let width = proposal.width else {
            stack.place(children, in: bounds, proposal: proposal)
            return
        }
        let estimated = memory.estimated[width] ?? []
        let childProposal = ProposedSize(width: width, height: nil)
        var cursor = bounds.minY
        var rows: [ObjectIdentifier] = []
        var tops: [Int] = []
        var heights: [Int] = []
        rows.reserveCapacity(children.count)
        tops.reserveCapacity(children.count)
        heights.reserveCapacity(children.count)
        for child in children {
            let size = estimated.contains(ObjectIdentifier(child)) ? nil : child.cachedSize(for: childProposal)
            let height = size?.height ?? child.lastKnownSize?.height ?? 0
            rows.append(ObjectIdentifier(child))
            tops.append(cursor - bounds.minY)
            heights.append(height)
            guard let size else {
                // A stand-in: skipped until measured, out of view meanwhile.
                cursor += height + spacing
                child.isOutOfLayout = true
                continue
            }
            let origin = Point(x: bounds.minX + alignment.offset(child: size.width, in: bounds.size.width), y: cursor)
            child.place(at: origin, proposal: childProposal)
            cursor += size.height + spacing
        }
        memory.placedRows = rows
        memory.placedTops = tops
        memory.placedHeights = heights
        if !estimated.isEmpty {
            // Measure more of them on the next pass.
            node.layoutChanged()
            node.graph.onNeedsRender()
        }
    }
}
