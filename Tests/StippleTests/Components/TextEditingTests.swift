import Testing

@testable import Stipple

@Test func insertsAtTheCursor() {
    var editing = TextEditing(text: "ac", cursor: 1)
    editing.apply(.insert("b"))
    #expect(editing.text == "abc")
    #expect(editing.cursor == 2)
}

@Test func insertsMultipleCharactersAndPastes() {
    var editing = TextEditing(text: "", cursor: 0)
    editing.apply(.insert("hello world"))
    #expect(editing.text == "hello world")
    #expect(editing.cursor == 11)
}

@Test func cursorCountsGraphemeClusters() {
    var editing = TextEditing(text: "👍🏽x", cursor: 0)
    editing.apply(.moveRight)
    #expect(editing.cursor == 1)
    editing.apply(.deleteBackward)
    #expect(editing.text == "x")
    #expect(editing.cursor == 0)
}

@Test func backspaceAndDeleteAtBoundariesDoNothing() {
    var editing = TextEditing(text: "ab", cursor: 0)
    editing.apply(.deleteBackward)
    #expect(editing.text == "ab")
    editing.apply(.moveToEnd)
    editing.apply(.deleteForward)
    #expect(editing.text == "ab")
    #expect(editing.cursor == 2)
}

@Test func backspaceAndDeleteRemoveOneCharacter() {
    var editing = TextEditing(text: "abc", cursor: 2)
    editing.apply(.deleteBackward)
    #expect(editing.text == "ac")
    #expect(editing.cursor == 1)
    editing.apply(.deleteForward)
    #expect(editing.text == "a")
    #expect(editing.cursor == 1)
}

@Test func movesWithinBounds() {
    var editing = TextEditing(text: "ab", cursor: 0)
    editing.apply(.moveLeft)
    #expect(editing.cursor == 0)
    editing.apply(.moveRight)
    editing.apply(.moveRight)
    editing.apply(.moveRight)
    #expect(editing.cursor == 2)
    editing.apply(.moveToStart)
    #expect(editing.cursor == 0)
    editing.apply(.moveToEnd)
    #expect(editing.cursor == 2)
}

@Test func deletesToStartAndEnd() {
    var editing = TextEditing(text: "hello world", cursor: 5)
    editing.apply(.deleteToEnd)
    #expect(editing.text == "hello")
    #expect(editing.cursor == 5)
    var other = TextEditing(text: "hello world", cursor: 6)
    other.apply(.deleteToStart)
    #expect(other.text == "world")
    #expect(other.cursor == 0)
}

@Test func wordMovesSkipSpacesThenWords() {
    var editing = TextEditing(text: "one  two three", cursor: 14)
    editing.apply(.wordLeft)
    #expect(editing.cursor == 9)
    editing.apply(.wordLeft)
    #expect(editing.cursor == 5)
    editing.apply(.wordLeft)
    #expect(editing.cursor == 0)
    editing.apply(.wordLeft)
    #expect(editing.cursor == 0)
    editing.apply(.wordRight)
    #expect(editing.cursor == 3)
    editing.apply(.wordRight)
    #expect(editing.cursor == 8)
    editing.apply(.wordRight)
    #expect(editing.cursor == 14)
    editing.apply(.wordRight)
    #expect(editing.cursor == 14)
}

@Test func deletesPreviousWord() {
    var editing = TextEditing(text: "one two  ", cursor: 9)
    editing.apply(.deleteWordBackward)
    #expect(editing.text == "one ")
    #expect(editing.cursor == 4)
    editing.apply(.deleteWordBackward)
    #expect(editing.text.isEmpty)
    #expect(editing.cursor == 0)
}

@Test func cursorIsClampedIntoTheText() {
    #expect(TextEditing(text: "ab", cursor: 99).cursor == 2)
    #expect(TextEditing(text: "ab", cursor: -4).cursor == 0)
}

@Test func submitChangesNothing() {
    var editing = TextEditing(text: "ab", cursor: 1)
    editing.apply(.submit)
    #expect(editing == TextEditing(text: "ab", cursor: 1))
}
