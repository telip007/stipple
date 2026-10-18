extension View {
    /// Gives the view an explicit identity, as in SwiftUI. When `id`
    /// changes, the view is replaced: its state starts over. A
    /// ``ScrollPosition`` can scroll to it with `scrollTo(id:)`.
    public func id(_ id: some Hashable) -> some View {
        IdentifiedView(id: AnyHashable(id), content: self)
    }
}

/// A view with an explicit identity from `.id(_:)`.
struct IdentifiedView<Content: View>: View, PrimitiveView {
    let id: AnyHashable
    let content: Content

    typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.appID = id
        return [ChildView(id: id, view: content, environment: node.environment)]
    }
}
