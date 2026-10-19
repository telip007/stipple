/// Recognises taps: which view a left press went down on, and the series of
/// recent clicks for `onTapGesture(count:)`.
@MainActor
struct ClickTracker {
    /// Clicks closer together than this, on the same cell, form a series.
    static let interval = Duration.milliseconds(500)

    /// One click of a series.
    struct Click {
        var location: Point
        var time: ContinuousClock.Instant
        var count: Int
    }

    weak var pressed: ViewNode?
    var last: Click?
    /// The clock clicks are timed with; tests stop it so that a slow machine
    /// doesn't split a double click.
    var now: @MainActor () -> ContinuousClock.Instant = { ContinuousClock.now }
    /// The nodes with hover handlers that the pointer is over.
    var hovered: [Weak] = []

    /// A weak reference, so hover state doesn't keep unmounted nodes alive.
    struct Weak {
        weak var node: ViewNode?
    }
}

extension Runtime {
    /// Routes one mouse report: the wheel scrolls, a left press focuses and
    /// starts a tap, the release finishes it, and every report updates hover.
    func handleMouse(_ event: MouseEvent) {
        updateHover(at: event.location)
        switch event.kind {
        case .scroll(let direction):
            switch direction {
            case .up: scrollWheel(at: event.location, rows: -ScrollRegistration.wheelStep)
            case .down: scrollWheel(at: event.location, rows: ScrollRegistration.wheelStep)
            case .left, .right: break
            }
        case .press(.left):
            focusClicked(at: event.location)
            clicks.pressed = tapTarget(at: event.location)
        case .release(.left), .release(nil):
            finishClick(at: event.location)
        case .press, .release, .move:
            break
        }
    }

    /// Scrolls the innermost scroll view under the pointer that can move,
    /// then the ones around it. Inline output doesn't know which screen row
    /// its first line is on, so there the scroll views in or around focus
    /// come first, then the innermost one in tree order.
    private func scrollWheel(at location: Point, rows: Int) {
        guard let root = graph.root else { return }
        let candidates: [ViewNode]
        if writer.alternateScreen {
            candidates = ViewGraph.nodes(at: location, in: root).filter { $0.behaviors.scroll != nil }
        } else {
            var all: [ViewNode] = []
            root.visit(having: .scroll) { node in
                if node.behaviors.scroll != nil { all.append(node) }
            }
            let focused: [ViewNode] = all.filter(graph.isScrollFocused).reversed()
            let innermostFirst: [ViewNode] = all.reversed()
            candidates = focused + innermostFirst
        }
        for node in candidates where node.behaviors.scroll?.scroll(by: rows) == true {
            return
        }
    }

    /// The innermost node under the pointer, and the nodes around it, innermost
    /// first; empty off the alternate screen, where the frame's screen row is unknown.
    private func pathUnderPointer(at location: Point) -> [ViewNode] {
        guard writer.alternateScreen, let root = graph.root,
            let innermost = ViewGraph.nodes(at: location, in: root).first
        else { return [] }
        var path: [ViewNode] = []
        var current: ViewNode? = innermost
        while let node = current {
            path.append(node)
            current = node.parent
        }
        return path
    }

    /// The innermost view under the pointer that handles taps.
    private func tapTarget(at location: Point) -> ViewNode? {
        pathUnderPointer(at: location).first { !$0.behaviors.tapHandlers.isEmpty }
    }

    /// Focuses the innermost focusable view under the pointer, as a click in a GUI does.
    private func focusClicked(at location: Point) {
        guard let node = pathUnderPointer(at: location).first(where: { $0.behaviors.focus != nil }),
            node.behaviors.focus?.isEnabled == true, node !== graph.focus.focusedNode
        else { return }
        graph.focus.focus(node)
        scheduleRender()
    }

    /// Calls `onHover` handlers whose view the pointer entered (`true`) or left (`false`).
    private func updateHover(at location: Point) {
        let now = pathUnderPointer(at: location).filter { !$0.behaviors.hoverHandlers.isEmpty }
        let before = clicks.hovered.compactMap(\.node)
        clicks.hovered = now.map(ClickTracker.Weak.init)
        for node in before where node.isMounted && !now.contains(where: { $0 === node }) {
            for handler in node.behaviors.hoverHandlers { handler(false) }
        }
        for node in now.reversed() where !before.contains(where: { $0 === node }) {
            for handler in node.behaviors.hoverHandlers { handler(true) }
        }
    }

    /// Turns motion reporting on while some view has an `onHover` handler.
    func syncMouseMotion() {
        guard options.mouseReporting, let root = graph.root else { return }
        terminal.setMouseMotionReporting(root.behaviorKinds.contains(.hover))
    }

    private func finishClick(at location: Point) {
        guard let pressed = clicks.pressed else { return }
        clicks.pressed = nil
        guard tapTarget(at: location) === pressed else { return }
        let now = clicks.now()
        var count = 1
        if let last = clicks.last, last.location == location, now - last.time < ClickTracker.interval {
            count = last.count + 1
        }
        clicks.last = ClickTracker.Click(location: location, time: now, count: count)
        // For each click count, the innermost handler around the pressed view wins, so
        // `.onTapGesture(count: 2)` stacked on `.onTapGesture` still sees double clicks.
        var seen: Set<Int> = []
        var current: ViewNode? = pressed
        while let node = current {
            for handler in node.behaviors.tapHandlers where seen.insert(handler.count).inserted {
                if count.isMultiple(of: handler.count) { handler.action() }
            }
            current = node.parent
        }
    }
}

extension ViewGraph {
    /// The nodes with a layout whose visible part contains `point`,
    /// topmost first: the last drawn, innermost one leads.
    static func nodes(at point: Point, in root: ViewNode) -> [ViewNode] {
        var hits: [ViewNode] = []
        collectHits(at: point, in: root, clip: Rect(x: 0, y: 0, width: .infinity, height: .infinity), into: &hits)
        return hits.reversed()
    }

    private static func collectHits(at point: Point, in node: ViewNode, clip: Rect, into hits: inout [ViewNode]) {
        guard node.mayCover(row: point.y) else { return }
        node.pushPendingMove()
        var childClip = clip
        if let layout = node.layout {
            if node.frame.intersection(clip).contains(point) { hits.append(node) }
            childClip = layout.childClip(node, clip: clip)
        }
        for child in node.children {
            collectHits(at: point, in: child, clip: childClip, into: &hits)
        }
    }
}
