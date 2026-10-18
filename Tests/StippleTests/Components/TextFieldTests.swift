import Observation
import Testing

@testable import Stipple

/// The state the test views edit, observed so that changes redraw.
@Observable
@MainActor
final class Store {
    var name = ""
    var second = ""
    var password = ""
    var submitted: [String] = []

    func binding(_ key: ReferenceWritableKeyPath<Store, String>) -> Binding<String> {
        Binding(get: { self[keyPath: key] }, set: { self[keyPath: key] = $0 })
    }
}

/// A form with one auto-focused field, and a submit handler.
private struct Form: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: store.binding(\.name)).focusable(autoFocus: true)
            Text("name=\(store.name)")
        }
        .onSubmit { store.submitted.append(store.name) }
    }
}

/// Two fields; the first is not focusable, so Tab reaches only the second.
private struct Unfocused: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            TextField("First", text: store.binding(\.name)).focusable(false)
            TextField("Second", text: store.binding(\.second))
        }
    }
}

/// Focus driven by a `@FocusState`, and a key outside the field that moves it there.
private struct Bound: View {
    enum Field: Hashable { case name }
    @FocusState private var focus: Field?
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: store.binding(\.name)).focused($focus, equals: .name)
            // Reading the state in `body` is what rebuilds the view when focus is set.
            Text(focus == .name ? "focused" : "blurred")
        }
        .onKeyPress("f") {
            focus = .name
            return .handled
        }
    }
}

/// A secure field focused through a Boolean `@FocusState`.
private struct Secret: View {
    @FocusState private var isFocused = false
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            SecureField("Password", text: store.binding(\.password)).focused($isFocused)
            Text(isFocused ? "focused" : "blurred")
        }
        .onKeyPress("f") {
            isFocused = true
            return .handled
        }
    }
}

/// A field, and a global key (F10, which the field ignores) that clears the text from outside.
private struct External: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: store.binding(\.name)).focusable(autoFocus: true)
        }
        .onKeyPress(.function(10)) {
            store.name = ""
            return .handled
        }
    }
}

/// The plain text of a frame, with escape codes removed.
func plain(_ frame: String) -> String {
    frame.replacing(/\u{1B}\[[0-9;?]*[A-Za-z]/, with: "")
}

/// Every focus modifier on the two field types, so each overload runs.
private struct Modifiers: View {
    enum Field: Hashable { case name }
    @FocusState private var focus: Field?
    @FocusState private var isFocused = false
    let store: Store

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: store.binding(\.name)).focused($isFocused).focusable(true)
            TextField("Other", text: store.binding(\.second)).focused($focus, equals: .name)
            SecureField("Password", text: store.binding(\.password)).focusable(autoFocus: true)
            SecureField("Again", text: store.binding(\.password)).focused($focus, equals: .name)
                .focusable(false)
        }
        .onKeyPress("f") {
            isFocused = true
            return .handled
        }
    }
}

