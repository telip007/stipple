import Observation

/// A scrollable view, as SwiftUI's `ScrollView`.
///
/// It takes the height it is offered as its viewport, lays its content out
/// at its own width with unlimited height, and draws the rows that are in
/// view, clipped. Offered no height (inline output, `fixedSize()`), it is as
/// tall as its content. Only vertical scrolling is supported.
///
/// Scrolling:
/// - **Keys**, while the scroll view or a view inside it has focus (make it
///   focusable with `.focusable()`): ↑/↓ by a row, Page Up/Page Down by a
///   page, Home/End to the top and bottom. Handlers of the focused view see
///   the keys first. ``View/scrollOnPageKeys(_:)`` lets Page Up/Page Down
///   scroll it while focus is elsewhere.
/// - **The mouse wheel**, with ``RenderOptions/mouseReporting`` on.
/// - **The app**, through ``View/scrollPosition(_:)``.
///
/// A thin indicator in the rightmost column shows the position while the
/// content overflows (``View/scrollIndicators(_:axes:)``).
///
/// ```swift
/// ScrollView {
///     ForEach(messages) { message in Text(message.text) }
/// }
/// .defaultScrollAnchor(.bottom)
/// ```
public struct ScrollView<Content: View>: View, PrimitiveView {
    /// The scrollable axes. Only `.vertical` scrolls.
    public var axes: Axis.Set
    let content: Content

    /// Creates a scroll view.
    public init(_ axes: Axis.Set = .vertical, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.content = content()
    }

    /// Never called: `ScrollView` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let state = node.storage(at: 0) { ScrollState() }
        var environment = node.environment
        state.binding = environment.scrollPositionBinding
        state.anchors = environment.scrollAnchors
        let pageKeys = environment.scrollOnPageKeys
        // A position binding and page keys belong to this view, not to scroll views nested in it.
        environment.scrollPositionBinding = nil
        environment.scrollOnPageKeys = false
        let style = node.environment.textStyle.resolved(background: node.environment.inheritedBackground)
        node.layout = ScrollLayout(
            state: state, indicators: node.environment.verticalScrollIndicatorVisibility, style: style)
        if node.environment.isEnabled {
            node.behaviors.scroll = ScrollRegistration(state: state, scrollsOnPageKeys: pageKeys, graph: node.graph)
        }
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

/// A scroll view's offset and the measurements of its last layout. Lives in the node.
@MainActor
final class ScrollState {
    /// The position when no binding is set.
    var position = ScrollPosition()
    var binding: Binding<ScrollPosition>?
    var anchors = ScrollAnchors()
    /// Rows of content above the viewport.
    var offset = 0
    var maxOffset = 0
    var viewportHeight = 0
    var contentHeight = 0
    /// Where the content is visible, in frame coordinates (the viewport without the indicator).
    var viewport = Rect(x: 0, y: 0, width: 0, height: 0)
    var showsIndicator = false
    var hasLaidOut = false
    private var isObservingBinding = false

    /// The current position. Reading a binding also watches it, so that the
    /// app setting it draws a new frame even when no body reads it.
    func readPosition(graph: ViewGraph) -> ScrollPosition {
        guard let binding else { return position }
        guard !isObservingBinding else { return binding.wrappedValue }
        isObservingBinding = true
        return withObservationTracking {
            binding.wrappedValue
        } onChange: { [weak self, weak graph] in
            Task { @MainActor in
                self?.isObservingBinding = false
                graph?.onNeedsRender()
            }
        }
    }

    /// Stores a position the view worked out itself.
    func store(_ newPosition: ScrollPosition) {
        if let binding {
            if binding.wrappedValue != newPosition { binding.wrappedValue = newPosition }
        } else {
            position = newPosition
        }
    }

