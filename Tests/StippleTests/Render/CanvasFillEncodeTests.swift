import Testing

@testable import Stipple

@Suite struct CanvasFillEncodeTests {
    private func canvas(_ width: Int, _ height: Int = 1) -> Canvas {
        Canvas(width: width, height: height)
    }

    // MARK: fill

    @Test func fillPaintsBackgroundAndKeepsCharacters() {
        var canvas = canvas(4, 2)
        canvas.write([run("ab", .red)], at: .zero)
        canvas.fill(Rect(x: 1, y: 0, width: 2, height: 2), background: .blue)
        #expect(canvas.plainLines() == ["ab  ", "    "])
        #expect(canvas.cell(x: 0, y: 0)?.style == .red)
        #expect(canvas.cell(x: 1, y: 0)?.style == Style(foreground: .red, background: .blue))
        #expect(canvas.cell(x: 2, y: 1)?.style == .onBlue)
        #expect(canvas.cell(x: 3, y: 1)?.style == .plain)
    }

    @Test func fillIsLimitedByClipAndCanvas() {
        var canvas = canvas(4)
        canvas.fill(
            Rect(x: -2, y: -1, width: 10, height: 5), background: .blue, clip: Rect(x: 1, y: 0, width: 2, height: 1))
        #expect(canvas.cell(x: 0, y: 0)?.style == .plain)
        #expect(canvas.cell(x: 1, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 2, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 3, y: 0)?.style == .plain)
        canvas.fill(Rect(x: 0, y: 0, width: 0, height: 1), background: .red)
        #expect(canvas.cell(x: 0, y: 0)?.style == .plain)
    }

    @Test func fillBlanksWideCharactersItCuts() {
        var canvas = canvas(6)
        canvas.write([run("你好吗")], at: .zero)
        canvas.fill(Rect(x: 1, y: 0, width: 4, height: 1), background: .blue)
        #expect(canvas.plainLines() == ["  好  "])
        #expect(canvas.cell(x: 0, y: 0)?.style == .plain)
        #expect(canvas.cell(x: 1, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 4, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 5, y: 0)?.style == .plain)
    }

    @Test func fillKeepsWholeWideCharacters() {
        var canvas = canvas(4)
        canvas.write([run("你好")], at: .zero)
        canvas.fill(Rect(x: 0, y: 0, width: 2, height: 1), background: .blue)
        #expect(canvas.plainLines() == ["你好"])
        #expect(canvas.cell(x: 1, y: 0)?.style == .onBlue)
        #expect(canvas.cell(x: 2, y: 0)?.style == .plain)
    }

    // MARK: encoding

    @Test func encodeTrimsTrailingPlainSpaces() {
        var canvas = canvas(8)
        canvas.write([run("ab  cd")], at: .zero)
        #expect(canvas.encodedLines() == ["ab  cd"])
    }

    @Test func encodeKeepsStyledTrailingCells() {
        var canvas = canvas(4)
        canvas.write([run("a"), run("  ", .onBlue)], at: .zero)
        #expect(canvas.encodedLines() == ["a\(esc)[44m  \(esc)[49m"])
    }

    @Test func encodeClosesStylesAtTheEndOfEachRow() {
        var canvas = canvas(2, 2)
        canvas.write([run("ab", Style(foreground: .red, attributes: .bold))], at: .zero)
        canvas.write([run("cd", .red)], at: Point(x: 0, y: 1))
        #expect(canvas.encodedLines() == ["\(esc)[1;31mab\(esc)[22;39m", "\(esc)[31mcd\(esc)[39m"])
    }

    @Test func encodeSwitchesStylesMinimally() {
        var canvas = canvas(5)
        canvas.write([run("a"), run("b", .red), run("c", .red), run("d", .blue), run("e")], at: .zero)
        #expect(canvas.encodedLines() == ["a\(esc)[31mbc\(esc)[34md\(esc)[39me"])
    }

    @Test func encodeHyperlinks() {
        var canvas = canvas(7)
        canvas.write([run("go "), run("here", Style(link: "https://example.com"))], at: .zero)
        #expect(canvas.encodedLines() == ["go \(esc)]8;;https://example.com\(esc)\\here\(esc)]8;;\(esc)\\"])
    }

    @Test func encodeStyledWideCharacters() {
        var canvas = canvas(4)
        canvas.write([run("你", .onBlue)], at: .zero)
        #expect(canvas.encodedLines() == ["\(esc)[44m你\(esc)[49m"])
    }

    @Test func encodeKeepsBlankedHalfOfWideCharacter() {
        var canvas = canvas(3)
        canvas.write([run("你", .onBlue)], at: .zero)
        canvas.write([run("X")], at: .zero)
        #expect(canvas.encodedLines() == ["X\(esc)[44m \(esc)[49m"])
    }
}
