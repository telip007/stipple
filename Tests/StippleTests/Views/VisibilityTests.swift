import Testing

@testable import Stipple

@MainActor
struct VisibilityTests {
    private func plain(_ view: some View, width: Int = 6) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func dividers() {
        #expect(
            plain(
                VStack {
                    Text("a")
                    Divider()
                    Text("b")
                }) == "a\n──────\nb")
        #expect(
            plain(
                HStack {
                    Text("a")
                    Divider()
                    Text("b")
                }) == "a│b")
        #expect(plain(Divider().foregroundStyle(.gray)) == "──────")
    }

    @Test func hiddenKeepsSpace() {
        #expect(
            plain(
                HStack {
                    Text("ab").hidden()
                    Text("c")
                }) == "  c")
    }

    @Test func disabledBlocksKeysPasteAndFocus() async {
        struct App: View {
            @State private var log = ""
            var body: some View {
                VStack {
                    Text("log \(log)")
                    Text("field").focusable(autoFocus: true)
                }
                .onKeyPress { _ in
                    log += "k"
                    return .handled
                }
                .onPaste { log += $0 }
                .disabled()
            }
        }
        let (runtime, terminal) = makeRuntime(App())
        runtime.handle(.input(Array("x\u{1B}[200~p\u{1B}[201~".utf8)))
        await runtime.settle()
        #expect(!terminal.output.contains("log k"))
        #expect(!terminal.output.contains("log p"))
        #expect(runtime.graph.focus.focusedNode == nil)
    }
}
