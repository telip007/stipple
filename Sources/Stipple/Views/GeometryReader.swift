/// The size and position a `GeometryReader` or `onGeometryChange` was given.
public struct GeometryProxy: Hashable, Sendable {
    /// The view's size in cells.
    public var size: Size
    /// The view's frame relative to the top-left corner of the frame.
    public var frame: Rect
}

/// Builds its content from the space it is offered (Ink's `measureElement`
/// and `useBoxMetrics`). It fills the offered space; in inline mode, where
/// height isn't limited, it is as tall as its content.
///
/// The content sees the size from the previous layout pass; the first
/// pass sees zero and Stipple immediately lays out again.
public struct GeometryReader<Content: View>: View, PrimitiveView {
    let content: (GeometryProxy) -> Content

    /// Creates a reader.
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    /// Never called: `GeometryReader` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let geometry = node.storage(at: 0) { GeometryBox() }
        node.layout = GeometryReaderLayout(geometry: geometry)
        return [ChildView(id: nil, view: content(geometry.proxy), environment: node.environment)]
    }
}

@MainActor
final class GeometryBox {
    var proxy = GeometryProxy(size: .zero, frame: Rect(x: 0, y: 0, width: 0, height: 0))
}

@MainActor
struct GeometryReaderLayout: SingleChildLayout {
    let geometry: GeometryBox

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        let ideal = (proposal.width == nil || proposal.height == nil) ? content(of: node).sizeThatFits(proposal) : .zero
        return Size(width: proposal.width ?? ideal.width, height: proposal.height ?? ideal.height)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: ProposedSize(bounds.size))
        let proxy = GeometryProxy(size: bounds.size, frame: bounds)
        if proxy != geometry.proxy {
            geometry.proxy = proxy
            node.invalidate()
        }
    }
}

extension View {
    /// Calls `action` with a value derived from the view's geometry whenever
    /// that value changes after layout.
    public func onGeometryChange<Value: Equatable>(
        for type: Value.Type,
        of transform: @escaping @MainActor (GeometryProxy) -> Value,
        action: @escaping @MainActor (_ newValue: Value) -> Void,
    ) -> some View {
        modified { node, _ in
            let last = node.storage(at: Int.min + 1) { ChangeBox<Value>() }
            node.layout = PassThroughLayout()
            node.behaviors.geometryChange.append { frame in
                let value = transform(GeometryProxy(size: frame.size, frame: frame))
                guard last.value != value else { return }
                last.value = value
                action(value)
            }
        }
    }
}
