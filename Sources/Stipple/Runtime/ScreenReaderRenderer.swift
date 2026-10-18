/// Renders the graph as plain text for screen readers, following Ink's
/// `renderNodeToScreenReaderOutput`: text as-is, horizontal stacks joined by
/// spaces, everything else by newlines, labels replacing content, and roles
/// and states as prefixes.
@MainActor
enum ScreenReaderRenderer {
    static func text(
        of node: ViewNode,
        parentRole: AccessibilityRole? = nil,
        separator: String = "\n",
        skipStatic: Bool = true,
    ) -> String {
        let (info, content) = accessibility(startingAt: node)
        if info.isHidden || (skipStatic && content.layout is StaticLayout) {
            return ""
        }
        let role = info.role ?? parentRole
        var output: String
        if let label = info.label {
            output = label
        } else if let text = content.layout as? TextNodeLayout {
            output = text.runs.map(\.text).joined()
        } else {
            // Transparent nodes (groups, tuples, composite views) keep the enclosing stack's separator.
            let childSeparator =
                content.layout == nil ? separator : (content.layout as? StackLayout)?.axis == .horizontal ? " " : "\n"
            output = content.children
                .map { text(of: $0, parentRole: role, separator: childSeparator, skipStatic: skipStatic) }
                .filter { !$0.isEmpty }
                .joined(separator: childSeparator)
        }
        let states = info.state.names
        if !states.isEmpty {
            output = "(\(states.joined(separator: ", "))) \(output)"
        }
        if let ownRole = info.role, ownRole != parentRole {
            output = "\(ownRole.rawValue): \(output)"
        }
        return output
    }

    /// Accessibility modifiers each add a node; merge a chain of them into
    /// one description, as Ink has all `aria-*` props on a single element.
    private static func accessibility(startingAt node: ViewNode) -> (AccessibilityInfo, ViewNode) {
        var info = node.behaviors.accessibility
        var current = node
        while current.layout == nil, current.children.count == 1, current.children[0].behaviors.hasAccessibility {
            current = current.children[0]
            let inner = current.behaviors.accessibility
            info.label = info.label ?? inner.label
            info.isHidden = info.isHidden || inner.isHidden
            info.role = info.role ?? inner.role
            info.state.formUnion(inner.state)
        }
        return (info, current)
    }

    /// The not-yet-written `Static` items as screen reader text, marking them written.
    static func takeStaticOutput(from graph: ViewGraph) -> String {
        guard let root = graph.root else { return "" }
        let parts = ViewGraph.allNodes(in: root).filter { $0.layout is StaticLayout }.compactMap { node -> String? in
            let content = node.children.map { text(of: $0, skipStatic: false) }.filter { !$0.isEmpty }
                .joined(separator: "\n")
            let progress = node.storage(at: 0) { StaticProgress() }
            progress.written = progress.total
            node.rebuild()
            return content.isEmpty ? nil : content
        }
        return parts.isEmpty ? "" : parts.joined(separator: "\n") + "\n"
    }
}

extension NodeBehaviors {
    var hasAccessibility: Bool {
        accessibility.label != nil || accessibility.isHidden || accessibility.role != nil
            || !accessibility.state.isEmpty
    }
}
