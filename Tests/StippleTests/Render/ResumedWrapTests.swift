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
}
