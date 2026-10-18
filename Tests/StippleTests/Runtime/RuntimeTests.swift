import Testing

@testable import Stipple

private struct Counter: View {
    @State private var count = 0
    @Environment(\.exit) private var exit

    var body: some View {
        Text("Count: \(count)")
            .onKeyPress(.upArrow) {
                count += 1
                return .handled
            }
            .onKeyPress("q") {
                exit()
                return .handled
            }
    }
}

@MainActor
struct RuntimeTests {
    @Test func rendersInitialFrame() {
        let (_, terminal) = makeRuntime(Counter())
        #expect(terminal.output.contains("Count: 0"))
        #expect(terminal.rawMode)
        #expect(terminal.bracketedPaste)
    }

    @Test func keyPressUpdatesState() async {
        let (runtime, terminal) = makeRuntime(Counter())
        runtime.handle(.input(Array("\u{1B}[A".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("Count: 1"))
    }

    @Test func exitRestoresTerminal() async throws {
        let (runtime, terminal) = makeRuntime(Counter())
        runtime.handle(.input(Array("q".utf8)))
        try await runtime.waitUntilExit()
        #expect(terminal.restored)
    }

    @Test func ctrlCExits() async throws {
        let (runtime, terminal) = makeRuntime(Counter())
        runtime.handle(.input([0x03]))
        try await runtime.waitUntilExit()
        #expect(terminal.restored)
    }

    @Test func exitThrowing() async {
        struct Boom: Error {}
        struct Failing: View {
            @Environment(\.exit) private var exit
            var body: some View {
                Text("x").onAppear { exit(throwing: Boom()) }
            }
        }
        let (runtime, _) = makeRuntime(Failing())
        await #expect(throws: Boom.self) { try await runtime.waitUntilExit() }
    }

    @Test func staticOutputIsWrittenOnce() async {
        struct Log: View {
            @State private var lines = ["one"]
            var body: some View {
                VStack {
                    Static(lines) { Text($0) }
                    Text("live \(lines.count)")
                }
                .onKeyPress(.return) {
                    lines.append("line \(lines.count + 1)")
                    return .handled
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Log())
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(terminal.output.ranges(of: "one").count == 1)
        #expect(terminal.output.contains("line 2"))
        #expect(terminal.output.contains("live 2"))
    }

    @Test func pasteGoesToHandler() async {
        struct Paste: View {
            @State private var pasted = ""
            var body: some View {
                Text("pasted: \(pasted)").onPaste { pasted = $0 }
            }
        }
        let (runtime, terminal) = makeRuntime(Paste())
        runtime.handle(.input(Array("\u{1B}[200~hello\u{1B}[201~".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("pasted: hello"))
    }

    @Test func nonInteractiveWritesOnlyFinalFrame() async throws {
        let (runtime, terminal) = makeRuntime(Counter()) { $0.interactive = false }
        #expect(!terminal.output.contains("Count"))
        runtime.exit(with: nil)
        try await runtime.waitUntilExit()
        #expect(terminal.output.contains("Count: 0"))
        #expect(!terminal.output.contains("\u{1B}["))
    }
}
