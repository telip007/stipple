/// Writes each item once, above the live area, where it stays in the
/// terminal's scrollback (Ink's `<Static>`). Use it for logs, finished
/// tasks or chat history: anything that doesn't change once shown.
///
/// Items are tracked by position: append new items to the end; changing or
/// removing items that were already written has no effect.
///
/// ```swift
/// Static(finishedTasks) { task in
///     Text("✔ \(task.name)").foregroundStyle(.green)
/// }
/// ```
public struct Static<Data: RandomAccessCollection, Content: View>: View, PrimitiveView {
    let data: Data
    let content: (Data.Element) -> Content

    /// Creates a static list from `data`.
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    /// Never called: `Static` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let progress = node.storage(at: 0) { StaticProgress() }
        progress.total = data.count
        node.layout = StaticLayout()
        var environment = node.environment
        environment.stackAxis = .vertical
        return data.dropFirst(progress.written).enumerated().map { offset, element in
            ChildView(id: progress.written + offset, view: content(element), environment: environment)
        }
    }
}

/// How many items of a `Static` were written to scrollback.
@MainActor
final class StaticProgress {
    var written = 0
    var total = 0
}

/// Takes no space in the live frame and draws nothing there; the runtime
/// renders its children separately into the static output.
@MainActor
struct StaticLayout: NodeLayout {
    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size { .zero }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {}

    func childClip(_ node: ViewNode, clip: Rect) -> Rect { Rect(x: 0, y: 0, width: 0, height: 0) }
}

extension ViewGraph {
    /// Renders the not-yet-written items of every `Static` in the graph,
    /// `width` columns wide, marks them written and returns the text to put
    /// above the frame ("" when there is none), colors reduced to `colorDepth`.
    func takeStaticOutput(width: Int, colorDepth: ColorDepth = .trueColor) -> String {
        guard let root else { return "" }
        let lines = Self.staticNodes(in: root).flatMap { node -> [String] in
            let pending = node.layoutChildren
            guard !pending.isEmpty else { return [] }
            let group = ChildGroup(nodes: pending)
            let proposal = ProposedSize(width: width, height: nil)
            let size = group.sizeThatFits(proposal)
            group.place(at: .zero, proposal: proposal)
            var canvas = Canvas(width: width, height: size.height)
            let clip = Rect(x: 0, y: 0, width: width, height: size.height)
            for child in node.children {
                child.draw(into: &canvas, clip: clip)
            }
            let progress = node.storage(at: 0) { StaticProgress() }
            progress.written = progress.total
            node.rebuild()
            return canvas.encodedLines(colorDepth: colorDepth)
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    private static func staticNodes(in node: ViewNode) -> [ViewNode] {
        (node.layout is StaticLayout ? [node] : []) + node.children.flatMap(staticNodes)
    }
}
