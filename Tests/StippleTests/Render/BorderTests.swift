import Testing

@testable import Stipple

@Suite struct BorderTests {
    private func draw(
        _ border: BorderStyle,
        _ width: Int,
        _ height: Int,
        edges: Edge.Set = .all,
    ) -> [String] {
        var canvas = Canvas(width: width, height: height)
        canvas.drawBorder(border, in: canvas.bounds, edges: edges, style: .plain)
        return canvas.plainLines()
    }

    @Test(arguments: [
        (BorderStyle.single, ["┌───┐", "│   │", "└───┘"]),
        (.double, ["╔═══╗", "║   ║", "╚═══╝"]),
        (.rounded, ["╭───╮", "│   │", "╰───╯"]),
        (.heavy, ["┏━━━┓", "┃   ┃", "┗━━━┛"]),
        (.singleDouble, ["╓───╖", "║   ║", "╙───╜"]),
        (.doubleSingle, ["╒═══╕", "│   │", "╘═══╛"]),
        (.classic, ["+---+", "|   |", "+---+"]),
        (.arrow, ["↘↓↓↓↙", "→   ←", "↗↑↑↑↖"]),
    ])
    func characterSets(border: BorderStyle, expected: [String]) {
        #expect(draw(border, 5, 3) == expected)
    }

    @Test func customBorder() {
        let border = BorderStyle(
            topLeft: "1", top: "2", topRight: "3", left: "4", right: "5", bottomLeft: "6", bottom: "7", bottomRight: "8"
        )
        #expect(draw(border, 4, 3) == ["1223", "4  5", "6778"])
    }

    @Test func hiddenSidesDropTheirCorners() {
        #expect(draw(.single, 5, 3, edges: [.top, .bottom]) == ["─────", "     ", "─────"])
        #expect(draw(.single, 5, 3, edges: [.leading, .trailing]) == ["│   │", "│   │", "│   │"])
        #expect(draw(.single, 5, 3, edges: [.top, .trailing, .bottom]) == ["────┐", "    │", "────┘"])
        #expect(draw(.single, 5, 3, edges: [.top, .leading]) == ["┌────", "│    ", "│    "])
        #expect(draw(.single, 5, 3, edges: []) == ["     ", "     ", "     "])
    }

    @Test func tinyBoxes() {
        #expect(draw(.single, 2, 2) == ["┌┐", "└┘"])
        #expect(draw(.single, 1, 1) == ["└"])
        #expect(draw(.single, 3, 1) == ["└─┘"])
        #expect(draw(.single, 1, 3) == ["┌", "│", "└"])
    }

    @Test func emptyRectDrawsNothing() {
        var canvas = Canvas(width: 3, height: 3)
        canvas.drawBorder(.single, in: Rect(x: 0, y: 0, width: 0, height: 3), style: .plain)
        #expect(canvas.plainLines() == ["   ", "   ", "   "])
    }

    @Test func borderInsideACanvas() {
        var canvas = Canvas(width: 6, height: 4)
        canvas.drawBorder(.rounded, in: Rect(x: 1, y: 1, width: 4, height: 3), style: .plain)
        #expect(canvas.plainLines() == ["      ", " ╭──╮ ", " │  │ ", " ╰──╯ "])
    }

    @Test func borderIsClipped() {
        var canvas = Canvas(width: 5, height: 3)
        canvas.drawBorder(.single, in: canvas.bounds, style: .plain, clip: Rect(x: 0, y: 0, width: 3, height: 2))
        #expect(canvas.plainLines() == ["┌──  ", "│    ", "     "])
    }

    @Test func eachSideHasItsOwnStyle() {
        var canvas = Canvas(width: 4, height: 3)
        let colors = BorderStyle.Colors(top: .red, left: .blue, bottom: .onRed, right: .onGreen)
        canvas.drawBorder(.single, in: canvas.bounds, colors: colors)
        #expect(canvas.cell(x: 0, y: 0)?.style == .red)
        #expect(canvas.cell(x: 2, y: 0)?.style == .red)
        #expect(canvas.cell(x: 3, y: 0)?.style == .red)
        #expect(canvas.cell(x: 0, y: 1)?.style == .blue)
        #expect(canvas.cell(x: 3, y: 1)?.style == .onGreen)
        #expect(canvas.cell(x: 1, y: 1)?.style == .plain)
        #expect(canvas.cell(x: 0, y: 2)?.style == .onRed)
        #expect(canvas.cell(x: 3, y: 2)?.style == .onRed)
    }

    @Test func uniformStyle() {
        var canvas = Canvas(width: 3, height: 3)
        canvas.drawBorder(.single, in: canvas.bounds, style: Style(foreground: .cyan, attributes: .dim))
        #expect(canvas.encodedLines().first == "\(esc)[2;36m┌─┐\(esc)[22;39m")
    }
}
