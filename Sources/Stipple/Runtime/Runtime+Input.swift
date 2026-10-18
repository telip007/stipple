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
        case .mouse(let event):
            handleMouse(event)
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
    /// Key handlers that may see a press, in dispatch order: the focused
    /// path (innermost first), scroll views in or around focus, global
    /// handlers in tree order, then scroll views that take Page Up and Page
    /// Down while focus is elsewhere.
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
        let scrollViews = Self.allNodes(in: root).filter { $0.behaviors.scroll != nil }
        let focused = scrollViews.filter(isScrollFocused).reversed().compactMap(\.behaviors.scroll)
        let unfocused = scrollViews.filter { !isScrollFocused($0) }.compactMap(\.behaviors.scroll)
            .filter(\.scrollsOnPageKeys)
        let focusedHandlers = focused.map { scroll -> @MainActor (KeyPress) -> KeyPress.Result in
            { press in scroll.handleKey(press, focused: true) }
        }
        let pageHandlers = unfocused.map { scroll -> @MainActor (KeyPress) -> KeyPress.Result in
            { press in scroll.handleKey(press, focused: false) }
        }
        return scoped + focusedHandlers + global.flatMap(\.behaviors.keyHandlers) + pageHandlers
    }

    /// Whether a scroll view takes focus keys: focus is inside it, or on
    /// the nearest focusable view around it (`ScrollView { … }.focusable()`).
    func isScrollFocused(_ node: ViewNode) -> Bool {
        guard let focused = focus.focusedNode else { return false }
        if focus.containsFocus(node) { return true }
        var current: ViewNode? = node
        while let candidate = current {
            if candidate.behaviors.focus != nil { return candidate === focused }
            current = candidate.parent
        }
        return false
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
        root?.visit { node in
            for callback in node.behaviors.geometryChange {
                callback(node.frame)
            }
        }
    }

    /// Where the terminal cursor should rest: the last `.cursorPosition(_:)` in tree order.
    var cursorPosition: CursorPosition? {
        var last: ViewNode?
        root?.visit { node in
            if node.behaviors.cursorPosition != nil { last = node }
        }
        guard let node = last, let point = node.behaviors.cursorPosition else { return nil }
        return CursorPosition(x: node.frame.minX + point.x, y: node.frame.minY + point.y)
    }

    private static func globalNodes(in node: ViewNode, insideFocusable: Bool) -> [ViewNode] {
        var nodes: [ViewNode] = []
        collectGlobalNodes(in: node, insideFocusable: insideFocusable, into: &nodes)
        return nodes
    }

    private static func collectGlobalNodes(in node: ViewNode, insideFocusable: Bool, into nodes: inout [ViewNode]) {
        let inside = insideFocusable || node.behaviors.focus != nil
        if !inside, !node.behaviors.keyHandlers.isEmpty {
            nodes.append(node)
        }
        for child in node.children {
            collectGlobalNodes(in: child, insideFocusable: inside, into: &nodes)
        }
    }

    /// `node` and every node below it, in tree order.
    static func allNodes(in node: ViewNode) -> [ViewNode] {
        var nodes: [ViewNode] = []
        node.visit { nodes.append($0) }
        return nodes
    }
}

extension ViewNode {
    /// Calls `body` with this node and every node below it, in tree order.
    func visit(_ body: (ViewNode) -> Void) {
        body(self)
        for child in children {
            child.visit(body)
        }
    }

    /// Whether this node or one below it satisfies `predicate`.
    func containsNode(where predicate: (ViewNode) -> Bool) -> Bool {
        predicate(self) || children.contains { $0.containsNode(where: predicate) }
    }

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
