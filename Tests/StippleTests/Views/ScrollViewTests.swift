import Testing

@testable import Stipple

/// `count` numbered lines, each with its number as `ForEach` id.
private struct Lines: View {
    var count: Int

    var body: some View {
        ForEach(0..<count) { index in
            Text("line \(index)")
        }
    }
}

@MainActor
private func scrolled(_ view: some View, width: Int = 12) -> String {
    Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
}

@MainActor
private func scrolledLines(_ view: some View, width: Int = 12) -> [String] {
    scrolled(view, width: width).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

@MainActor
@Suite struct ScrollViewTests {
    // MARK: Layout and slicing

    @Test func showsTheTopSliceWithAnIndicator() {
        let view = ScrollView { Lines(count: 10) }.frame(height: 3)
        #expect(scrolledLines(view) == ["line 0     ┃", "line 1     │", "line 2     │"])
    }

    @Test func hidesTheIndicator() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden).frame(height: 3)
        #expect(scrolled(view) == "line 0\nline 1\nline 2")
    }

    @Test func automaticIndicatorOnlyWhenContentOverflows() {
        let view = ScrollView { Lines(count: 2) }.frame(height: 3)
        #expect(scrolled(view) == "line 0\nline 1\n")
    }

    @Test func visibleIndicatorEvenWithoutOverflow() {
        let view = ScrollView { Lines(count: 2) }.scrollIndicators(.visible).frame(height: 2)
        #expect(scrolledLines(view) == ["line 0     ┃", "line 1     ┃"])
    }

    @Test func indicatorTakesAColumnFromTheContent() {
        // Ten columns of text at width 10 wrap once the indicator takes one.
        let view = ScrollView {
            Text("abcde fghij")
            Lines(count: 3)
        }.frame(height: 2)
        #expect(scrolledLines(view, width: 10).first == "abcde    ┃")
    }

    @Test func withoutAProposedHeightShowsEverything() {
        let view = ScrollView { Lines(count: 3) }
        #expect(scrolled(view) == "line 0\nline 1\nline 2")
    }

    @Test func clipsContentToTheViewport() {
        let view = VStack {
            ScrollView { Lines(count: 10) }.scrollIndicators(.hidden).frame(height: 2)
            Text("below")
        }
        #expect(scrolled(view) == "line 0\nline 1\nbelow")
    }

    @Test func takesTheRemainingHeightInAStack() {
        let view = VStack {
            Text("top")
            ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            Text("bottom")
        }
        .frame(height: 5)
        #expect(scrolled(view) == "top\nline 0\nline 1\nline 2\nbottom")
    }

    @Test func fillsTheOfferedWidth() {
        let view = HStack {
            ScrollView { Text("ab") }.frame(height: 1)
            Text("|")
        }
        #expect(scrolled(view) == "ab         |")
    }

    @Test func idealWidthIsTheContentWidth() {
        let view = HStack {
            ScrollView { Text("ab") }.frame(height: 1).fixedSize(horizontal: true, vertical: false)
            Text("|")
        }
        #expect(scrolled(view) == "ab|")
    }

    @Test func drawsWideContentWithoutDisturbingSiblings() {
        let view = HStack {
            ScrollView { Lines(count: 5) }.frame(width: 7, height: 2)
            Text("|")
        }
        #expect(scrolledLines(view, width: 12) == ["line 0┃|", "line 1│"])
    }

    // MARK: Anchors

    @Test func bottomAnchorStartsAtTheBottom() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden).defaultScrollAnchor(.bottom)
            .frame(height: 3)
        #expect(scrolled(view) == "line 7\nline 8\nline 9")
    }

    @Test func bottomAnchorPutsShortContentAtTheBottom() {
        let view = ScrollView { Lines(count: 2) }.defaultScrollAnchor(.bottom).frame(height: 4)
        #expect(scrolled(view) == "\n\nline 0\nline 1")
    }

    @Test func sizeChangesAnchorAloneKeepsShortContentAtTheTop() {
        let view = ScrollView { Lines(count: 2) }.defaultScrollAnchor(.bottom, for: .sizeChanges).frame(height: 4)
        #expect(scrolled(view) == "line 0\nline 1\n\n")
    }

    @Test func centerAnchorStartsInTheMiddle() {
        let view = ScrollView { Lines(count: 9) }.scrollIndicators(.hidden)
            .defaultScrollAnchor(.center, for: .initialOffset).frame(height: 3)
        #expect(scrolled(view) == "line 3\nline 4\nline 5")
    }
}

@MainActor
@Suite struct ScrollPositionTests {
    // MARK: Positions

