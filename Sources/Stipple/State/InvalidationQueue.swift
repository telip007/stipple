import Synchronization

/// Collects nodes whose observed values changed. Observation reports changes
/// synchronously on whatever thread mutated the value, before the new value
/// is stored; queueing them here lets the next flush see every change, even
/// one made just before `exit()`, without waiting for a task hop.
final class InvalidationQueue: Sendable {
    private struct Entry: Sendable {
        weak var node: ViewNode?
    }

    private let entries = Mutex<[Entry]>([])
    private let callback = Mutex<(@Sendable () -> Void)?>(nil)

    /// Called after each enqueue, to schedule a drain on the main actor.
    var onEnqueue: (@Sendable () -> Void)? {
        get { callback.withLock { $0 } }
        set { callback.withLock { $0 = newValue } }
    }

    var isEmpty: Bool { entries.withLock { $0.isEmpty } }

    func enqueue(_ node: ViewNode?) {
        entries.withLock { $0.append(Entry(node: node)) }
        onEnqueue?()
    }

    func drain() -> [ViewNode] {
        entries.withLock { entries in
            defer { entries.removeAll() }
            return entries.compactMap(\.node)
        }
    }
}