@MainActor
struct TextFieldTests {
    @Test func focusModifiersApplyToBothFieldTypes() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Modifiers(store: store))
        // The secure field asks for focus on mount, so typing reaches it.
        runtime.handle(.input(Array("s".utf8)))
        await runtime.settle()
        #expect(store.password == "s")
        #expect(runtime.graph.focus.focusedNode != nil)
    }

    @Test func typingInsertsAtTheCursor() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("hi".utf8)))
        await runtime.settle()
        #expect(store.name == "hi")
    }

    @Test func caretIsInverseAndTheTerminalCursorFollowsIt() async {
        let store = Store()
        let (runtime, terminal) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("ab".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("\u{1B}[7m"))
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 2, y: 0))
        runtime.handle(.input(Array("\u{1B}[D".utf8)))
        await runtime.settle()
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 1, y: 0))
    }

    @Test func returnCallsTheSubmitAction() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("ok".utf8)))
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(store.submitted == ["ok"])
    }

    @Test func editingKeysReachTheText() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("one two".utf8)))
        runtime.handle(.input([0x17]))
        runtime.handle(.input(Array("\u{1B}[H".utf8)))
        runtime.handle(.input(Array("> ".utf8)))
        await runtime.settle()
        #expect(store.name == "> one ")
    }

    @Test func pasteInsertsTheWholePaste() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("\u{1B}[200~pasted text\u{1B}[201~".utf8)))
        await runtime.settle()
        #expect(store.name == "pasted text")
    }

    @Test func optionBackspaceDeletesAWord() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("alpha beta".utf8)))
        runtime.handle(.input(Array("\u{1B}\u{7F}".utf8)))
        await runtime.settle()
        #expect(store.name == "alpha ")
    }

    @Test func controlKeysEditTheText() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("hello".utf8)))
        runtime.handle(.input([0x01]))
        runtime.handle(.input(Array(">".utf8)))
        runtime.handle(.input([0x05]))
        runtime.handle(.input([0x0B]))
        await runtime.settle()
        #expect(store.name == ">hello")
        runtime.handle(.input([0x15]))
        await runtime.settle()
        #expect(store.name.isEmpty)
    }

    @Test func externalChangeClampsTheCursor() async {
        let store = Store()
        let (runtime, _) = makeRuntime(External(store: store))
        runtime.handle(.input(Array("abc".utf8)))
        await runtime.settle()
        runtime.handle(.input(Array("\u{1B}[21~".utf8)))
        await runtime.settle()
        #expect(store.name.isEmpty)
        runtime.handle(.input(Array("z".utf8)))
        await runtime.settle()
        #expect(store.name == "z")
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 1, y: 0))
    }

    @Test func fieldIgnoresKeysWhenNotFocused() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Unfocused(store: store))
        runtime.handle(.input(Array("x".utf8)))
        await runtime.settle()
        #expect(store.name.isEmpty && store.second.isEmpty)
        runtime.handle(.input([0x09]))
        runtime.handle(.input(Array("y".utf8)))
        await runtime.settle()
        #expect(store.second == "y")
        #expect(store.name.isEmpty)
    }

    @Test func focusableFalseLeavesTheFieldOutOfTab() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Unfocused(store: store))
        runtime.handle(.input([0x09]))
        runtime.handle(.input(Array("q".utf8)))
        await runtime.settle()
        #expect(store.second == "q")
    }

    @Test func focusedFieldReceivesFocusFromAFocusState() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Bound(store: store))
        runtime.handle(.input(Array("a".utf8)))
        await runtime.settle()
        #expect(runtime.graph.focus.focusedNode == nil)
        runtime.handle(.input(Array("f".utf8)))
        await runtime.settle()
        runtime.handle(.input(Array("o".utf8)))
        await runtime.settle()
        #expect(runtime.graph.focus.focusedNode != nil)
        #expect(store.name == "o")
    }

    @Test func secureFieldFocusedByBooleanState() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Secret(store: store))
        runtime.handle(.input(Array("f".utf8)))
        await runtime.settle()
        runtime.handle(.input(Array("pw".utf8)))
        await runtime.settle()
        #expect(store.password == "pw")
    }

    @Test func wideCharactersTakeTwoColumns() async {
        let store = Store()
        let (runtime, _) = makeRuntime(Form(store: store))
        runtime.handle(.input(Array("漢字".utf8)))
        await runtime.settle()
        #expect(runtime.graph.cursorPosition == CursorPosition(x: 4, y: 0))
    }

    @Test func submitWithoutAnAncestorDoesNothing() async {
        let store = Store()
        let (runtime, _) = makeRuntime(TextField("Name", text: store.binding(\.name)).focusable(autoFocus: true))
        runtime.handle(.input([0x0D]))
        await runtime.settle()
        #expect(store.submitted.isEmpty)
        #expect(runtime.graph.focus.focusedNode != nil)
    }

    @Test func secureFieldMasksTheText() {
        let frame = Stipple.renderToString(SecureField("Password", text: .constant("pw1")), width: 20)
        #expect(plain(frame) == "***")
    }

    @Test func placeholderIsShownWhileEmpty() {
        let frame = Stipple.renderToString(TextField("Name", text: .constant("")), width: 20)
        #expect(plain(frame) == "Name")
    }

    @Test func textIsShownAndFitsTheProposedWidth() {
        let field = TextField("", text: .constant("abcdefghij")).frame(width: 4)
        #expect(plain(Stipple.renderToString(field, width: 20)) == "abcd")
    }
}
