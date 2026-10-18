import Testing

@testable import Stipple

@MainActor
final class Recorder {
    var events: [String] = []
}

@MainActor
struct LifecycleTests {
    @Test func appearDisappearAndChange() async {
        struct Child: View {
            let recorder: Recorder
            var body: some View {
                Text("child")
                    .onAppear { recorder.events.append("appear") }
                    .onDisappear { recorder.events.append("disappear") }
            }
        }
        struct Parent: View {
            let recorder: Recorder
            @State private var show = true
            @State private var count = 0
            var body: some View {
                VStack {
                    if show { Child(recorder: recorder) }
                    Text("count \(count)")
                }
                .onChange(of: count) { old, new in recorder.events.append("change \(old)->\(new)") }
                .onChange(of: show, initial: true) { recorder.events.append("show") }
                .onKeyPress("h") {
                    show = false
                    return .handled
                }
                .onKeyPress("c") {
                    count += 1
                    return .handled
                }
            }
        }
        let recorder = Recorder()
        let (runtime, _) = makeRuntime(Parent(recorder: recorder))
        runtime.handle(.input(Array("c".utf8)))
        await runtime.settle()
        runtime.handle(.input(Array("h".utf8)))
        await runtime.settle()
        #expect(recorder.events == ["appear", "show", "change 0->1", "disappear", "show"])
    }

    @Test func taskRunsAndIsCancelledOnExit() async throws {
        struct Ticker: View {
            @State private var ticks = 0
            @Environment(\.exit) private var exit
            var body: some View {
                Text("ticks \(ticks)").task {
                    ticks += 1
                    if ticks == 1 { exit() }
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Ticker())
        try await runtime.waitUntilExit()
        #expect(terminal.output.contains("ticks 1"))
    }

    @Test func taskIDRestarts() async {
        struct Restart: View {
            let recorder: Recorder
            @State private var id = 0
            var body: some View {
                Text("id \(id)")
                    .task(id: id) { recorder.events.append("task \(id)") }
                    .onKeyPress("n") {
                        id += 1
                        return .handled
                    }
            }
        }
        let recorder = Recorder()
        let (runtime, _) = makeRuntime(Restart(recorder: recorder))
        await runtime.settle()
        runtime.handle(.input(Array("n".utf8)))
        await runtime.settle()
        #expect(recorder.events == ["task 0", "task 1"])
    }

    @Test func timelineViewTicks() async throws {
        let view = TimelineView(.periodic(every: .milliseconds(5))) { context in
            Text("frame \(context.frame) \(context.elapsed > .zero)")
        }
        let (runtime, terminal) = makeRuntime(view)
        await runtime.waitUntil { terminal.output.contains("true") }
        #expect(terminal.output.contains("frame 0 false"))
        #expect(terminal.output.contains("true"))
    }

    @Test func geometryReaderAndGeometryChange() async {
        struct Measured: View {
            @State private var width = 0
            var body: some View {
                VStack {
                    GeometryReader { proxy in Text("reader \(proxy.size.width)") }
                    Text("width \(width)")
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: Int.self, of: \.size.width) { width = $0 }
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Measured())
        await runtime.settle()
        #expect(terminal.output.contains("reader 40"))
        #expect(terminal.output.contains("width 40"))
    }

    @Test func cursorPositionIsReported() {
        let (runtime, _) = makeRuntime(
            VStack {
                Text("a")
                Text("bc").cursorPosition(Point(x: 1, y: 0))
            })
        #expect(runtime.produceFrame().cursor == CursorPosition(x: 1, y: 1))
    }

    @Test func environmentActionsFromRuntime() async {
        struct Actions: View {
            @Environment(\.terminal) private var terminal
            @Environment(\.focusManager) private var focusManager
            @Environment(\.terminalSize) private var size
            @Environment(\.isScreenReaderEnabled) private var screenReader
            var body: some View {
                VStack {
                    Text("size \(size.width)x\(size.height) \(screenReader)")
                    Text("a").focusable()
                    Text("b").focusable(autoFocus: true)
                }
                .onKeyPress("w") {
                    terminal.write("above\n")
                    terminal.writeError("err\n")
                    focusManager.focusNext()
                    focusManager.focusPrevious()
                    focusManager.blur()
                    focusManager.setEnabled(false)
                    return .handled
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Actions())
        #expect(terminal.output.contains("size 40x10 false"))
        #expect(runtime.graph.focus.focusedNode != nil)
        runtime.handle(.input(Array("w".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("above"))
        #expect(terminal.errorOutput == "err\n")
        #expect(runtime.graph.focus.focusedNode == nil)
        #expect(!runtime.graph.focus.isEnabled)
    }

    @Test func defaultEnvironmentActionsAreInert() {
        let values = EnvironmentValues()
        values.exit()
        values.terminal.write("x")
        values.focusManager.focusNext()
        #expect(values.terminalSize == Size(width: 80, height: 24))
    }
}
