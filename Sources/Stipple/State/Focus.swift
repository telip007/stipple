/// Tracks focusable nodes in tree order and which one has focus. Tab and
/// Shift-Tab move focus, Escape clears it, as in Ink.
@MainActor
final class FocusController {
    private(set) weak var focusedNode: ViewNode?
    private var focusables: [ViewNode] = []
    /// When `false`, Tab does nothing and nothing can take focus (Ink's `disableFocus`).
    var isEnabled = true

    /// Re-reads focusable nodes after an update, applies focus requests from
    /// `@FocusState` bindings and auto-focus.
    func update(root: ViewNode?) {
        focusables = root.map(Self.collectFocusables) ?? []
        if let focusedNode, !focusables.contains(where: { $0 === focusedNode }) {
            self.focusedNode = nil
        }
        if let requested = focusables.last(where: { $0.behaviors.focus?.isRequested() == true }) {
            focus(requested)
        } else if let registration = focusedNode?.behaviors.focus,
            registration.isRequested() == false || !registration.isEnabled
        {
            blur()
        } else if focusedNode == nil,
            let auto = focusables.first(where: {
                $0.behaviors.focus?.autoFocus == true && $0.behaviors.focus?.isEnabled == true
            })
        {
            focus(auto)
        }
    }

    /// Moves focus to `node`.
    func focus(_ node: ViewNode?) {
        guard isEnabled || node == nil, node !== focusedNode else { return }
        let previous = focusedNode
        focusedNode = node
        previous?.behaviors.focus?.update(false)
        node?.behaviors.focus?.update(true)
    }

    /// Clears focus.
    func blur() {
        focus(nil)
    }

    /// Focuses the next enabled focusable, wrapping around.
    func focusNext() {
        move(by: 1)
    }

    /// Focuses the previous enabled focusable, wrapping around.
    func focusPrevious() {
        move(by: -1)
    }

    func nodeRemoved(_ node: ViewNode) {
        if node === focusedNode {
            focusedNode = nil
        }
    }

    /// Whether `node` is focused or contains the focused node.
    func containsFocus(_ node: ViewNode) -> Bool {
        var current = focusedNode
        while let candidate = current {
            if candidate === node { return true }
            current = candidate.parent
        }
        return false
    }

    private func move(by step: Int) {
        let enabled = focusables.filter { $0.behaviors.focus?.isEnabled == true }
        guard isEnabled, !enabled.isEmpty else { return }
        guard let current = focusedNode, let index = enabled.firstIndex(where: { $0 === current }) else {
            focus(step > 0 ? enabled.first : enabled.last)
            return
        }
        focus(enabled[(index + step + enabled.count) % enabled.count])
    }

    private static func collectFocusables(_ root: ViewNode) -> [ViewNode] {
        var nodes: [ViewNode] = []
        root.visit(having: .focus) { node in
            if node.behaviors.focus != nil {
                nodes.append(node)
            }
        }
        return nodes
    }
}
