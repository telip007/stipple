public import Observation

extension View {
    /// Colors the text in this view and its descendants.
    public func foregroundStyle(_ color: Color?) -> some View {
        environmentChange { $0.textStyle.foreground = .some(color) }
    }

    /// Makes text in this view bold.
    public func bold(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.bold, isActive) }
    }

    /// Makes text in this view italic.
    public func italic(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.italic, isActive) }
    }

    /// Underlines text in this view.
    public func underline(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.underline, isActive) }
    }

    /// Strikes text in this view through.
    public func strikethrough(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.strikethrough, isActive) }
    }

    /// Dims text in this view (Ink's `dimColor`).
    public func dim(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.dim, isActive) }
    }

    /// Swaps foreground and background colors of text in this view.
    public func inverse(_ isActive: Bool = true) -> some View {
        environmentChange { $0.textStyle.set(.inverse, isActive) }
    }

    /// Limits text to `number` lines; the last line is truncated. With
    /// `.truncationMode(.head)` the last `number` lines are kept instead and
    /// the first of them is truncated, as in SwiftUI. `nil` removes the limit.
    public func lineLimit(_ number: Int?) -> some View {
        environmentChange { $0.lineLimit = number }
    }

    /// How text breaks lines wider than the offered space. `.truncate` shortens
    /// every line on its own, like Ink's `wrap="truncate"`; `.lineLimit(1)`
    /// instead keeps only the first line, as in SwiftUI.
    public func textWrapping(_ wrapping: TextWrapping) -> some View {
        environmentChange { $0.textWrapping = wrapping }
    }

    /// Where text that doesn't fit is shortened.
    public func truncationMode(_ mode: TruncationMode) -> some View {
        environmentChange { $0.truncationMode = mode }
    }

    /// How the lines of multi-line text align.
    public func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        environmentChange { $0.multilineTextAlignment = alignment }
    }

    /// Fills the view's frame with a color. Text inside inherits it as its background.
    public func background(_ color: Color) -> some View {
        modified { node, environment in
            node.layout = BackgroundLayout(color: color)
            environment.inheritedBackground = color
        }
    }

    /// Draws a border around the view, inside its frame (Ink's `borderStyle`).
    public func border(_ style: BorderStyle = .single, color: Color? = nil, edges: Edge.Set = .all) -> some View {
        modified { node, environment in
            node.layout = BorderLayout(
                border: style, style: Style(foreground: color, background: environment.inheritedBackground),
                edges: edges)
        }
    }

    /// Places a value in the environment for this view and its descendants.
    public func environment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, _ value: Value) -> some View {
        environmentChange { $0[keyPath: keyPath] = value }
    }

    /// Places an observable object in the environment, readable with `@Environment(Type.self)`.
    public func environment<Object: AnyObject & Observable>(_ object: Object?) -> some View {
        environmentChange { $0.setObject(object) }
    }
}

@MainActor
struct BackgroundLayout: SingleChildLayout {
    let color: Color

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: proposal)
    }

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        canvas.fill(node.frame, background: color, clip: clip)
    }
}

@MainActor
struct BorderLayout: SingleChildLayout {
    let border: BorderStyle
    let style: Style
    let edges: Edge.Set

    private var insets: EdgeInsets { EdgeInsets(edges, 1) }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let inner = content(of: node).sizeThatFits(proposal.inset(by: insets))
        return Size(width: inner.width + insets.horizontal, height: inner.height + insets.vertical)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        let origin = Point(x: bounds.minX + insets.leading, y: bounds.minY + insets.top)
        content(of: node).place(at: origin, proposal: proposal.inset(by: insets))
    }

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        canvas.drawBorder(border, in: node.frame, edges: edges, style: style, clip: clip)
    }
}
