import Testing

@testable import Stipple

@Suite struct CanvasTests {
    private func canvas(_ width: Int, _ height: Int = 1) -> Canvas {
        Canvas(width: width, height: height)
    }

    // MARK: basics

    @Test func newCanvasIsBlank() {
        let canvas = canvas(3, 2)
        #expect(canvas.plainLines() == ["   ", "   "])
        #expect(canvas.encodedLines() == ["", ""])
        #expect(canvas.cell(x: 0, y: 0) == Canvas.Cell(grapheme: " ", style: .plain, isContinuation: false))
        #expect(canvas.cell(x: 3, y: 0) == nil)
        #expect(canvas.cell(x: -1, y: 0) == nil)
        #expect(canvas.cell(x: 0, y: 2) == nil)
        #expect(canvas.bounds == Rect(x: 0, y: 0, width: 3, height: 2))
    }

    @Test func negativeSizeIsEmpty() {
        let canvas = canvas(-3, -1)
        #expect(canvas.width == 0)
        #expect(canvas.height == 0)
        #expect(canvas.encodedLines().isEmpty)
    }

    @Test func writeTextWithStyles() {
        var canvas = canvas(6)
        canvas.write([run("ab", .red), run("cd")], at: Point(x: 1, y: 0))
        #expect(canvas.plainLines() == [" abcd "])
        #expect(canvas.cell(x: 1, y: 0)?.style == .red)
        #expect(canvas.cell(x: 3, y: 0)?.style == .plain)
    }

    @Test func writeOutsideTheCanvasIsIgnored() {
        var canvas = canvas(3, 2)
        canvas.write([run("x")], at: Point(x: 0, y: -1))
        canvas.write([run("x")], at: Point(x: 0, y: 2))
        canvas.write([run("x")], at: Point(x: 3, y: 0))
        canvas.write([run("x")], at: Point(x: -5, y: 0))
        #expect(canvas.plainLines() == ["   ", "   "])
        canvas.write([run("abcdef")], at: Point(x: -2, y: 1))
        #expect(canvas.plainLines() == ["   ", "cde"])
    }

    @Test func writeStopsAtTheClip() {
        var canvas = canvas(8, 2)
        let clip = Rect(x: 2, y: 0, width: 3, height: 1)
        canvas.write([run("abcdefgh")], at: .zero, clip: clip)
        canvas.write([run("abcdefgh")], at: Point(x: 0, y: 1), clip: clip)
        #expect(canvas.plainLines() == ["  cde   ", "        "])
    }

    @Test func writeIgnoresControlsAndNewlines() {
        var canvas = canvas(5)
        canvas.write([run("a\nb\u{7}c\t")], at: .zero)
        #expect(canvas.plainLines() == ["abc  "])
    }

    @Test func emptyClipDrawsNothing() {
        var canvas = canvas(3)
        canvas.write([run("abc")], at: .zero, clip: Rect(x: 1, y: 0, width: 0, height: 1))
        #expect(canvas.plainLines() == ["   "])
    }

    // MARK: wide characters

    @Test func wideCharacterTakesTwoCells() {
        var canvas = canvas(4)
        canvas.write([run("你好")], at: .zero)
        #expect(canvas.plainLines() == ["你好"])
        #expect(canvas.cell(x: 0, y: 0)?.isContinuation == false)
        #expect(canvas.cell(x: 1, y: 0)?.isContinuation == true)
        #expect(canvas.encodedLines() == ["你好"])
    }

    @Test func wideCharacterAtTheCanvasEdgeBecomesASpace() {
        var canvas = canvas(3)
        canvas.write([run("ab你")], at: .zero)
        #expect(canvas.plainLines() == ["ab "])
    }

    @Test(arguments: [
        (1, 3, " 好"), (0, 3, "你 "), (1, 2, "  "), (0, 4, "你好"),
    ])
    func clippingWideTextKeepsItsBackground(offset: Int, width: Int, expected: String) {
        var canvas = canvas(width)
        canvas.write([run("你好", .onBlue)], at: Point(x: -offset, y: 0), clip: Rect(x: 0, y: 0, width: width, height: 1))
        #expect(canvas.plainLines() == [expected])
        for column in 0..<width {
            #expect(canvas.cell(x: column, y: 0)?.style == .onBlue)
        }
    }

    @Test func clippedHalvesKeepTheirOwnBackgrounds() {
        var canvas = canvas(2)
        canvas.write([run("你", .onBlue), run("好", .onRed)], at: Point(x: -1, y: 0))
        #expect(canvas.plainLines() == ["  "])
        #expect(canvas.cell(x: 0, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 1, y: 0)?.style == .onRed)
    }

