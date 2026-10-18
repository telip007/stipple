extension Runtime {
    /// Routes one decoded input event: Ctrl-C exit, focus keys, then handlers.
    func handle(_ input: InputEvent) {
        switch input {
        case .key(let press):
            handleKey(press)
        case .paste(let text):
            handlePaste(text)
        case .focus:
            break
        case .kittyKeyboardSupported:
            if options.keyboardProtocol == .automatic {
                terminal.pushKittyKeyboard(KittyKeyboardFlags.disambiguateEscapeCodes)
            }
        }
    }

    private func handleKey(_ press: KeyPress) {
        let modifiers = press.modifiers.subtracting([.capsLock, .numLock])
        if options.exitOnCtrlC, press.key == "c", modifiers == .control, press.phase != .up {
            exit(with: nil)
            return
        }
        if press.phase != .up {
            handleFocusKey(press, modifiers: modifiers)
        }
        dispatch(press)
    }

    /// Tab and Shift-Tab move focus; Escape clears it (Ink's `App`).
    private func handleFocusKey(_ press: KeyPress, modifiers: EventModifiers) {
        switch press.key {
        case .tab where modifiers.isSubset(of: .shift):
            if modifiers.contains(.shift) {
                graph.focus.focusPrevious()
            } else {
                graph.focus.focusNext()
            }
            scheduleRender()
        case .escape where modifiers.isEmpty && graph.focus.focusedNode != nil:
            graph.focus.blur()
            scheduleRender()
        default:
            break
        }
    }

    /// Calls key handlers until one handles the press: first those around the
    /// focused view (innermost first), then global handlers in tree order.
    func dispatch(_ press: KeyPress) {
        for handler in graph.keyHandlers() where handler(press) == .handled {
            return
        }
    }

    private func handlePaste(_ text: String) {
        let handlers = graph.pasteHandlers()
        guard !handlers.isEmpty else {
            // Without a paste handler, a paste arrives as typed text (Ink sends it to `useInput`).
            dispatch(KeyPress(key: text.first.map(KeyEquivalent.character) ?? .space, characters: text))
            return
        }
        for handler in handlers {
            handler(text)
        }
    }
}

extension ViewGraph {
    /// Key handlers that may see a press, in dispatch order.
    func keyHandlers() -> [@MainActor (KeyPress) -> KeyPress.Result] {
        guard let root else { return [] }
        var focusedPath: [ViewNode] = []
        var current = focus.focusedNode
        while let node = current {
            focusedPath.append(node)
            current = node.parent
        }
        let scoped = focusedPath.flatMap(\.behaviors.keyHandlers)
        let global = Self.globalNodes(in: root, insideFocusable: false).filter { node in
            !focusedPath.contains { $0 === node }
        }
        return scoped + global.flatMap(\.behaviors.keyHandlers)
    }

    /// Paste handlers that may see a paste: focused path plus global ones.
    func pasteHandlers() -> [@MainActor (String) -> Void] {
        guard let root else { return [] }
        return Self.allNodes(in: root).filter { node in
            !node.behaviors.pasteHandlers.isEmpty && (focus.containsFocus(node) || !node.isInsideFocusable)
        }
        .flatMap(\.behaviors.pasteHandlers)
    }

    /// Calls geometry-change callbacks with each node's latest frame.
    func runGeometryCallbacks() {
        guard let root else { return }
        for node in Self.allNodes(in: root) {
            for callback in node.behaviors.geometryChange {
                callback(node.frame)
            }
        }
    }

    /// Where the terminal cursor should rest: the last `.cursorPosition(_:)` in tree order.
    var cursorPosition: CursorPosition? {
        guard let root else { return nil }
        guard let node = Self.allNodes(in: root).last(where: { $0.behaviors.cursorPosition != nil }),
            let point = node.behaviors.cursorPosition
        else { return nil }
        return CursorPosition(x: node.frame.minX + point.x, y: node.frame.minY + point.y)
    }

    private static func globalNodes(in node: ViewNode, insideFocusable: Bool) -> [ViewNode] {
        let inside = insideFocusable || node.behaviors.focus != nil
        let own = inside || node.behaviors.keyHandlers.isEmpty ? [] : [node]
        return own + node.children.flatMap { globalNodes(in: $0, insideFocusable: inside) }
    }

    static func allNodes(in node: ViewNode) -> [ViewNode] {
        [node] + node.children.flatMap(allNodes)
    }
}

extension ViewNode {
    /// Whether this node or an ancestor is focusable.
    var isInsideFocusable: Bool {
        var current: ViewNode? = self
        while let node = current {
            if node.behaviors.focus != nil { return true }
            current = node.parent
        }
        return false
    }
}
