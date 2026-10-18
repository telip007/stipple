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
    private var sizeCache: [ProposedSize: Size] = [:]

    /// How this node lays out and draws; `nil` for transparent nodes.
    var layout: (any NodeLayout)?
    /// Set by `.layoutPriority(_:)`; read by stacks.
    var layoutPriority = 0.0
    /// The id the app gave this view (`.id(_:)` or `ForEach`), for `ScrollPosition.scrollTo(id:)`.
    var appID: AnyHashable?
    /// Key, paste and lifecycle behaviour attached by modifiers.
    var behaviors = NodeBehaviors()
    /// Where the node was placed in the last layout pass.
    private(set) var frame = Rect(x: 0, y: 0, width: 0, height: 0)
    /// The proposal the node was placed with in the last layout pass.
    private(set) var placementProposal = ProposedSize.unspecified
    /// Whether this node or one below it rebuilt since it was last placed.
    private var needsPlacement = true
    /// Whether the last placement of this subtree used only pure layouts
    /// (``NodeLayout/placesPurely``), so it can be kept or moved as it is.
    private var placedPurely = false
    /// ``layoutChildren``, until this node or one below it rebuilds.
    private var cachedLayoutChildren: [ViewNode]?
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
        invalidateSizes()
        invalidatePlacement()
        layout = nil
        layoutPriority = 0
        let previousBehaviors = behaviors
        behaviors = NodeBehaviors()
        let specs = (view as? any PrimitiveView)?.update(self) ?? evaluateBody()
        graph.behaviorsChanged(self, from: previousBehaviors)
        reconcile(specs)
    }

    private func evaluateBody() -> [ChildView] {
        let view = view
        let body = evaluateTracked(installing: view) { Self.body(of: view) }
        return [ChildView(id: nil, view: body, environment: environment)]
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

    /// The size this node wants for `proposal`; cached until the subtree rebuilds.
    func sizeThatFits(_ proposal: ProposedSize) -> Size {
        if let cached = sizeCache[proposal] { return cached }
        let size =
            layout?.sizeThatFits(proposal, node: self) ?? ChildGroup(nodes: layoutChildren).sizeThatFits(proposal)
        sizeCache[proposal] = size
        return size
    }

    /// Places the node at `origin` with the size it wants for `proposal`.
    /// A pure subtree that didn't change keeps its placement, moved to
    /// `origin` if it has to be.
    func place(at origin: Point, proposal: ProposedSize) {
        if !needsPlacement, placedPurely, proposal == placementProposal {
            if origin != frame.origin {
                move(by: Point(x: origin.x - frame.minX, y: origin.y - frame.minY))
            }
            return
        }
        frame = Rect(origin: origin, size: sizeThatFits(proposal))
        placementProposal = proposal
        let children = layoutChildren
        if let layout {
            layout.placeChildren(of: self, in: frame, proposal: proposal)
        } else {
            ChildGroup(nodes: children).place(at: origin, proposal: proposal)
        }
        needsPlacement = false
        placedPurely = (layout?.placesPurely ?? true) && children.allSatisfy(\.placedPurely)
    }

    /// Moves this subtree's frames by `delta`.
    private func move(by delta: Point) {
        frame = Rect(origin: Point(x: frame.minX + delta.x, y: frame.minY + delta.y), size: frame.size)
        for child in children {
            child.move(by: delta)
        }
    }

    /// Marks this node and its ancestors for placing again and forgets their
    /// layout children, which may include this node's. The walk goes to the
    /// root: transparent nodes are never placed themselves, so their mark
    /// stays set and can't end it.
    private func invalidatePlacement() {
        var node: ViewNode? = self
        while let current = node {
            current.needsPlacement = true
            current.cachedLayoutChildren = nil
            node = current.parent
        }
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

    // MARK: Drawing

    /// Draws this subtree.
    func draw(into canvas: inout Canvas, clip: Rect) {
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
