/// Property wrappers (`@State`, `@Environment`, …) that Stipple connects to
/// a view's node before evaluating its body.
@MainActor
protocol DynamicPropertyLink {
    /// Connects the property at position `index` of a view to `node`.
    func install(in node: ViewNode, index: Int)
}

extension ViewNode {
    /// Finds every dynamic property of `owner` (a view or modifier) and connects it to this node.
    /// Mirror copies of a property share its reference-typed link, so
    /// installing into the copy reaches the view's own property.
    func installDynamicProperties(of owner: some Any) {
        for (index, child) in Mirror(reflecting: owner).children.enumerated() {
            (child.value as? any DynamicPropertyLink)?.install(in: self, index: index)
        }
    }
}
