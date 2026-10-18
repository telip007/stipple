/// A piece of terminal UI, declared as a value. Compose views in `body`,
/// exactly as in SwiftUI:
///
/// ```swift
/// struct Greeting: View {
///     var name: String
///     var body: some View {
///         Text("Hello, \(name)!").bold()
///     }
/// }
/// ```
@MainActor
public protocol View {
    /// The type of view this view is composed of.
    associatedtype Body: View

    /// The content of this view. Stipple calls it whenever state the body
    /// reads changes.
    @ViewBuilder var body: Body { get }
}

extension Never: View {
    /// `Never` has no body; it marks views that Stipple draws itself.
    public typealias Body = Never
}

extension View where Body == Never {
    /// Built-in views have no body. Accessing it is a programming error.
    public var body: Never {
        preconditionFailure("\(Self.self) is a built-in view and has no body")
    }
}

/// Built-in views: instead of a body they describe their children and how
/// their node lays out and draws.
@MainActor
protocol PrimitiveView {
    /// Configures `node` (layout, handlers, state) for this value and returns
    /// the child views to reconcile.
    func update(_ node: ViewNode) -> [ChildView]
}

/// A child view to reconcile under a node.
struct ChildView {
    /// Explicit identity (from `ForEach`); `nil` means identity by position.
    var id: AnyHashable?
    /// The child.
    var view: any View
    /// The environment the child sees.
    var environment: EnvironmentValues
    /// Whether `id` is an id the app chose (`ForEach`), which
    /// `ScrollPosition.scrollTo(id:)` can find, rather than an internal one.
    var isAppID = false
}
