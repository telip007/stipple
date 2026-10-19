import Observation

/// One view in the live view graph: the retained counterpart of a view
/// value. It owns the view's state, its children and its last layout.
@MainActor
final class ViewNode {
    private enum ChildKey: Hashable {
        case position(Int, ObjectIdentifier)
        case explicit(AnyHashable, ObjectIdentifier)
    }

    unowned let graph: ViewGraph
    private(set) weak var parent: ViewNode?
    private(set) var view: any View
    private(set) var environment: EnvironmentValues
    private(set) var children: [ViewNode] = []
    private var childKeys: [ChildKey] = []
    private var storage: [Int: AnyObject] = [:]
    /// Sizes by proposal, kept across frames until the node or a node below
    /// it rebuilds: layouts are values set on rebuild, so a size can only
    /// change when the subtree does.
    /// A short list searched in order: a node sees only a few proposals,
    /// and comparing them beats hashing them.
    private var sizeCache: [(proposal: ProposedSize, size: Size)] = []
    /// Proposals a node keeps sizes for; past this the oldest is dropped.
    private static let sizeCacheLimit = 8

    /// How this node lays out and draws; `nil` for transparent nodes.
    var layout: (any NodeLayout)?
    /// Set by `.layoutPriority(_:)`; read by stacks.
    var layoutPriority = 0.0
    /// The id the app gave this view (`.id(_:)` or `ForEach`), for `ScrollPosition.scrollTo(id:)`.
    var appID: AnyHashable?
    /// Key, paste and lifecycle behaviour attached by modifiers.
    var behaviors = NodeBehaviors()
    /// Where the node was placed in the last layout pass.
    var frame: Rect {
        applyPendingMoves()
        return placedFrame
    }
    /// ``frame`` as last set, without moves still pending above.
    private var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
    /// A move of this node not yet applied to its children: moving a subtree
    /// is free, and only the nodes that are read again (drawn, hit, measured
    /// for a callback) pay for it.
    private var pendingMove = Point.zero
    /// What this subtree's placed nodes cover, to skip drawing it when it is
    /// out of view; `nil` until it has been placed.
    private var placedBounds: Rect?
    /// The proposal the node was placed with in the last layout pass.
    private(set) var placementProposal = ProposedSize.unspecified
    /// Whether this node or one below it rebuilt since it was last placed.
    private var needsPlacement = true
    /// Whether the last placement of this subtree used only pure layouts
    /// (``NodeLayout/placesPurely``), so it can be kept or moved as it is.
    private var placedPurely = false
    /// ``layoutChildren``, until this node or one below it rebuilds.
    private var cachedLayoutChildren: [ViewNode]?
    /// Left out of the last layout pass by a lazy stack: its frame is stale,
    /// so drawing and hit testing skip it.
    var isOutOfLayout = false
    /// ``behaviorKinds``, until this node or one below it rebuilds.
    private var cachedBehaviorKinds: BehaviorKinds?
    private(set) var isMounted = true
    var isDirty = false
    let depth: Int

    init(graph: ViewGraph, parent: ViewNode?, view: any View, environment: EnvironmentValues) {
        self.graph = graph
        self.parent = parent
        self.view = view
        self.environment = environment
        depth = (parent?.depth ?? -1) + 1
    }

    /// Persistent storage for the dynamic property at `index`, created on first use.
    func storage<Object: AnyObject>(at index: Int, create: () -> Object) -> Object {
        if let existing = storage[index] as? Object { return existing }
        let object = create()
        storage[index] = object
        return object
    }

    // MARK: Building

    /// Gives the node a new view value and environment from its parent and
    /// rebuilds it. An `Equatable` view equal to the current one, in the same
    /// environment, keeps its subtree: nothing it shows can have changed
    /// unless it was invalidated.
    func update(view: any View, environment: EnvironmentValues) {
        if !isDirty, environment.isIdentical(to: self.environment), areEqual(self.view, view) {
            return
        }
        self.view = view
        self.environment = environment
        rebuild()
    }

    /// Re-evaluates the node's view and reconciles its children.
    func rebuild() {
        isDirty = false
        graph.treeChanged()
        invalidateSizes()
        invalidatePlacement()
        layout = nil
        layoutPriority = 0
        let previousBehaviors = behaviors
        behaviors = NodeBehaviors()
        let specs = (view as? any PrimitiveView).map(updateTracked) ?? evaluateBody()
        graph.behaviorsChanged(self, from: previousBehaviors)
        reconcile(specs)
    }

    private func evaluateBody() -> [ChildView] {
        let view = view
        let body = evaluateTracked(installing: view) { Self.body(of: view) }
        return [ChildView(id: nil, view: body, environment: environment)]
    }

    /// Runs a primitive view's update while tracking what it reads: a
    /// `ForEach` builds its rows there, and a row that reads an observable
    /// value must redraw when it changes.
    private func updateTracked(_ primitive: any PrimitiveView) -> [ChildView] {
        let graph = graph
        return withObservationTracking {
            primitive.update(self)
        } onChange: { [weak self] in
            graph.invalidations.enqueue(self)
        }
    }