    /// Scrolls to `target` because the user asked (keys or wheel). Returns
    /// whether the view moved.
    func scrollByUser(to target: Int) -> Bool {
        let clamped = min(max(0, target), maxOffset)
        guard clamped != offset else { return false }
        offset = clamped
        store(.resting(at: clamped, maxOffset: maxOffset, byUser: true))
        return true
    }
}

/// How the runtime scrolls a scroll view from the keyboard and the mouse wheel.
@MainActor
struct ScrollRegistration {
    let state: ScrollState
    /// Whether Page Up and Page Down scroll it while focus is elsewhere.
    let scrollsOnPageKeys: Bool
    weak var graph: ViewGraph?

    /// Rows one wheel notch scrolls.
    static let wheelStep = 3

    /// Scrolls by `rows` for the wheel. Returns whether the view moved.
    func scroll(by rows: Int) -> Bool {
        guard state.scrollByUser(to: state.offset + rows) else { return false }
        graph?.onNeedsRender()
        return true
    }

    /// Handles a key press. `focused` says whether focus is in or on the scroll view.
    func handleKey(_ press: KeyPress, focused: Bool) -> KeyPress.Result {
        guard press.phase != .up, press.modifiers.subtracting([.capsLock, .numLock]).isEmpty else { return .ignored }
        let page = max(1, state.viewportHeight - 1)
        let target: Int
        switch press.key {
        case .pageUp where focused || scrollsOnPageKeys: target = state.offset - page
        case .pageDown where focused || scrollsOnPageKeys: target = state.offset + page
        case .upArrow where focused: target = state.offset - 1
        case .downArrow where focused: target = state.offset + 1
        case .home where focused: target = 0
        case .end where focused: target = state.maxOffset
        default: return .ignored
        }
        _ = scroll(by: target - state.offset)
        return .handled
    }
}

@MainActor
struct ScrollLayout: NodeLayout {
    let state: ScrollState
    let indicators: ScrollIndicatorVisibility
    let style: Style

    private func content(of node: ViewNode) -> ChildGroup {
        ChildGroup(nodes: node.layoutChildren)
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let group = content(of: node)
        guard let proposed = proposal.width, proposed < .infinity else {
            // The content's ideal size, height included: measuring the height
            // again at the ideal width would give the same rows, but at a
            // width that changes whenever the widest line does, so every row
            // would be laid out again.
            let ideal = group.sizeThatFits(ProposedSize(width: proposal.width, height: nil))
            let width = indicators == .visible ? ideal.width + 1 : ideal.width
            return Size(width: width, height: proposal.height ?? ideal.height)
        }
        if let height = proposal.height {
            return Size(width: proposed, height: height)
        }
        return Size(width: proposed, height: group.sizeThatFits(ProposedSize(width: proposed, height: nil)).height)
    }

    /// The width the content gets, and whether the indicator takes the column next to it.
    private func contentWidth(for size: Size, content: ChildGroup) -> (width: Int, showsIndicator: Bool) {
        let narrower = max(0, size.width - 1)
        switch indicators {
        case .hidden, .never:
            return (size.width, false)
        case .visible:
            return (narrower, true)
        case .automatic:
            let height = content.sizeThatFits(ProposedSize(width: size.width, height: nil)).height
            return height > size.height ? (narrower, true) : (size.width, false)
        }
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let group = content(of: node)
        let (width, showsIndicator) = contentWidth(for: bounds.size, content: group)
        let contentProposal = ProposedSize(width: width, height: nil)
        let contentHeight = group.sizeThatFits(contentProposal).height
        let viewport = bounds.size.height
        let maxOffset = max(0, contentHeight - viewport)
        var position = state.readPosition(graph: node.graph)

        var offset = resolvedOffset(position, maxOffset: maxOffset, contentHeight: contentHeight)
        if case .id(let id) = position.target {
            group.place(at: bounds.origin, proposal: contentProposal)
            offset = Self.offset(revealing: id, in: node, origin: bounds.minY, current: offset, viewport: viewport)
        }
        let settled = offset
        offset = min(max(0, offset + position.delta), maxOffset)

        var shift = 0
        if contentHeight < viewport, let anchor = state.anchors.alignment {
            shift = Int((anchor.y * Double(viewport - contentHeight)).rounded())
        }
        group.place(at: Point(x: bounds.minX, y: bounds.minY - offset + shift), proposal: contentProposal)

        state.offset = offset
        state.maxOffset = maxOffset
        state.viewportHeight = viewport
        state.contentHeight = contentHeight
        state.viewport = Rect(x: bounds.minX, y: bounds.minY, width: width, height: viewport)
        state.showsIndicator = showsIndicator
        state.hasLaidOut = true
        if position.delta != 0 {
            // `scrollBy(lines:)` is applied once; keep the target if it didn't move the view.
            if offset == settled {
                position.delta = 0
            } else {
                position = .resting(at: offset, maxOffset: maxOffset, byUser: false)
            }
            state.store(position)
        }
    }

