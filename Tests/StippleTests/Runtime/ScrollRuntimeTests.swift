import Testing

@testable import Stipple

/// A chat-like transcript: `a` appends a line, and the scroll position is
/// shown under the transcript.
private struct Transcript: View {
    @State private var count: Int
    @State private var position = ScrollPosition()
    let height: Int
    let showPosition: Bool

    init(count: Int, height: Int = 3, showPosition: Bool = false) {
        _count = State(initialValue: count)
        self.height = height
        self.showPosition = showPosition
    }

    var body: some View {
        VStack {
            ScrollView {
                ForEach(0..<count) { Text("line \($0)") }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .scrollPosition($position)
            .frame(height: height)
            if showPosition {
                Text("edge: \(position.edge.map { "\($0)" } ?? "-") user: \(position.isPositionedByUser)")
            }
        }
        .onKeyPress("a") {
            count += 1
            return .handled
        }
        .onKeyPress("b") {
            position.scrollTo(edge: .bottom)
            return .handled
        }
        .onKeyPress("u") {
            position.scrollBy(lines: -2)
            return .handled
        }
        .onKeyPress("i") {
            position.scrollTo(id: 1)
            return .handled
        }
    }
}

/// A focusable scroll view above a text field.
private struct Workspace: View {
    @State private var text = ""
    var pageKeys = false

