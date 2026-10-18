extension Runtime {
    struct ProducedFrame {
        var text: String
        var height: Int
        var staticOutput: String
        var cursor: CursorPosition?
    }

    func produceFrame() -> ProducedFrame {
        let size = terminal.size
        let height = writer.alternateScreen ? size.height : nil
        var staticOutput = ""
        var result = FrameRenderer.Result(frame: "", height: 0)
        // Geometry readers and geometry callbacks may change state during
        // layout; lay out again until the graph settles.
        if isScreenReaderEnabled {
            graph.flush()
            staticOutput = ScreenReaderRenderer.takeStaticOutput(from: graph)
            let text = graph.root.map { ScreenReaderRenderer.text(of: $0) } ?? ""
            return ProducedFrame(
                text: text, height: text.split(separator: "\n", omittingEmptySubsequences: false).count,
                staticOutput: staticOutput, cursor: nil)
        }
        for _ in 0..<4 {
            graph.flush()
            staticOutput += graph.takeStaticOutput(width: size.width)
            result = FrameRenderer(graph: graph).render(width: size.width, height: height)
            graph.runGeometryCallbacks()
            if !graph.hasPendingWork { break }
        }
        return ProducedFrame(
            text: result.frame, height: result.height, staticOutput: staticOutput, cursor: graph.cursorPosition)
    }
}
