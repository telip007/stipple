/// The live view hierarchy: builds nodes, batches rebuilds, runs lifecycle
/// callbacks and tasks after each update, and owns focus.
@MainActor
final class ViewGraph {
    private(set) var root: ViewNode?
    private var pendingRebuilds: [ViewNode] = []
    private var mountedNodes: [ViewNode] = []
    private var touchedNodes: [ViewNode] = []
    private var afterFlush: [@MainActor () -> Void] = []
    private var runningTasks: [ObjectIdentifier: [(id: AnyHashable?, task: Task<Void, Never>)]] = [:]
    let focus = FocusController()
    /// Nodes whose observed values changed, possibly reported off the main actor.
    let invalidations = InvalidationQueue()

    /// Called when something needs a new frame.
    var onNeedsRender: @MainActor () -> Void = {}

    init() {
        invalidations.onEnqueue = { [weak self] in
            Task { @MainActor in self?.drainInvalidations() }
        }
    }

    /// Marks every node reported by observation as dirty.
    func drainInvalidations() {
        for node in invalidations.drain() {
            node.invalidate()
        }
    }

    /// Builds the graph for `view`.
    func mount(_ view: some View, environment: EnvironmentValues) {
        let node = ViewNode(graph: self, parent: nil, view: view, environment: environment)
        root = node
        mounted(node)
        node.rebuild()
        finishUpdate()
    }

    /// Replaces the root view's value, keeping state where the type matches.
    func update(_ view: some View, environment: EnvironmentValues) {
        guard let root, type(of: root.view) == type(of: view) else {
            unmountAll()
            mount(view, environment: environment)
            return
        }
        root.update(view: view, environment: environment)
        finishUpdate()
    }

    /// Tears the graph down, running `onDisappear` and cancelling tasks.
    func unmountAll() {
        root?.unmountFromGraph()
        root = nil
        pendingRebuilds.removeAll()
    }

    /// Rebuilds every invalidated node, parents first, then runs callbacks.
    /// Returns whether anything was rebuilt.
    @discardableResult
    func flush() -> Bool {
        drainInvalidations()
        guard !pendingRebuilds.isEmpty else { return false }
        let pending = pendingRebuilds.sorted { $0.depth < $1.depth }
        pendingRebuilds.removeAll()
        for node in pending where node.isDirty && node.isMounted {
            node.rebuild()
        }
        finishUpdate()
        return true
    }

    var hasPendingWork: Bool { !pendingRebuilds.isEmpty || !invalidations.isEmpty }

    /// Runs `action` after the current update's rebuilds and callbacks.
    func enqueueAfterFlush(_ action: @escaping @MainActor () -> Void) {
        afterFlush.append(action)
    }

    // MARK: Node notifications

    func scheduleRebuild(_ node: ViewNode) {
        pendingRebuilds.append(node)
        onNeedsRender()
    }

    func mounted(_ node: ViewNode) {
        mountedNodes.append(node)
    }

    func behaviorsChanged(_ node: ViewNode, from previous: NodeBehaviors) {
        if !node.behaviors.isEmpty || !previous.isEmpty {
            touchedNodes.append(node)
        }
    }

    func unmounted(_ node: ViewNode) {
        for action in node.behaviors.onDisappear {
            action()
        }
        cancelTasks(of: node)
        focus.nodeRemoved(node)
    }

    // MARK: Lifecycle

    private func finishUpdate() {
        let appeared = mountedNodes
        mountedNodes.removeAll()
        let touched = touchedNodes
        touchedNodes.removeAll()
        for node in appeared where node.isMounted {
            for action in node.behaviors.onAppear {
                action()
            }
        }
        for node in touched where node.isMounted {
            syncTasks(of: node)
        }
        focus.update(root: root)
        let actions = afterFlush
        afterFlush.removeAll()
        for action in actions {
            action()
        }
    }

    private func syncTasks(of node: ViewNode) {
        let key = ObjectIdentifier(node)
        let wanted = node.behaviors.tasks
        var running = runningTasks[key] ?? []
        for index in wanted.indices {
            if index < running.count, running[index].id == wanted[index].id { continue }
            if index < running.count { running[index].task.cancel() }
            let action = wanted[index].action
            let entry = (id: wanted[index].id, task: Task { @MainActor in await action() })
            if index < running.count { running[index] = entry } else { running.append(entry) }
        }
        for extra in running.dropFirst(wanted.count) {
            extra.task.cancel()
        }
        runningTasks[key] = running.isEmpty ? nil : Array(running.prefix(wanted.count))
    }

    private func cancelTasks(of node: ViewNode) {
        for entry in runningTasks.removeValue(forKey: ObjectIdentifier(node)) ?? [] {
            entry.task.cancel()
        }
    }
}

extension ViewNode {
    /// Unmounts this node as the graph root.
    func unmountFromGraph() {
        unmountSubtree()
    }
}
