/// Whether a key press was consumed. Unhandled presses continue to other handlers.
extension KeyPress {
    /// The outcome of a key press handler, as in SwiftUI.
    public enum Result: Hashable, Sendable {
        /// The press was consumed; no other handler sees it.
        case handled
        /// The press was not consumed; other handlers see it.
        case ignored
    }
}

/// Behaviour attached to a node by modifiers. Rebuilt on every update of the node.
@MainActor
struct NodeBehaviors {
    struct Task {
        var id: AnyHashable?
        var action: @MainActor () async -> Void
    }

    var keyHandlers: [@MainActor (KeyPress) -> KeyPress.Result] = []
    var pasteHandlers: [@MainActor (String) -> Void] = []
    var onAppear: [@MainActor () -> Void] = []
    var onDisappear: [@MainActor () -> Void] = []
    var tasks: [Task] = []
    var focus: FocusRegistration?
    var geometryChange: [@MainActor (Rect) -> Void] = []
    var cursorPosition: Point?
    var timeline: Duration?

    var isEmpty: Bool {
        keyHandlers.isEmpty && pasteHandlers.isEmpty && onAppear.isEmpty && onDisappear.isEmpty && tasks.isEmpty
            && focus == nil && geometryChange.isEmpty && cursorPosition == nil && timeline == nil
    }
}

/// A focusable node and how its focus is mirrored into a `@FocusState`.
@MainActor
struct FocusRegistration {
    /// Whether the node can take focus right now.
    var isEnabled: Bool
    /// Asked to focus on mount when nothing else has focus.
    var autoFocus: Bool
    /// Whether the bound focus state says this node should be focused right
    /// now; `nil` when no `@FocusState` is bound.
    var isRequested: @MainActor () -> Bool?
    /// Writes the bound focus state when focus moves to (`true`) or away from (`false`) the node.
    var update: @MainActor (Bool) -> Void
}