    var body: some View {
        VStack {
            ScrollView { ForEach(0..<20) { Text("row \($0)") } }
                .scrollIndicators(.hidden)
                .scrollOnPageKeys(pageKeys)
                .frame(height: 3)
            TextField("type", text: $text).focusable(autoFocus: true)
        }
    }
}

@MainActor
@Suite struct ScrollRuntimeTests {
    private func frame(_ runtime: Runtime) -> [String] {
        let text = runtime.produceFrame().text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func send(_ runtime: Runtime, _ text: String) async {
        runtime.handle(.input(Array(text.utf8)))
        await runtime.settle()
    }

    private func wheel(_ runtime: Runtime, up: Bool, x: Int = 1, y: Int = 1) async {
        await send(runtime, "\u{1B}[<\(up ? 64 : 65);\(x);\(y)M")
    }

    // MARK: Pinning

    @Test func staysPinnedToTheBottomWhileContentGrows() async {
        let (runtime, _) = makeRuntime(Transcript(count: 5))
        #expect(frame(runtime) == ["line 2", "line 3", "line 4"])
        await send(runtime, "aa")
        #expect(frame(runtime) == ["line 4", "line 5", "line 6"])
    }

    @Test func scrollingAwayUnpinsAndScrollingBackPinsAgain() async {
        let (runtime, terminal) = makeRuntime(Transcript(count: 8, showPosition: true)) {
            $0.mouseReporting = true
        }
        #expect(terminal.mouseReporting)
        await wheel(runtime, up: true)
        #expect(frame(runtime) == ["line 2", "line 3", "line 4", "edge: - user: true"])
        await send(runtime, "a")
        #expect(frame(runtime).first == "line 2")
        await wheel(runtime, up: false)
        #expect(frame(runtime) == ["line 5", "line 6", "line 7", "edge: - user: true"])
        await wheel(runtime, up: false)
        #expect(frame(runtime) == ["line 6", "line 7", "line 8", "edge: bottom user: true"])
        await send(runtime, "a")
        #expect(frame(runtime) == ["line 7", "line 8", "line 9", "edge: bottom user: true"])
    }

    @Test func wheelToTheTopReportsTheTopEdge() async {
        let (runtime, _) = makeRuntime(Transcript(count: 6, showPosition: true)) { $0.mouseReporting = true }
        await wheel(runtime, up: true)
        #expect(frame(runtime) == ["line 0", "line 1", "line 2", "edge: top user: true"])
        // Already at the top: nothing changes.
        await wheel(runtime, up: true)
        #expect(frame(runtime).first == "line 0")
    }

    @Test func appScrollsWithThePosition() async {
        let (runtime, _) = makeRuntime(Transcript(count: 10, showPosition: true)) { $0.mouseReporting = true }
        await send(runtime, "u")
        #expect(frame(runtime) == ["line 5", "line 6", "line 7", "edge: - user: false"])
        await send(runtime, "i")
        #expect(frame(runtime).first == "line 1")
        await send(runtime, "b")
        #expect(frame(runtime) == ["line 7", "line 8", "line 9", "edge: bottom user: false"])
    }

    @Test func positionChangesRedrawWithoutABodyReadingThem() async {
        let (runtime, _) = makeRuntime(Transcript(count: 10))
        await send(runtime, "u")
        #expect(frame(runtime) == ["line 5", "line 6", "line 7"])
    }

    // MARK: Keyboard

    @Test func focusedScrollViewTakesPagingKeys() async {
        let view = ScrollView { ForEach(0..<20) { Text("row \($0)") } }
            .scrollIndicators(.hidden)
            .frame(height: 3)
            .focusable(autoFocus: true)
        let (runtime, _) = makeRuntime(view)
        await send(runtime, "\u{1B}[6~")
        #expect(frame(runtime).first == "row 2")
        await send(runtime, "\u{1B}[B")
        #expect(frame(runtime).first == "row 3")
        await send(runtime, "\u{1B}[F")
        #expect(frame(runtime).first == "row 17")
        await send(runtime, "\u{1B}[5~")
        #expect(frame(runtime).first == "row 15")
        await send(runtime, "\u{1B}[A")
        #expect(frame(runtime).first == "row 14")
        await send(runtime, "\u{1B}[H")
        #expect(frame(runtime).first == "row 0")
        // Modified keys and releases are left alone.
        await send(runtime, "\u{1B}[1;5B")
        #expect(frame(runtime).first == "row 0")
    }

    @Test func arrowKeysStayWithAFocusedTextField() async {
        let (runtime, _) = makeRuntime(Workspace())
        await send(runtime, "\u{1B}[B\u{1B}[F\u{1B}[6~")
        #expect(frame(runtime).first == "row 0")
    }

    @Test func pageKeysReachTheScrollViewWhenEnabled() async {
        let (runtime, _) = makeRuntime(Workspace(pageKeys: true))
        await send(runtime, "\u{1B}[6~")
        #expect(frame(runtime).first == "row 2")
        // Arrows and Home/End still belong to the field.
        await send(runtime, "\u{1B}[B\u{1B}[H")
        #expect(frame(runtime).first == "row 2")
        await send(runtime, "x")
        #expect(frame(runtime).last?.contains("x") == true)
    }

    @Test func focusInsideTheScrollViewScrollsIt() async {
        let view = ScrollView {
            Text("field").focusable(autoFocus: true)
            ForEach(0..<20) { Text("row \($0)") }
        }
        .scrollIndicators(.hidden)
        .frame(height: 3)
        let (runtime, _) = makeRuntime(view)
        await send(runtime, "\u{1B}[6~")
        #expect(frame(runtime).first == "row 1")
    }

    @Test func disabledScrollViewDoesNotScroll() async {
        let view = ScrollView { ForEach(0..<20) { Text("row \($0)") } }
            .scrollIndicators(.hidden)
            .frame(height: 3)
            .scrollOnPageKeys()
            .disabled()
        let (runtime, _) = makeRuntime(view)
        await send(runtime, "\u{1B}[6~")
        #expect(frame(runtime).first == "row 0")
    }

    // MARK: Mouse

    @Test func wheelScrollsTheScrollViewUnderThePointer() async {
        let view = HStack {
            ScrollView { ForEach(0..<20) { Text("left \($0)") } }.scrollIndicators(.hidden).frame(width: 10)
            ScrollView { ForEach(0..<20) { Text("right \($0)") } }.scrollIndicators(.hidden)
        }
        let (runtime, terminal) = makeRuntime(view) {
            $0.alternateScreen = true
            $0.mouseReporting = true
        }
        terminal.size = Size(width: 30, height: 4)
        _ = frame(runtime)
        await wheel(runtime, up: false, x: 15, y: 2)
        #expect(frame(runtime).first == "left 0    right 3")
        await wheel(runtime, up: false, x: 2, y: 2)
        #expect(frame(runtime).first == "left 3    right 3")
        // Horizontal wheel notches don't scroll.
        await send(runtime, "\u{1B}[<66;2;2M")
        #expect(frame(runtime).first == "left 3    right 3")
    }

    @Test func wheelFallsBackToTheOuterScrollView() async {
        let view = ScrollView {
            ScrollView { Text("inner") }.frame(height: 1)
            ForEach(0..<20) { Text("row \($0)") }
        }
        .scrollIndicators(.hidden)
        let (runtime, terminal) = makeRuntime(view) {
            $0.alternateScreen = true
            $0.mouseReporting = true
        }
        terminal.size = Size(width: 20, height: 3)
        _ = frame(runtime)
        await wheel(runtime, up: false, x: 1, y: 1)
        #expect(frame(runtime) == ["row 2", "row 3", "row 4"])
    }

    @Test func inlineWheelScrollsTheInnermostScrollView() async {
        let (runtime, _) = makeRuntime(Transcript(count: 10)) { $0.mouseReporting = true }
        await wheel(runtime, up: true, x: 1, y: 40)
        #expect(frame(runtime).first == "line 4")
    }

    @Test func tapGestureCountsClicks() async {
        struct Tapper: View {
            @State private var taps = 0
            @State private var doubles = 0
            var body: some View {
                VStack {
                    Text("taps \(taps) doubles \(doubles)")
                        .onTapGesture { taps += 1 }
                        .onTapGesture(count: 2) { doubles += 1 }
                    Text("elsewhere")
                }
            }
        }
        let (runtime, _) = makeRuntime(Tapper()) {
            $0.alternateScreen = true
            $0.mouseReporting = true
        }
        _ = frame(runtime)
        await send(runtime, "\u{1B}[<0;2;1M\u{1B}[<0;2;1m")
        #expect(frame(runtime).first == "taps 1 doubles 0")
        await send(runtime, "\u{1B}[<0;2;1M\u{1B}[<0;2;1m")
        #expect(frame(runtime).first == "taps 2 doubles 1")
        // A press that ends on another view is no tap; nor is a right click.
        await send(runtime, "\u{1B}[<0;2;1M\u{1B}[<0;2;2m\u{1B}[<2;2;1M\u{1B}[<2;2;1m")
        // A click on a view without a handler does nothing.
        await send(runtime, "\u{1B}[<0;2;2M\u{1B}[<0;2;2m")
        #expect(frame(runtime).first == "taps 2 doubles 1")
    }

    @Test func tapsNeedTheAlternateScreen() async {
        struct Tapper: View {
            @State private var taps = 0
            var body: some View {
                Text("taps \(taps)").onTapGesture { taps += 1 }
            }
        }
        let (runtime, _) = makeRuntime(Tapper()) { $0.mouseReporting = true }
        await send(runtime, "\u{1B}[<0;1;1M\u{1B}[<0;1;1m")
        #expect(frame(runtime).first == "taps 0")
    }

    @Test func mouseReportingIsOffByDefault() {
        let (_, terminal) = makeRuntime(Text("x"))
        #expect(!terminal.mouseReporting)
    }
}
