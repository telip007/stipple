import Testing

@testable import Stipple

@MainActor
struct LeadFollowUpTests {
    @Test func renderToStringSettlesGeometry() {
        let output = Stipple.renderToString(ProgressView(value: 0.5), width: 10)
        #expect(output.contains("█"))
    }

    @Test func focusStateSetFromHandlerMovesFocusWithoutBodyRead() async {
        struct Form: View {
            @FocusState private var focused = false
            @State private var text = ""
            var body: some View {
                VStack {
                    TextField("name", text: $text).focused($focused)
                    Text("value \(text)")
                }
                .onKeyPress("f") {
                    focused = true
                    return .handled
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Form())
        runtime.handle(.input(Array("f".utf8)))
        await runtime.settle()
        runtime.handle(.input(Array("x".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("value x"))
    }

    @Test func selectionListUsesEnvironmentSubmit() async {
        struct Item: Identifiable { let id: Int }
        struct Menu: View {
            @State private var selection: Int?
            @State private var submitted = 0
            var body: some View {
                VStack {
                    SelectionList([Item(id: 1), Item(id: 2)], selection: $selection) { Text("item \($0.id)") }
                    Text("submitted \(submitted)")
                }
                .onSubmit { submitted += 1 }
            }
        }
        let (runtime, terminal) = makeRuntime(Menu())
        runtime.handle(.input(Array("\u{1B}[B".utf8)))
        await runtime.settle()
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(terminal.output.contains("submitted 1"))
    }
}
