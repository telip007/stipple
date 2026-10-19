import Testing

@testable import Stipple

/// A chat: rows of wrapping text in a scroll view pinned to its bottom.
private struct Chat: View {
    let count: Int
    let isLazy: Bool

    var body: some View {
        ScrollView {
            if isLazy {
                LazyVStack {
                    ForEach(0..<count, id: \.self) { Text(Self.text($0)) }
                }
            } else {
                VStack {
                    ForEach(0..<count, id: \.self) { Text(Self.text($0)) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .frame(height: 6)
    }

    static func text(_ index: Int) -> String {
        "row \(index) " + String(repeating: "word ", count: index % 7)
    }
}

@MainActor
struct LazyVStackTests {
    /// A graph drawn like the runtime does, noting when it asks for another frame.
    @MainActor
    private final class Screen {
        let graph = ViewGraph()
        var needsFrame = false

        init(_ view: some View) {
            graph.onNeedsRender = { [weak self] in self?.needsFrame = true }
            graph.mount(view, environment: EnvironmentValues())
        }

        func scroll(to offset: Int) {
            graph.root?.visit { node in
                _ = node.behaviors.scroll?.state.scrollByUser(to: offset)
            }
        }

        func frame(width: Int) -> String {
            needsFrame = false
            var text = ""
            for _ in 0..<4 {
                graph.flush()
                text = FrameRenderer(graph: graph).render(width: width, height: 6).frame
                graph.runGeometryCallbacks()
                if !graph.hasPendingWork { break }
            }
            return text
        }
    }

    @Test func laysOutLikeAVStackAtEveryWidth() {
        let lazy = Screen(Chat(count: 300, isLazy: true))
        let eager = Screen(Chat(count: 300, isLazy: false))
        for width in [40, 40, 25, 18, 30] {
            // What is in view matches at once, while rows above it may still stand in.
            #expect(lazy.frame(width: width) == eager.frame(width: width), "width \(width)")
        }
        // The rows above settle over the next frames, and then nothing is left to do.
        var frames = 0
        while lazy.needsFrame, frames < 1_000 {
            _ = lazy.frame(width: 30)
            frames += 1
        }
        #expect(!lazy.needsFrame)
        let settledLazy = lazy.frame(width: 30)
        let settledEager = eager.frame(width: 30)
        #expect(settledLazy == settledEager)
    }

    /// The first line on screen, without styling.
    private func topLine(_ frame: String) -> String {
        String(frame.replacing(/\u{1B}\[[0-9;]*m/, with: "").split(separator: "\n").first ?? "")
    }

    @Test func scrolledAwayItKeepsTheFirstRowInViewAcrossResizes() {
        let lazy = Screen(Chat(count: 300, isLazy: true))
        _ = lazy.frame(width: 40)
        // Scroll so that row 150 starts on the top line.
        var offset = 0
        for index in 0..<150 {
            offset += TextLayout.wrap([StyledRun(text: Chat.text(index), style: .plain)], width: 40).count
        }
        lazy.scroll(to: offset)
        #expect(topLine(lazy.frame(width: 40)).hasPrefix("row 150 "))
        // Narrower and wider: the rows above wrap differently, but row 150 stays put.
        for width in [22, 35] {
            #expect(topLine(lazy.frame(width: width)).hasPrefix("row 150 "), "width \(width)")
        }
        var frames = 0
        while lazy.needsFrame, frames < 1_000 {
            _ = lazy.frame(width: 35)
            frames += 1
        }
        #expect(topLine(lazy.frame(width: 35)).hasPrefix("row 150 "))
        // The user can still scroll away from it.
        lazy.scroll(to: offset + 3)
        #expect(!topLine(lazy.frame(width: 35)).hasPrefix("row 150 "))
    }

    @Test func outsideAScrollViewItIsAVStack() {
        let lazy = Stipple.renderToString(
            LazyVStack {
                Text("a")
                Text("b")
            }, width: 10)
        let eager = Stipple.renderToString(
            VStack {
                Text("a")
                Text("b")
            }, width: 10)
        #expect(lazy == eager)
    }
}
