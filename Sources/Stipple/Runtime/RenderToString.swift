extension Stipple {
    /// Renders `view` once, `width` columns wide, and returns the frame as a
    /// string with ANSI styling (Ink's `renderToString`). Effects such as
    /// `.task` and key handlers don't run.
    @MainActor
    public static func renderToString(_ view: some View, width: Int = 80) -> String {
        let graph = ViewGraph()
        graph.mount(view, environment: EnvironmentValues())
        defer { graph.unmountAll() }
        let staticOutput = graph.takeStaticOutput(width: width)
        return staticOutput + FrameRenderer(graph: graph).render(width: width, height: nil).frame
    }
}

/// Lays out and draws the graph into a frame string.
@MainActor
struct FrameRenderer {
    struct Result {
        var frame: String
        var height: Int
    }

    let graph: ViewGraph

    func render(width: Int, height: Int?) -> Result {
        guard let root = graph.root else { return Result(frame: "", height: 0) }
        root.resetLayoutCache()
        let proposal = ProposedSize(width: width, height: height)
        let size = root.sizeThatFits(proposal)
        root.place(at: .zero, proposal: proposal)
        let canvasHeight = height.map { min($0, size.height) } ?? size.height
        var canvas = Canvas(width: width, height: canvasHeight)
        root.draw(into: &canvas, clip: Rect(x: 0, y: 0, width: width, height: canvasHeight))
        return Result(frame: canvas.encodedLines().joined(separator: "\n"), height: canvasHeight)
    }
}
