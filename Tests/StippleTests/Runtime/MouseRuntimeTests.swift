import Testing

@testable import Stipple

private struct TwoFields: View {
    @State private var first = ""
    @State private var second = ""

    var body: some View {
        VStack {
            TextField("first", text: $first).focusable(autoFocus: true)
            TextField("second", text: $second)
            Text("first=\(first) second=\(second)")
        }
    }
}

private struct HoverProbe: View {
    @State private var inner = false
    @State private var outer = false
    @State private var watching = true

    var body: some View {
        VStack {
            if watching {
                VStack {
                    Text("target").onHover { inner = $0 }
                    Text("sibling")
                }
                .onHover { outer = $0 }
            }
            Text("inner=\(inner) outer=\(outer)")
        }
        .onKeyPress("x") {
            watching = false
            return .handled
        }
    }
}

private struct Picker: View {
    @State private var choice: Int?
    @State private var submitted: [Int] = []

    var body: some View {
        VStack {
            SelectionList(
                Array(1...3), id: \.self, selection: $choice, onSubmit: { submitted.append($0) },
                row: { Text("item \($0)") }
            )
            Text("choice=\(choice.map(String.init) ?? "-") submitted=\(submitted.map(String.init).joined())")
        }
    }
}

@MainActor
@Suite struct MouseRuntimeTests {
    private func frame(_ runtime: Runtime) -> [String] {
        let text = runtime.produceFrame().text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func send(_ runtime: Runtime, _ text: String) async {
        runtime.handle(.input(Array(text.utf8)))
        await runtime.settle()
    }

    private func click(_ runtime: Runtime, x: Int, y: Int) async {
        await send(runtime, "\u{1B}[<0;\(x);\(y)M\u{1B}[<0;\(x);\(y)m")
    }

    private func makeMouseRuntime(_ view: some View) -> (Runtime, FakeTerminal) {
        makeRuntime(view) {
            $0.alternateScreen = true
            $0.mouseReporting = true
        }
    }

    @Test func clickFocusesATextField() async {
        let (runtime, _) = makeMouseRuntime(TwoFields())
        _ = frame(runtime)
        await click(runtime, x: 1, y: 2)
        await send(runtime, "b")
        #expect(frame(runtime).last == "first= second=b")
        await click(runtime, x: 1, y: 1)
        await send(runtime, "a")
        #expect(frame(runtime).last == "first=a second=b")
    }

    @Test func clickOffTheAlternateScreenDoesNotFocus() async {
        let (runtime, _) = makeRuntime(TwoFields()) { $0.mouseReporting = true }
        await click(runtime, x: 1, y: 2)
        await send(runtime, "a")
        #expect(frame(runtime).last == "first=a second=")
    }

    @Test func clickSelectsAndDoubleClickSubmitsAListRow() async {
        let (runtime, _) = makeMouseRuntime(Picker())
        _ = frame(runtime)
        await click(runtime, x: 3, y: 2)
        #expect(frame(runtime).last == "choice=2 submitted=")
        await click(runtime, x: 3, y: 3)
        await click(runtime, x: 3, y: 3)
        #expect(frame(runtime).last == "choice=3 submitted=3")
    }

    @Test func hoverEntersAndLeaves() async {
        let (runtime, terminal) = makeMouseRuntime(HoverProbe())
        #expect(terminal.mouseMotion)
        await send(runtime, "\u{1B}[<35;2;1M")
        #expect(frame(runtime).contains("inner=true outer=true"))
        await send(runtime, "\u{1B}[<35;2;2M")
        #expect(frame(runtime).contains("inner=false outer=true"))
        await send(runtime, "\u{1B}[<35;2;3M")
        #expect(frame(runtime).contains("inner=false outer=false"))
        await send(runtime, "\u{1B}[<35;2;1M")
        #expect(frame(runtime).contains("inner=true outer=true"))
        // Without hover handlers left, motion reports are switched off again.
        await send(runtime, "x")
        #expect(!terminal.mouseMotion)
        #expect(terminal.mouseReporting)
    }

    @Test func noMotionReportsWithoutHoverHandlers() {
        let (_, terminal) = makeMouseRuntime(TwoFields())
        #expect(!terminal.mouseMotion)
        let (_, plain) = makeRuntime(HoverProbe()) { $0.alternateScreen = true }
        #expect(!plain.mouseMotion)
    }
}
