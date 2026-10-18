extension Stipple {
    /// Renders `view` once, `width` columns wide, and returns the frame as a
    /// string with ANSI styling (Ink's `renderToString`). Effects such as
    /// `.task` and key handlers don't run. Colors are reduced to
    /// `colorDepth`, which defaults to truecolor (colors as written).
    @MainActor
    public static func renderToString(
        _ view: some View, width: Int = 80, colorDepth: ColorDepth = .trueColor,
    ) -> String {
        let graph = ViewGraph()
        graph.mount(view, environment: EnvironmentValues())
        defer { graph.unmountAll() }
        var staticOutput = ""
        var frame = ""
        // Geometry readers see their size from the previous pass; repeat
        // until the graph settles, as the runtime does.
        for _ in 0..<4 {
            graph.flush()
            staticOutput += graph.takeStaticOutput(width: width, colorDepth: colorDepth)
            frame = FrameRenderer(graph: graph, colorDepth: colorDepth).render(width: width, height: nil).frame
            graph.runGeometryCallbacks()
            if !graph.hasPendingWork { break }
        }
        return staticOutput + frame
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
    var colorDepth = ColorDepth.trueColor

    func render(width: Int, height: Int?) -> Result {
        guard let root = graph.root else { return Result(frame: "", height: 0) }
        let proposal = ProposedSize(width: width, height: height)
        let size = root.sizeThatFits(proposal)
        root.place(at: .zero, proposal: proposal)
        let canvasHeight = height.map { min($0, size.height) } ?? size.height
        var canvas = Canvas(width: width, height: canvasHeight)
        root.draw(into: &canvas, clip: Rect(x: 0, y: 0, width: width, height: canvasHeight))
        return Result(frame: canvas.encodedLines(colorDepth: colorDepth).joined(separator: "\n"), height: canvasHeight)
    }
}