    private static func body<V: View>(of view: V) -> any View {
        view.body
    }

    /// Connects the dynamic properties of `owner` to this node, then runs
    /// `build` while tracking which observable values it reads; a later
    /// change to any of them invalidates the node.
    func evaluateTracked(installing owner: some Any, _ build: () -> any View) -> any View {
        installDynamicProperties(of: owner)
        let graph = graph
        return withObservationTracking(build) { [weak self] in
            graph.invalidations.enqueue(self)
        }
    }

    /// Marks the node for rebuilding on the next render.
    func invalidate() {
        guard isMounted, !isDirty else { return }
        isDirty = true
        graph.scheduleRebuild(self)
    }

    private func reconcile(_ specs: [ChildView]) {
        var existing = Dictionary(uniqueKeysWithValues: zip(childKeys, children))
        var newChildren: [ViewNode] = []
        var newKeys: [ChildKey] = []
        for (position, spec) in specs.enumerated() {
            let type = ObjectIdentifier(Swift.type(of: spec.view))
            let key = spec.id.map { ChildKey.explicit($0, type) } ?? .position(position, type)
            let child: ViewNode
            if let reused = existing.removeValue(forKey: key) {
                child = reused
                child.update(view: spec.view, environment: spec.environment)
            } else {
                child = ViewNode(graph: graph, parent: self, view: spec.view, environment: spec.environment)
                graph.mounted(child)
                child.rebuild()
            }
            if spec.isAppID { child.appID = spec.id }
            newChildren.append(child)
            newKeys.append(key)
        }
        for removed in existing.values {
            removed.unmountSubtree()
        }
        children = newChildren
        childKeys = newKeys
    }

    func unmountSubtree() {
        isMounted = false
        for child in children {
            child.unmountSubtree()
        }
        graph.unmounted(self)
    }

    // MARK: Layout

    /// The nodes that take part in this node's layout: children with a
    /// layout, and the layout children of transparent children.
    var layoutChildren: [ViewNode] {
        if let cachedLayoutChildren { return cachedLayoutChildren }
        let nodes = children.flatMap { $0.layout == nil ? $0.layoutChildren : [$0] }
        cachedLayoutChildren = nodes
        return nodes
    }

    /// The size cached for `proposal`, without working it out.
    func cachedSize(for proposal: ProposedSize) -> Size? {
        for entry in sizeCache where entry.proposal == proposal {
            return entry.size
        }
        return nil
    }

    /// The size last worked out with unlimited height, at whatever width: a
    /// stand-in for a size not worked out yet.
    var lastKnownSize: Size? {
        for entry in sizeCache.reversed() where entry.proposal.height == nil {
            return entry.size
        }
        return nil
    }

    /// Asks for this node to be measured and placed again on the next pass,
    /// for a layout that left work for later.
    func layoutChanged() {
        invalidateSizes()
        invalidatePlacement()
    }

    /// The size this node wants for `proposal`; cached until the subtree rebuilds.
    func sizeThatFits(_ proposal: ProposedSize) -> Size {
        for entry in sizeCache where entry.proposal == proposal {
            return entry.size
        }
        let size =
            layout?.sizeThatFits(proposal, node: self) ?? ChildGroup(nodes: layoutChildren).sizeThatFits(proposal)
        if sizeCache.count == Self.sizeCacheLimit {
            sizeCache.removeFirst()
        }
        sizeCache.append((proposal, size))
        return size
    }

    /// Forgets the cached sizes of this node and of its ancestors, whose
    /// sizes depend on it. An empty cache on a node with a layout ends the
    /// walk: sizes above it were either forgotten with it or computed without
    /// asking it. Transparent nodes don't end it, as parents measure through
    /// them (``layoutChildren``) and leave their caches empty.
    private func invalidateSizes() {
        var node: ViewNode? = self
        while let current = node, current.layout == nil || !current.sizeCache.isEmpty {
            current.sizeCache.removeAll()
            node = current.parent
        }
    }
}

// MARK: - Placement and drawing

extension ViewNode {
    /// Places the node at `origin` with the size it wants for `proposal`.
    /// A pure subtree that didn't change keeps its placement, moved to
    /// `origin` if it has to be.
    func place(at origin: Point, proposal: ProposedSize) {
        isOutOfLayout = false
        // Placing goes top down, and a parent hands its moves down before it
        // places its children, so the moves above this node are applied.
        if !needsPlacement, placedPurely, proposal == placementProposal {
            if origin != placedFrame.origin {
                move(by: Point(x: origin.x - placedFrame.minX, y: origin.y - placedFrame.minY))
            }
            return
        }
        // The children are placed afresh, from where they are now.
        pushPendingMove()
        placedFrame = Rect(origin: origin, size: sizeThatFits(proposal))
        placementProposal = proposal
        // Cleared before the children are placed, so a layout that leaves
        // work for the next pass (a lazy stack) can ask for it again.
        needsPlacement = false
        let children = layoutChildren
        if let layout {
            layout.placeChildren(of: self, in: placedFrame, proposal: proposal)
        } else {
            ChildGroup(nodes: children).place(at: origin, proposal: proposal)
        }
        // A loop rather than `allSatisfy` and `reduce`: closures in this
        // main-actor class are checked for the actor on every call.
        var pure = layout?.placesPurely ?? true
        var bounds = placedFrame
        for child in children {
            pure = pure && child.placedPurely
            if let childBounds = child.placedBounds {
                bounds = bounds.union(childBounds)
            }
        }
        placedPurely = pure
        placedBounds = bounds
    }

