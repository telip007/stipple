/// A built-in modifier applied to `content`: it configures the node (layout,
/// behaviours) and the environment its content sees.
struct ModifiedView<Content: View>: View, PrimitiveView {
    let content: Content
    let configure: @MainActor (ViewNode, inout EnvironmentValues) -> Void

    typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        var environment = node.environment
        configure(node, &environment)
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

extension View {
    func modified(_ configure: @escaping @MainActor (ViewNode, inout EnvironmentValues) -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, configure: configure)
    }

    func layout(_ layout: some NodeLayout) -> ModifiedView<Self> {
        modified { node, _ in node.layout = layout }
    }

    func environmentChange(_ change: @escaping @MainActor (inout EnvironmentValues) -> Void) -> ModifiedView<Self> {
        modified { _, environment in change(&environment) }
    }

    func behavior(_ change: @escaping @MainActor (inout NodeBehaviors) -> Void) -> ModifiedView<Self> {
        modified { node, _ in change(&node.behaviors) }
    }
}

/// A modifier you write yourself, as in SwiftUI.
///
/// ```swift
/// struct Card: ViewModifier {
///     func body(content: Content) -> some View {
///         content.padding(1).border(.rounded)
///     }
/// }
/// ```
@MainActor
public protocol ViewModifier {
    /// The view the modifier produces.
    associatedtype Body: View
    /// The modified view's placeholder.
    typealias Content = ViewModifierContent
    /// Builds the modified view from `content`.
    @ViewBuilder func body(content: Content) -> Body
}

/// Stands for the view a `ViewModifier` is applied to.
public struct ViewModifierContent: View, PrimitiveView {
    let view: any View

    /// Never called: the placeholder is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        [ChildView(id: nil, view: view, environment: node.environment)]
    }
}

/// A view with a custom `ViewModifier` applied.
public struct ModifiedContent<Content: View, Modifier: ViewModifier>: View, PrimitiveView {
    let content: Content
    let modifier: Modifier

    /// Never called: modified content is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let body = node.evaluateTracked(installing: modifier) {
            modifier.body(content: ViewModifierContent(view: content))
        }
        return [ChildView(id: nil, view: body, environment: node.environment)]
    }
}

extension View {
    /// Applies a custom modifier.
    public func modifier<Modifier: ViewModifier>(_ modifier: Modifier) -> ModifiedContent<Self, Modifier> {
        ModifiedContent(content: self, modifier: modifier)
    }
}
