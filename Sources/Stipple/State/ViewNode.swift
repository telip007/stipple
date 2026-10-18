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
    private var sizeCache: [ProposedSize: Size] = [:]

    /// How this node lays out and draws; `nil` for transparent nodes.
    var layout: (any NodeLayout)?
    /// Set by `.layoutPriority(_:)`; read by stacks.
    var layoutPriority = 0.0
    /// Key, paste and lifecycle behaviour attached by modifiers.
    var behaviors = NodeBehaviors()
    /// Where the node was placed in the last layout pass.
    private(set) var frame = Rect(x: 0, y: 0, width: 0, height: 0)
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

    /// Gives the node a new view value and environment from its parent and rebuilds it.
    func update(view: any View, environment: EnvironmentValues) {
        self.view = view
        self.environment = environment
        rebuild()
    }

    /// Re-evaluates the node's view and reconciles its children.
    func rebuild() {
        isDirty = false
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
        return withObservationTracking(build) { [weak self] in
            Task { @MainActor in self?.invalidate() }
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
        children.flatMap { $0.layout == nil ? $0.layoutChildren : [$0] }
    }

    /// The size this node wants for `proposal`; cached per layout pass.
    func sizeThatFits(_ proposal: ProposedSize) -> Size {
        if let cached = sizeCache[proposal] { return cached }
        let size =
            layout?.sizeThatFits(proposal, node: self) ?? ChildGroup(nodes: layoutChildren).sizeThatFits(proposal)
        sizeCache[proposal] = size
        return size
    }

    /// Places the node at `origin` with the size it wants for `proposal`.
    func place(at origin: Point, proposal: ProposedSize) {
        frame = Rect(origin: origin, size: sizeThatFits(proposal))
        if let layout {
            layout.placeChildren(of: self, in: frame, proposal: proposal)
        } else {
            ChildGroup(nodes: layoutChildren).place(at: origin, proposal: proposal)
        }
    }

    /// Forgets cached sizes in this subtree before a new layout pass.
    func resetLayoutCache() {
        sizeCache.removeAll(keepingCapacity: true)
        for child in children {
            child.resetLayoutCache()
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
