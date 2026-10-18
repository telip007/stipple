/// Arranges children top to bottom.
///
/// ```swift
/// VStack(alignment: .leading, spacing: 1) {
///     Text("Title").bold()
///     Text("Body")
/// }
/// ```
public struct VStack<Content: View>: View, PrimitiveView {
    let alignment: HorizontalAlignment
    let spacing: Int
    let content: Content

    /// Creates a vertical stack. Terminal UIs usually want `.leading`, which
    /// is the default here (SwiftUI defaults to `.center`).
    public init(alignment: HorizontalAlignment = .leading, spacing: Int = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    /// Never called: `VStack` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = StackLayout(
            axis: .vertical, alignment: Alignment(horizontal: alignment, vertical: .top), spacing: spacing)
        var environment = node.environment
        environment.stackAxis = .vertical
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

/// Arranges children left to right.
public struct HStack<Content: View>: View, PrimitiveView {
    let alignment: VerticalAlignment
    let spacing: Int
    let content: Content

    /// Creates a horizontal stack. The default alignment is `.top`, which
    /// suits multi-line terminal text (SwiftUI defaults to `.center`).
    public init(alignment: VerticalAlignment = .top, spacing: Int = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    /// Never called: `HStack` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = StackLayout(
            axis: .horizontal, alignment: Alignment(horizontal: .leading, vertical: alignment), spacing: spacing)
        var environment = node.environment
        environment.stackAxis = .horizontal
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

/// Overlays children, aligned within the largest one.
public struct ZStack<Content: View>: View, PrimitiveView {
    let alignment: Alignment
    let content: Content

    /// Creates an overlaying stack. Later children draw on top.
    public init(alignment: Alignment = .topLeading, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    /// Never called: `ZStack` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = OverlayLayout(alignment: alignment)
        var environment = node.environment
        environment.stackAxis = nil
        return [ChildView(id: nil, view: content, environment: environment)]
    }
}

/// Flexible space that expands along the enclosing stack's axis.
public struct Spacer: View, PrimitiveView {
    let minLength: Int

    /// Creates a spacer at least `minLength` cells long.
    public init(minLength: Int = 0) {
        self.minLength = minLength
    }

    /// Never called: `Spacer` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = SpacerLayout(minLength: minLength, axis: node.environment.stackAxis)
        return []
    }
}

@MainActor
struct SpacerLayout: NodeLayout {
    let minLength: Int
    let axis: Axis?

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        guard let axis else { return .zero }
        let length = max(minLength, proposal.dimension(axis) ?? minLength)
        return .along(axis, length, cross: 0)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {}
}

struct StackAxisKey: EnvironmentKey {
    static let defaultValue: Axis? = nil
}

extension EnvironmentValues {
    /// The axis of the nearest enclosing stack, for `Spacer`.
    var stackAxis: Axis? {
        get { self[StackAxisKey.self] }
        set { self[StackAxisKey.self] = newValue }
    }
}
