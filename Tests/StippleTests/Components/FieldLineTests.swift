import Testing

@testable import Stipple

@Test func placeholderShownWhileEmpty() {
    let line = FieldLine(text: "", placeholder: "Name", isSecure: false, cursor: 0)
    #expect(line.isPlaceholder)
    #expect(line.cells.map(\.text).joined() == "Name")
}

@Test func secureFieldMasksEachCharacter() {
    let line = FieldLine(text: "pa👍🏽", placeholder: "", isSecure: true, cursor: 0)
    #expect(line.cells.map(\.text) == ["*", "*", "*"])
    #expect(!line.isPlaceholder)
}

@Test func cellsCarryColumnsAndWideWidths() {
    let cells = FieldCell.cells(of: "a漢b")
    #expect(
        cells == [
            FieldCell(text: "a", column: 0, width: 1),
            FieldCell(text: "漢", column: 1, width: 2),
            FieldCell(text: "b", column: 3, width: 1),
        ])
}

@Test func windowShowsWholeTextWhenItFits() {
    let line = FieldLine(text: "abc", placeholder: "", isSecure: false, cursor: 1)
    let window = line.window(width: 10)
    #expect(window.before.map(\.text) == ["a"])
    #expect(window.current?.text == "b")
    #expect(window.after.map(\.text) == ["c"])
    #expect(window.caretColumn == 1)
}

@Test func caretPastTheEndHasNoCurrentCell() {
    let line = FieldLine(text: "abc", placeholder: "", isSecure: false, cursor: 3)
    let window = line.window(width: 10)
    #expect(window.current == nil)
    #expect(window.caretColumn == 3)
}

@Test func windowScrollsToKeepTheCaretVisible() {
    let line = FieldLine(text: "abcdefghij", placeholder: "", isSecure: false, cursor: 10)
    let window = line.window(width: 4)
    #expect(window.before.map(\.text) == ["h", "i", "j"])
    #expect(window.current == nil)
    #expect(window.caretColumn == 3)
}

@Test func windowScrollsBackWhenCaretMovesLeft() {
    let line = FieldLine(text: "abcdefghij", placeholder: "", isSecure: false, cursor: 2)
    let window = line.window(width: 4)
    #expect(window.before.map(\.text) == ["a", "b"])
    #expect(window.current?.text == "c")
    #expect(window.caretColumn == 2)
}

@Test func windowHandlesZeroWidth() {
    let line = FieldLine(text: "abc", placeholder: "", isSecure: false, cursor: 1)
    let window = line.window(width: 0)
    #expect(window.before.isEmpty)
    #expect(window.current == nil)
    #expect(window.after.isEmpty)
    #expect(window.caretColumn == 0)
}

@Test func lineClampsCursorToCellCount() {
    #expect(FieldLine(text: "ab", placeholder: "", isSecure: false, cursor: 9).cursor == 2)
    #expect(FieldLine(text: "ab", placeholder: "", isSecure: false, cursor: -1).cursor == 0)
}
