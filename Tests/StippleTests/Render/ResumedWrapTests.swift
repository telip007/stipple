import Testing

@testable import Stipple

@MainActor
struct ResumedWrapTests {
    /// A small deterministic generator, so a failure can be replayed.
    private struct Generator {
        var state: UInt64

        mutating func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private static let pieces = [
        "a", "word", " ", "  ", "longerword", "averyveryverylongwordthatbreaks", "\n", "\n\n", "é", "日本", "x y", "\t",
        "e\u{301}", "\u{200B}", "👍🏽", "  ", "a\u{301}bc",
    ]
    private static let styles = [Style.plain, Style(foreground: .red)]

    /// Text grown one piece at a time and wrapped from the checkpoint each
    /// time gives the same rows as wrapping it from the start.
    @Test(arguments: 1...16)
    func resumingMatchesWrappingFromTheStart(seed: Int) {
        var random = Generator(state: UInt64(seed))
        let width = 1 + random.next(14)
        var runs: [StyledRun] = []
        var checkpoint: WrapCheckpoint?
        for _ in 0..<40 {
            let text = Self.pieces[random.next(Self.pieces.count)]
            let style = Self.styles[random.next(Self.styles.count)]
            if let last = runs.last, last.style == style, random.next(2) == 0 {
                runs[runs.count - 1].text += text
            } else {
                runs.append(StyledRun(text: text, style: style))
            }
            let resumed = TextLayout.wrap(runs, width: width, resuming: checkpoint)
            checkpoint = resumed.checkpoint
            #expect(resumed.lines == TextLayout.wrap(runs, width: width), "seed \(seed), width \(width)")
        }
    }

    @Test func changedTextWrapsFromTheStart() {
        let first = TextLayout.wrap([StyledRun(text: "one two", style: .plain)], width: 4, resuming: nil)
        let other = [StyledRun(text: "three", style: .plain)]
        #expect(TextLayout.wrap(other, width: 4, resuming: first.checkpoint).lines == TextLayout.wrap(other, width: 4))
    }

    @Test func aStreamedTextNodeShowsEveryWord() {
        let graph = ViewGraph()
        let text = Text("alpha beta")
        graph.mount(text, environment: EnvironmentValues())
        graph.flush()
        _ = FrameRenderer(graph: graph).render(width: 8, height: nil)
        graph.update(Text("alpha beta gamma"), environment: EnvironmentValues())
        let frame = FrameRenderer(graph: graph).render(width: 8, height: nil).frame
        #expect(frame.replacing(/\u{1B}\[[0-9;]*m/, with: "").contains("gamma"))
    }

    /// Measuring from word widths gives the size of the laid-out lines.
    @Test(arguments: 1...16)
    func metricsMatchTheLaidOutLines(seed: Int) {
        var random = Generator(state: UInt64(seed) &* 7_919)
        var runs: [StyledRun] = []
        for _ in 0..<(1 + random.next(40)) {
            let text = Self.pieces[random.next(Self.pieces.count)]
            runs.append(StyledRun(text: text, style: Self.styles[random.next(Self.styles.count)]))
        }
        let metrics = WrapMetrics(runs)
        for width in 1...30 {
            let lines = TextLayout.wrap(runs, width: width)
            let widest = lines.map { line in line.reduce(0) { $0 + TextMetrics.width(of: $1.text) } }.max() ?? 0
            #expect(
                metrics.size(width: width) == Size(width: widest, height: lines.count), "seed \(seed), width \(width)")
        }
    }

    /// A text laid out at one width and then at others, as stacks and
    /// resizes ask, gives the lines a fresh layout gives at each width.
    @Test(arguments: 1...12)
    func reusedAndMeasuredLinesMatchAFreshLayout(seed: Int) {
        var random = Generator(state: UInt64(seed) &* 104_729)
        var runs: [StyledRun] = []
        for _ in 0..<(1 + random.next(30)) {
            runs.append(StyledRun(text: Self.pieces[random.next(Self.pieces.count)], style: .plain))
        }
        let environment = EnvironmentValues()
        let graph = ViewGraph()
        let node = ViewNode(graph: graph, parent: nil, view: EmptyView(), environment: environment)
        let kept = TextNodeLayout(runs: runs, environment: environment, memory: TextMemory())
        for _ in 0..<12 {
            let width = 1 + random.next(30)
            let proposal = ProposedSize(width: width, height: nil)
            let fresh = TextNodeLayout(runs: runs, environment: environment)
            #expect(kept.sizeThatFits(proposal, node: node) == fresh.sizeThatFits(proposal, node: node), "seed \(seed)")
            #expect(kept.lines(width: width) == fresh.lines(width: width), "seed \(seed), width \(width)")
        }
    }
}