    /// Moves this subtree by `delta`: this node now, its children when read.
    private func move(by delta: Point) {
        placedFrame = placedFrame.offsetBy(delta)
        placedBounds = placedBounds?.offsetBy(delta)
        pendingMove = Point(x: pendingMove.x + delta.x, y: pendingMove.y + delta.y)
    }

    /// Whether this subtree may cover cells in row `row`: `false` only for a
    /// placed subtree that lies entirely above or below it.
    func mayCover(row: Int) -> Bool {
        if isOutOfLayout { return false }
        guard layout != nil, let placedBounds else { return true }
        return row >= placedBounds.minY && row < placedBounds.maxY
    }

    /// Applies the moves pending above this node to it.
    private func applyPendingMoves() {
        guard let parent else { return }
        parent.applyPendingMoves()
        parent.pushPendingMove()
    }

    /// Hands this node's pending move to its children. Walks from the root
    /// down call it on each node they enter, so the nodes below are current.
    func pushPendingMove() {
        guard pendingMove != .zero else { return }
        let delta = pendingMove
        pendingMove = .zero
        for child in children {
            child.move(by: delta)
        }
    }

    /// Marks this node and its ancestors for placing again and forgets their
    /// layout children, which may include this node's. The walk goes to the
    /// root: transparent nodes are never placed themselves, so their mark
    /// stays set and can't end it.
    fileprivate func invalidatePlacement() {
        var node: ViewNode? = self
        while let current = node {
            current.needsPlacement = true
            current.cachedLayoutChildren = nil
            current.cachedBehaviorKinds = nil
            node = current.parent
        }
    }

    // MARK: Drawing

    /// Draws this subtree.
    func draw(into canvas: inout Canvas, clip: Rect) {
        // Rows scrolled out of view are skipped whole. Only rows: text can be
        // wider than its frame, so nothing is skipped sideways.
        // Drawing goes top down and hands moves down as it goes, so the
        // moves above this node are already applied.
        if isOutOfLayout {
            return
        }
        if layout != nil, let placedBounds, placedBounds.maxY <= clip.minY || placedBounds.minY >= clip.maxY {
            return
        }
        pushPendingMove()
        var childClip = clip
        if let layout {
            layout.draw(self, into: &canvas, clip: clip)
            childClip = layout.childClip(self, clip: clip)
        }
        for child in children {
            child.draw(into: &canvas, clip: childClip)
        }
    }
}

/// Kinds of behaviour a subtree has, so walks that look for one kind can
/// skip the subtrees without it.
struct BehaviorKinds: OptionSet {
    let rawValue: UInt8

    static let focus = Self(rawValue: 1 << 0)
    static let keys = Self(rawValue: 1 << 1)
    static let paste = Self(rawValue: 1 << 2)
    static let geometry = Self(rawValue: 1 << 3)
    static let hover = Self(rawValue: 1 << 4)
    static let scroll = Self(rawValue: 1 << 5)
    /// A cursor position, or a text field, which sets one while placed.
    static let cursor = Self(rawValue: 1 << 6)
}

extension ViewNode {
    /// The kinds of behaviour this node and the nodes below it have.
    var behaviorKinds: BehaviorKinds {
        if let cachedBehaviorKinds { return cachedBehaviorKinds }
        var kinds = ownBehaviorKinds
        for child in children {
            kinds.formUnion(child.behaviorKinds)
        }
        cachedBehaviorKinds = kinds
        return kinds
    }

    private var ownBehaviorKinds: BehaviorKinds {
        var kinds: BehaviorKinds = []
        if behaviors.focus != nil { kinds.insert(.focus) }
        if !behaviors.keyHandlers.isEmpty { kinds.insert(.keys) }
        if !behaviors.pasteHandlers.isEmpty { kinds.insert(.paste) }
        if !behaviors.geometryChange.isEmpty { kinds.insert(.geometry) }
        if !behaviors.hoverHandlers.isEmpty { kinds.insert(.hover) }
        if behaviors.scroll != nil { kinds.insert(.scroll) }
        if behaviors.cursorPosition != nil || layout is FieldLayout { kinds.insert(.cursor) }
        return kinds
    }

    /// Calls `body` with this node and every node below it that may have one
    /// of `kinds`, in tree order, skipping subtrees with none of them.
    func visit(having kinds: BehaviorKinds, _ body: (ViewNode) -> Void) {
        guard !behaviorKinds.isDisjoint(with: kinds) else { return }
        body(self)
        for child in children {
            child.visit(having: kinds, body)
        }
    }
}