    @Test func positionAtARow() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(ScrollPosition(y: 4))).frame(height: 3)
        #expect(scrolled(view) == "line 4\nline 5\nline 6")
    }

    @Test func rowPastTheEndIsClamped() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(ScrollPosition(y: 99))).frame(height: 3)
        #expect(scrolled(view) == "line 7\nline 8\nline 9")
    }

    @Test func positionAtTheBottomEdge() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(ScrollPosition(edge: .bottom))).frame(height: 3)
        #expect(scrolled(view) == "line 7\nline 8\nline 9")
    }

    @Test func scrollsJustEnoughToRevealAForEachElement() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(ScrollPosition(id: 8))).frame(height: 3)
        #expect(scrolled(view) == "line 6\nline 7\nline 8")
    }

    @Test func revealsAViewMarkedWithID() {
        let view = ScrollView {
            Lines(count: 5)
            Text("target").id("target")
            Lines(count: 5)
        }
        .scrollIndicators(.hidden)
        .scrollPosition(.constant(ScrollPosition(id: "target")))
        .frame(height: 2)
        #expect(scrolled(view) == "line 4\ntarget")
    }

    @Test func revealingAViewAboveScrollsUp() {
        var position = ScrollPosition(y: 6)
        position.scrollTo(id: 2)
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(position)).frame(height: 3)
        // A constant binding keeps the row the view settled on from the first layout: none.
        #expect(scrolled(view) == "line 0\nline 1\nline 2")
    }

    @Test func unknownIDLeavesThePosition() {
        let view = ScrollView { Lines(count: 10) }.scrollIndicators(.hidden)
            .scrollPosition(.constant(ScrollPosition(id: "missing"))).frame(height: 2)
        #expect(scrolled(view) == "line 0\nline 1")
    }

    @Test func tallViewShowsItsTop() {
        let view = ScrollView {
            Lines(count: 3)
            VStack {
                Text("a")
                Text("b")
                Text("c")
            }.id("tall")
        }
        .scrollIndicators(.hidden)
        .scrollPosition(.constant(ScrollPosition(id: "tall")))
        .frame(height: 2)
        #expect(scrolled(view) == "a\nb")
    }

    @Test func indicatorThumbFollowsTheOffset() {
        let view = ScrollView { Lines(count: 8) }.scrollPosition(.constant(ScrollPosition(edge: .bottom)))
            .frame(height: 4)
        #expect(scrolledLines(view).map { String($0.suffix(1)) } == ["│", "│", "┃", "┃"])
    }

    @Test func nestedScrollViewsDontShareTheBinding() {
        let view = ScrollView {
            ScrollView { Lines(count: 10) }.scrollIndicators(.hidden).frame(height: 2)
            Lines(count: 10)
        }
        .scrollIndicators(.hidden)
        .scrollPosition(.constant(ScrollPosition(y: 1)))
        .frame(height: 2)
        #expect(scrolled(view) == "line 1\nline 0")
    }

    // MARK: ScrollPosition values

    @Test func positionAccessors() {
        var position = ScrollPosition(idType: String.self)
        #expect(position.edge == nil && position.y == nil && position.viewID == nil)
        position.scrollTo(edge: .bottom)
        #expect(position.edge == .bottom)
        position.scrollTo(y: 3)
        #expect(position.y == 3 && position.edge == nil)
        position.scrollTo(id: "a")
        #expect(position.viewID(type: String.self) == "a")
        #expect(position.viewID(type: Int.self) == nil)
        position.scrollBy(lines: 2)
        position.scrollBy(lines: 1)
        #expect(position.delta == 3)
        #expect(!position.isPositionedByUser)
    }

    @Test func restingPositions() {
        #expect(ScrollPosition.resting(at: 0, maxOffset: 5, byUser: true).edge == .top)
        #expect(ScrollPosition.resting(at: 5, maxOffset: 5, byUser: true).edge == .bottom)
        let middle = ScrollPosition.resting(at: 2, maxOffset: 5, byUser: true)
        #expect(middle.y == 2 && middle.isPositionedByUser)
    }

    @Test func unitPoints() {
        #expect(UnitPoint.bottom.y == 1 && UnitPoint.top.y == 0 && UnitPoint.center == UnitPoint(x: 0.5, y: 0.5))
        let corners: [UnitPoint] = [
            .zero, .leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing,
        ]
        #expect(Set(corners).count == 6)
        #expect(Axis.Set.vertical.contains(.vertical) && !Axis.Set.vertical.contains(.horizontal))
    }

    @Test func changingTheIDResetsState() {
        // `.id` gives identity: a new id remounts the content, so its `onAppear` runs again.
        final class Counter { var appearances = 0 }
        let counter = Counter()
        struct Probe: View {
            let id: Int
            let counter: Counter
            var body: some View {
                Text("x").onAppear { counter.appearances += 1 }.id(id)
            }
        }
        let graph = ViewGraph()
        graph.mount(Probe(id: 1, counter: counter), environment: EnvironmentValues())
        graph.update(Probe(id: 1, counter: counter), environment: EnvironmentValues())
        #expect(counter.appearances == 1)
        graph.update(Probe(id: 2, counter: counter), environment: EnvironmentValues())
        #expect(counter.appearances == 2)
        graph.unmountAll()
    }
}
