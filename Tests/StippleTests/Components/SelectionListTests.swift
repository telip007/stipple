import Testing

@testable import Stipple

private struct Fruit: Identifiable, Hashable {
    let id: Int
    let name: String
}

private let fruits = [
    Fruit(id: 1, name: "Apple"),
    Fruit(id: 2, name: "Banana"),
    Fruit(id: 3, name: "Cherry"),
    Fruit(id: 4, name: "Date"),
]

/// A list that reports its selection and every submitted choice as text.
private struct Picker: View {
    @State private var choice: Int?
    @State private var submitted: [String] = []
    var visibleRows: Int?

    var body: some View {
        VStack(alignment: .leading) {
            SelectionList(
                fruits,
                id: \.id,
                selection: $choice,
                visibleRows: visibleRows,
                onSubmit: { fruit in submitted.append(fruit.name) },
                row: { fruit in Text(fruit.name) }
            )
            Text("selected: \(choice.map(String.init) ?? "none")")
            Text("submitted: \(submitted.joined(separator: ","))")
        }
    }
}

@MainActor
@Suite struct SelectionListTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    private func keys(_ text: String) -> TerminalEvent {
        .input(Array(text.utf8))
    }

    // MARK: Rendering

    @Test func marksTheSelectedRow() {
        let list = SelectionList(fruits, id: \.id, selection: .constant(2)) { Text($0.name) }
        #expect(plain(list) == "  Apple\n› Banana\n  Cherry\n  Date")
    }

    @Test func showsNoMarkerWithoutSelection() {
        let list = SelectionList(fruits, id: \.id, selection: .constant(nil)) { Text($0.name) }
        #expect(!plain(list).contains("›"))
    }

    @Test func identifiableElementsNeedNoKeyPath() {
        let list = SelectionList(fruits, selection: .constant(4)) { Text($0.name) }
        #expect(plain(list) == "  Apple\n  Banana\n  Cherry\n› Date")
    }

    @Test func visibleRowsScrollToTheSelection() {
        let list = SelectionList(fruits, id: \.id, selection: .constant(4), visibleRows: 2) { Text($0.name) }
        #expect(plain(list) == "  Cherry\n› Date")
    }

    @Test func emptyDataRendersNothing() {
        let list = SelectionList([Fruit](), id: \.id, selection: .constant(nil)) { Text($0.name) }
        #expect(plain(list).isEmpty)
    }

    @Test func scrollingKeepsTheSelectionInsideTheWindow() {
        typealias List = SelectionList<[Fruit], Int, Text>
        // Already visible: the offset stays.
        #expect(List.scrolledStart(offset: 1, selected: 2, count: 4, limit: 2) == 1)
        // Above the window: it moves up to the selection.
        #expect(List.scrolledStart(offset: 2, selected: 0, count: 4, limit: 2) == 0)
        // Below the window: the selection becomes the last row.
        #expect(List.scrolledStart(offset: 0, selected: 3, count: 4, limit: 2) == 2)
        // A stale offset past the end is pulled back.
        #expect(List.scrolledStart(offset: 9, selected: nil, count: 4, limit: 3) == 1)
        #expect(List.scrolledStart(offset: -2, selected: nil, count: 4, limit: 3) == 0)
    }

    // MARK: Keyboard

    @Test func downArrowSelectsTheFirstRowThenMovesDown() async {
        let (runtime, terminal) = makeRuntime(Picker())
        #expect(terminal.output.contains("selected: none"))
        runtime.handle(keys("\u{1B}[B"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 1"))
        runtime.handle(keys("j"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 2"))
    }

    @Test func upArrowAndKeyMoveBackAndClampAtTheTop() async {
        let (runtime, terminal) = makeRuntime(Picker())
        runtime.handle(keys("\u{1B}[A"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 4"))
        runtime.handle(keys("k"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 3"))
        runtime.handle(keys("\u{1B}[H"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 1"))
        runtime.handle(keys("\u{1B}[A"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 1"))
    }

    @Test func endJumpsToTheLastRowAndClampsThere() async {
        let (runtime, terminal) = makeRuntime(Picker())
        runtime.handle(keys("\u{1B}[F"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 4"))
        runtime.handle(keys("\u{1B}[B"))
        await runtime.settle()
        #expect(terminal.output.contains("selected: 4"))
    }

    @Test func enterSubmitsTheSelectedElementOnly() async {
        let (runtime, terminal) = makeRuntime(Picker())
        runtime.handle(keys("\r"))
        await runtime.settle()
        #expect(!terminal.output.contains("submitted: Apple"))
        runtime.handle(keys("j"))
        runtime.handle(keys("j"))
        runtime.handle(keys("\r"))
        await runtime.settle()
        #expect(terminal.output.contains("submitted: Banana"))
    }

    @Test func rowsScrollWhenTheSelectionLeavesTheWindow() async {
        let (runtime, terminal) = makeRuntime(Picker(visibleRows: 2))
        #expect(!terminal.output.contains("Date"))
        runtime.handle(keys("\u{1B}[F"))
        await runtime.settle()
        #expect(terminal.output.contains("Date"))
    }
}
