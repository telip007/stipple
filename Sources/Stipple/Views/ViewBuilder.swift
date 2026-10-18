/// Builds view hierarchies from closures, like SwiftUI's `ViewBuilder`.
@resultBuilder
@MainActor
public enum ViewBuilder {
    /// An empty closure builds an `EmptyView`.
    public static func buildBlock() -> EmptyView { EmptyView() }

    /// A single view passes through unchanged.
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }

    /// Several views become a `TupleView`.
    public static func buildBlock<each Content: View>(
        _ content: repeat each Content
    ) -> TupleView<
        (repeat each Content)
    > {
        TupleView((repeat each content))
    }

    /// `if` without `else`.
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }

    /// The `if` branch of an `if`/`else`.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        first: TrueContent
    ) -> ConditionalContent<TrueContent, FalseContent> {
        ConditionalContent(storage: .trueContent(first))
    }

    /// The `else` branch of an `if`/`else`.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        second: FalseContent
    ) -> ConditionalContent<TrueContent, FalseContent> {
        ConditionalContent(storage: .falseContent(second))
    }

    /// `if #available` erases the view's type.
    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView {
        AnyView(content)
    }
}

/// Several views built by a `ViewBuilder` block.
public struct TupleView<T>: View, PrimitiveView {
    /// The views, as a tuple.
    public var value: T

    /// Wraps a tuple of views.
    public init(_ value: T) {
        self.value = value
    }

    /// Never called: `TupleView` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        Mirror(reflecting: value).children.compactMap { child in
            (child.value as? any View).map { ChildView(id: nil, view: $0, environment: node.environment) }
        }
    }
}

/// One of two views, chosen by an `if`/`else` in a `ViewBuilder`.
public struct ConditionalContent<TrueContent: View, FalseContent: View>: View, PrimitiveView {
    enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    let storage: Storage

    /// Never called: `ConditionalContent` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        // Distinct ids give the branches distinct identity, so switching
        // branches resets state, as in SwiftUI.
        switch storage {
        case .trueContent(let view): [ChildView(id: true, view: view, environment: node.environment)]
        case .falseContent(let view): [ChildView(id: false, view: view, environment: node.environment)]
        }
    }
}

extension Optional: View where Wrapped: View {
    /// Never called: an optional view is a built-in view.
    public typealias Body = Never
}

extension Optional: PrimitiveView where Wrapped: View {
    func update(_ node: ViewNode) -> [ChildView] {
        map { [ChildView(id: nil, view: $0, environment: node.environment)] } ?? []
    }
}

/// A view that shows nothing and takes no space.
public struct EmptyView: View, PrimitiveView {
    /// Creates an empty view.
    public init() {}

    /// Never called: `EmptyView` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] { [] }
}

/// Groups views without affecting layout; modifiers apply to the group.
public struct Group<Content: View>: View, PrimitiveView {
    let content: Content

    /// Creates a group from a `ViewBuilder` closure.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// Never called: `Group` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        [ChildView(id: nil, view: content, environment: node.environment)]
    }
}

/// A type-erased view.
public struct AnyView: View, PrimitiveView {
    let view: any View

    /// Erases the type of `view`.
    public init(_ view: some View) {
        self.view = (view as? Self)?.view ?? view
    }

    /// Never called: `AnyView` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        // The wrapped type is part of the identity, so a different type
        // replaces the subtree instead of reusing its state.
        [ChildView(id: ObjectIdentifier(type(of: view)), view: view, environment: node.environment)]
    }
}