    /// The offset `position` asks for, before `scrollBy(lines:)` and clamping.
    private func resolvedOffset(_ position: ScrollPosition, maxOffset: Int, contentHeight: Int) -> Int {
        let clamp = { (value: Int) in min(max(0, value), maxOffset) }
        switch position.target {
        case .edge(.top): return 0
        case .edge(.bottom): return maxOffset
        case .y(let y): return clamp(y)
        case .edge, .id: return clamp(state.offset)
        case nil:
            guard state.hasLaidOut else {
                let anchor = state.anchors.initialOffset?.y ?? 0
                return clamp(Int((anchor * Double(maxOffset)).rounded()))
            }
            // Keep the anchored point in place: `.bottom` keeps the distance to the bottom.
            let anchor = state.anchors.sizeChanges?.y ?? 0
            return clamp(state.offset + Int((anchor * Double(maxOffset - state.maxOffset)).rounded()))
        }
    }

    /// The smallest change of `current` that shows the view with `id`
    /// (placed with its top at content row 0 = `origin`) entirely.
    private static func offset(
        revealing id: AnyHashable, in node: ViewNode, origin: Int, current: Int, viewport: Int,
    ) -> Int {
        guard let target = node.descendant(withAppID: id), let frame = target.layoutFrame else { return current }
        let top = frame.minY - origin
        let bottom = frame.maxY - origin
        if top < current || frame.size.height > viewport { return top }
        if bottom > current + viewport { return bottom - viewport }
        return current
    }

    func childClip(_ node: ViewNode, clip: Rect) -> Rect {
        clip.intersection(state.viewport)
    }

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        guard state.showsIndicator, state.viewportHeight > 0 else { return }
        let x = node.frame.maxX - 1
        let viewport = state.viewportHeight
        let thumb: Range<Int>
        if state.maxOffset == 0 {
            thumb = 0..<viewport
        } else {
            let length = max(1, min(viewport, (viewport * viewport + state.contentHeight / 2) / state.contentHeight))
            let start = (state.offset * (viewport - length) + state.maxOffset / 2) / state.maxOffset
            thumb = start..<(start + length)
        }
        var track = style
        track.attributes.insert(.dim)
        for row in 0..<viewport {
            let run = thumb.contains(row) ? StyledRun(text: "┃", style: style) : StyledRun(text: "│", style: track)
            canvas.write([run], at: Point(x: x, y: node.frame.minY + row), clip: clip)
        }
    }
}

extension ViewNode {
    /// The first node below this one with the app-given id `id`.
    func descendant(withAppID id: AnyHashable) -> ViewNode? {
        for child in children {
            if child.appID == id { return child }
            if let found = child.descendant(withAppID: id) { return found }
        }
        return nil
    }

    /// The cells the node covers after layout: its frame, or for a
    /// transparent node the frames of its layout children together.
    var layoutFrame: Rect? {
        if layout != nil { return frame }
        let frames = children.compactMap(\.layoutFrame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { union, frame in
            let minX = min(union.minX, frame.minX)
            let minY = min(union.minY, frame.minY)
            return Rect(
                x: minX, y: minY, width: max(union.maxX, frame.maxX) - minX,
                height: max(union.maxY, frame.maxY) - minY)
        }
    }
}