    @Test func clippedJoinedEmojiKeepsAdjacentText() {
        var canvas = canvas(2)
        canvas.write([run("👩‍💻X", .onBlue)], at: Point(x: -1, y: 0))
        #expect(canvas.plainLines() == [" X"])
        #expect(canvas.encodedLines() == ["\(esc)[44m X\(esc)[49m"])
    }

    @Test(arguments: [0, 1])
    func overwritingHalfOfAWideCharacterKeepsTheOtherHalf(column: Int) {
        var canvas = canvas(3)
        canvas.write([run("你Z", .onBlue)], at: .zero)
        canvas.write([run("X")], at: Point(x: column, y: 0))
        #expect(canvas.plainLines() == [column == 0 ? "X Z" : " XZ"])
        let blank = canvas.cell(x: 1 - column, y: 0)
        #expect(blank?.grapheme == " ")
        #expect(blank?.style == .onBlue)
        #expect(blank?.isContinuation == false)
        #expect(canvas.cell(x: column, y: 0)?.style == .plain)
    }

    @Test(arguments: ["XY", "好"])
    func fullyOverwritingAWideCharacterReplacesItsStyle(replacement: String) {
        var canvas = canvas(3)
        canvas.write([run("你Z", .onBlue)], at: .zero)
        canvas.write([run(replacement, .onRed)], at: .zero)
        #expect(canvas.plainLines() == [replacement + "Z"])
        #expect(canvas.cell(x: 1, y: 0)?.style == .onRed)
        #expect(canvas.cell(x: 2, y: 0)?.style == .onBlue)
    }

    @Test func overlayCrossingTwoWideCharacters() {
        var canvas = canvas(4)
        canvas.write([run("你", .onBlue), run("好", .onGreen)], at: .zero)
        canvas.write([run("XY", .onRed)], at: Point(x: 1, y: 0))
        #expect(canvas.plainLines() == [" XY "])
        #expect(canvas.cell(x: 0, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 1, y: 0)?.style == .onRed)
        #expect(canvas.cell(x: 2, y: 0)?.style == .onRed)
        #expect(canvas.cell(x: 3, y: 0)?.style == .onGreen)
        #expect(canvas.cell(x: 3, y: 0)?.isContinuation == false)
    }

    @Test func wideOverwriteWithWideNeighbourLeavesNoOrphan() {
        var canvas = canvas(4)
        canvas.write([run("a你b")], at: .zero)
        canvas.write([run("好")], at: .zero)
        #expect(canvas.plainLines() == ["好 b"])
    }

    // MARK: combining marks

    @Test func marksJoinThePreviousCell() {
        var canvas = canvas(3)
        canvas.write([run("e", .blue), run("\u{301}X", .red)], at: .zero)
        #expect(canvas.plainLines() == ["e\u{301}X "])
        #expect(canvas.cell(x: 0, y: 0)?.style == .blue)
        #expect(canvas.cell(x: 1, y: 0)?.style == .red)
    }

    @Test func writingNothingVisibleLeavesWideCharactersAlone() {
        var canvas = canvas(4)
        canvas.write([run("你好")], at: .zero)
        canvas.write([run("\u{200B}")], at: Point(x: 1, y: 0))
        canvas.write([run("")], at: Point(x: 1, y: 0))
        #expect(canvas.plainLines() == ["你好"])
    }

    @Test func markWithoutBaseIsDropped() {
        var canvas = canvas(3)
        canvas.write([run("\u{301}X"), run("\u{200B}")], at: .zero)
        #expect(canvas.plainLines() == ["X  "])
    }

    @Test func markThatCannotCombineIsDropped() {
        var canvas = canvas(3)
        canvas.write([run("a\u{200B}b")], at: .zero)
        #expect(canvas.plainLines() == ["ab "])
    }

    @Test func variationSelectorWidensTheCell() {
        var canvas = canvas(4)
        canvas.write([run("❤"), run("\u{FE0F}X", .red)], at: .zero)
        #expect(canvas.plainLines() == ["❤\u{FE0F}X "])
        #expect(canvas.cell(x: 1, y: 0)?.isContinuation == true)
        #expect(canvas.cell(x: 2, y: 0)?.grapheme == "X")
    }

    @Test func variationSelectorAtTheClipEdgeKeepsTheCellNarrow() {
        var canvas = canvas(1)
        canvas.write([run("❤\u{FE0F}")], at: .zero)
        #expect(canvas.cell(x: 0, y: 0)?.isContinuation == false)
    }
}
