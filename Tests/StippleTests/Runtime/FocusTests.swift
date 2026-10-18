import Testing

@testable import Stipple

private struct Fields: View {
    enum Field: Hashable { case first, second }
    @FocusState private var focus: Field?
    @State private var log: [String] = []

    var body: some View {
        VStack {
            Text(focus == .first ? "> first" : "  first")
                .focused($focus, equals: .first)
                .onKeyPress(.return) {
                    log.append("first")
                    return .handled
                }
            Text(focus == .second ? "> second" : "  second")
                .focused($focus, equals: .second)
                .onKeyPress(.return) {
                    log.append("second")
                    return .handled
                }
            Text("log: \(log.joined(separator: ","))")
        }
    }
}

@MainActor
struct FocusTests {
    @Test func tabCyclesFocusAndScopesHandlers() async {
        let (runtime, terminal) = makeRuntime(Fields())
        runtime.handle(.input([0x09]))
        await runtime.settle()
        #expect(terminal.output.contains("> first"))
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(terminal.output.contains("log: first"))
        runtime.handle(.input([0x09]))
        await runtime.settle()
        #expect(terminal.output.contains("> second"))
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(terminal.output.contains("log: first,second"))
    }

    @Test func shiftTabGoesBackAndEscapeBlurs() async throws {
        let (runtime, terminal) = makeRuntime(Fields())
        runtime.handle(.input(Array("\u{1B}[Z".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("> second"))
        // A lone ESC is only a key once the escape timeout passes without more bytes.
        runtime.handle(.input([0x1B]))
        try await Task.sleep(for: .milliseconds(120))
        await runtime.settle()
        #expect(runtime.graph.focus.focusedNode == nil)
    }
}
