import Testing

@testable import Stipple

/// A prompt that clears its input on submit and recalls the last entry on Up, like a shell.
private struct Prompt: View {
    let store: Store

    var body: some View {
        TextField("Message", text: store.binding(\.name)).focusable(autoFocus: true)
            .onSubmit {
                store.submitted.append(store.name)
                store.name = ""
            }
            .onKeyPress(.upArrow) {
                store.name = store.submitted.last.map { $0 + " again" } ?? ""
                return .handled
            }
    }
}

/// The binding changed by the app rather than by the field's own editing.
@MainActor
struct TextFieldOutsideChangeTests {
    @Test func clearingFromOutsidePutsTheCaretOnThePlaceholder() async {
        let store = Store()
        let (runtime, terminal) = makeRuntime(Prompt(store: store))
        runtime.handle(.input(Array("one\r".utf8)))
        await runtime.settle()
        #expect(store.submitted == ["one"])
        #expect(store.name.isEmpty)
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 0, y: 0))
        #expect(plain(terminal.output).contains("Message"))
        runtime.handle(.input(Array("x".utf8)))
        await runtime.settle()
        #expect(store.name == "x")
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 1, y: 0))
    }

    @Test func replacingFromOutsideMovesTheCaretToTheEnd() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Prompt(store: store))
        runtime.handle(.input(Array("hi\r".utf8)))
        runtime.handle(.input(Array("\u{1B}[A".utf8)))
        await runtime.settle()
        #expect(store.name == "hi again")
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 8, y: 0))
        runtime.handle(.input(Array("!".utf8)))
        await runtime.settle()
        #expect(store.name == "hi again!")
        // The field's own edits keep their insertion point.
        runtime.handle(.input(Array("\u{1B}[D\u{1B}[D?".utf8)))
        await runtime.settle()
        #expect(store.name == "hi agai?n!")
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 8, y: 0))
    }
}
