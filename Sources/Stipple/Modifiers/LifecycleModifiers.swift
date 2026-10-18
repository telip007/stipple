extension View {
    /// Runs `action` when the view first appears.
    public func onAppear(perform action: @escaping @MainActor () -> Void) -> some View {
        behavior { $0.onAppear.append(action) }
    }

    /// Runs `action` when the view is removed.
    public func onDisappear(perform action: @escaping @MainActor () -> Void) -> some View {
        behavior { $0.onDisappear.append(action) }
    }

    /// Starts `action` when the view appears and cancels it when the view disappears.
    public func task(_ action: @escaping @MainActor () async -> Void) -> some View {
        behavior { $0.tasks.append(NodeBehaviors.Task(id: nil, action: action)) }
    }

    /// Like `task(_:)`, but restarts the task whenever `id` changes.
    public func task<ID: Hashable>(id: ID, _ action: @escaping @MainActor () async -> Void) -> some View {
        behavior { $0.tasks.append(NodeBehaviors.Task(id: AnyHashable(id), action: action)) }
    }

    /// Runs `action` with the old and new value whenever `value` changes
    /// between updates. With `initial`, it also runs once on appear.
    public func onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping @MainActor (_ oldValue: Value, _ newValue: Value) -> Void,
    ) -> some View {
        modified { node, _ in
            let box = node.storage(at: Int.min) { ChangeBox<Value>() }
            let previous = box.value
            box.value = value
            if let previous, previous != value {
                node.graph.enqueueAfterFlush { action(previous, value) }
            } else if previous == nil, initial {
                node.graph.enqueueAfterFlush { action(value, value) }
            }
        }
    }

    /// Runs `action` whenever `value` changes between updates.
    public func onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping @MainActor () -> Void,
    ) -> some View {
        onChange(of: value, initial: initial) { _, _ in action() }
    }
}

@MainActor
final class ChangeBox<Value> {
    var value: Value?
}
