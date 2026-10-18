import Testing

@testable import Stipple

/// Ports of Ink's `borders.tsx` (boxen output is rebuilt with `box(_:)`).
@MainActor
struct BorderParityTests {
    private let round: [Character] = ["╭", "─", "╮", "│", "│", "╰", "─", "╯"]

    /// A rounded box around `content` lines, padded to the widest line (or `width` inner columns),
    /// like boxen's output for `borderStyle: 'round'`.
    private func box(_ content: String, width: Int? = nil, chars: [Character]? = nil) -> String {
        let glyphs = chars ?? round
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let inner = width ?? (lines.map { TextMetrics.width(of: $0) }.max() ?? 0)
        let pad = { (line: String) in line + String(repeating: " ", count: inner - TextMetrics.width(of: line)) }
        let top = "\(glyphs[0])" + String(repeating: glyphs[1], count: inner) + "\(glyphs[2])"
        let bottom = "\(glyphs[5])" + String(repeating: glyphs[6], count: inner) + "\(glyphs[7])"
        return ([top] + lines.map { "\(glyphs[3])\(pad($0))\(glyphs[4])" } + [bottom]).joined(separator: "\n")
    }

    private func fullWidth(_ text: Text) -> some View {
        text.frame(maxWidth: .infinity, alignment: .leading).border(.rounded)
    }

    @Test func fullWidthBox() {
        #expect(plain(fullWidth(Text("Hello World"))) == box("Hello World", width: 98))
    }

    @Test func fullWidthBoxWithColorfulBorder() {
        let view = Text("Hello World").frame(maxWidth: .infinity, alignment: .leading).border(.rounded, color: .green)
        let green = { (text: String) in "\(esc)[32m\(text)\(esc)[39m" }
        let rows = box("Hello World", width: 98).split(separator: "\n").map(String.init)
        let middle = String(rows[1].dropFirst().dropLast())
        let expected = [green(rows[0]), green("│") + middle + green("│"), green(rows[2])].joined(separator: "\n")
        #expect(sameStyledText(render(view), expected))
    }

    @Test(arguments: ["Hello World", "こんにちは", "🌊🌊", "🌡️⚠️✅"])
    func fitContentBox(text: String) {
        #expect(plain(Text(text).border(.rounded)) == box(text))
    }

    @Test func fixedWidthBox() {
        let view = Text("Hello World").frame(width: 18, alignment: .leading).border(.rounded)
        #expect(plain(view) == box("Hello World", width: 18))
    }

    @Test func fixedWidthAndHeightBox() {
        let view = Text("Hello World").frame(width: 18, height: 18, alignment: .topLeading).border(.rounded)
        #expect(plain(view) == box("Hello World" + String(repeating: "\n", count: 17), width: 18))
    }

    @Test func boxWithPadding() {
        #expect(plain(Text("Hello World").padding(1).border(.rounded)) == box("\n Hello World \n"))
    }

    @Test func horizontalAlignment() {
        let view = Text("Hello World").frame(width: 18, alignment: .top).border(.rounded)
        #expect(plain(view) == box("   Hello World    "))
    }

    @Test func verticalAlignment() {
        let view = Text("Hello World").frame(height: 18, alignment: .leading).border(.rounded)
        let content = String(repeating: "\n", count: 8) + "Hello World" + String(repeating: "\n", count: 9)
        #expect(plain(view) == box(content))
    }

    @Test func wrapping() {
        let view = Text("Hello World").frame(width: 8, alignment: .leading).border(.rounded)
        #expect(plain(view) == box("Hello \nWorld", width: 8))
    }

    @Test func wrappingWithLongFirstWord() {
        let view = Text("Helloooooo World").frame(width: 8, alignment: .leading).border(.rounded)
        #expect(plain(view) == box("Helloooo\noo World"))
        let veryLong = Text("Hellooooooooooooo World").frame(width: 8, alignment: .leading).border(.rounded)
        #expect(plain(veryLong) == box("Helloooo\noooooooo\no World"))
    }

    @Test func nestedBoxes() {
        let inner = Text("Hello World").padding(1).border(.rounded)
        let view = inner.padding(1).frame(width: 38, alignment: .topLeading).border(.rounded)
        let nested = box("\n Hello World \n").split(separator: "\n").map { " " + $0 }.joined(separator: "\n")
        #expect(plain(view) == box(String(repeating: " ", count: 38) + "\n" + nested + "\n", width: 38))
    }

    @Test(arguments: [["ミスター", "スポック", "カーク船長"], ["🦾", "🌏", "😋"]])
    func nestedBoxesInARow(words: [String]) {
        let view = HStack { ForEach(words, id: \.self) { Text($0).border(.rounded) } }.border(.rounded)
        let boxes = words.map { box($0).split(separator: "\n").map(String.init) }
        let rows = (0..<3).map { row in boxes.map { $0[row] }.joined() }
        #expect(plain(view) == box(rows.joined(separator: "\n")))
    }

    private func stretchedColumn(_ words: [String]) -> some View {
        // Ink stretches the inner boxes of a column to the widest one (alignItems: stretch); SwiftUI needs a flexible frame.
        VStack {
            ForEach(words, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading).border(.rounded) }
        }
        .fixedSize()
        .border(.rounded)
    }

    private func stretchedColumnExpected(_ words: [String]) -> String {
        let inner = words.map { TextMetrics.width(of: $0) }.max() ?? 0
        return box(words.map { box($0, width: inner) }.joined(separator: "\n"))
    }

    @Test func nestedBoxesInAColumnOfEqualWidth() {
        let words = ["🦾", "🌏", "😋"]
        #expect(plain(stretchedColumn(words)) == stretchedColumnExpected(words))
    }

    @Test func nestedBoxesInAColumnStretchToTheWidest() {
        let words = ["ミスター", "スポック", "カーク船長"]
        withKnownIssue("A VStack sized by fixedSize doesn't re-offer its final width to maxWidth: .infinity children") {
            #expect(plain(stretchedColumn(words)) == stretchedColumnExpected(words))
        }
    }

    // MARK: hidden sides

    private func around(_ edges: Edge.Set) -> String {
        plain(
            VStack(alignment: .leading) {
                Text("Above")
                Text("Content").border(.rounded, edges: edges)
                Text("Below")
            })
    }

    @Test func hideTopBorder() {
        #expect(around([.leading, .trailing, .bottom]) == "Above\n│Content│\n╰───────╯\nBelow")
    }

    @Test func hideBottomBorder() {
        #expect(around([.leading, .trailing, .top]) == "Above\n╭───────╮\n│Content│\nBelow")
    }

    @Test func hideTopAndBottom() {
        #expect(around([.leading, .trailing]) == "Above\n│Content│\nBelow")
    }

    @Test func hideLeft() {
        #expect(around([.top, .bottom, .trailing]) == "Above\n───────╮\nContent│\n───────╯\nBelow")
    }

    @Test func hideRight() {
        #expect(around([.top, .bottom, .leading]) == "Above\n╭───────\n│Content\n╰───────\nBelow")
    }

    @Test func hideLeftAndRight() {
        #expect(around([.top, .bottom]) == "Above\n───────\nContent\n───────\nBelow")
    }

    @Test func hideAll() {
        #expect(around([]) == "Above\nContent\nBelow")
    }

    @Test func colorOfWholeBorder() {
        let output = render(Text("Content").border(.rounded, color: .green))
        #expect(output.hasPrefix("\(esc)[32m╭───────╮\(esc)[39m\n"))
    }

    @Test func customBorderStyle() {
        let arrow = BorderStyle(
            topLeft: "↘", top: "↓", topRight: "↙", left: "→", right: "←", bottomLeft: "↗", bottom: "↑", bottomRight: "↖"
        )
        #expect(plain(Text("Content").border(arrow)) == box("Content", chars: Array("↘↓↙→←↗↑↖")))
        #expect(plain(Text("Content").border(.arrow)) == box("Content", chars: Array("↘↓↙→←↗↑↖")))
    }

    // MARK: Not expressible with `.border(_:color:edges:)`

    @Test(.disabled("Border takes one color; Ink has borderTopColor/BottomColor/LeftColor/RightColor"))
    func perSideColors() {}

    @Test(.disabled("No borderDimColor / per-side dim on .border"))
    func dimBorder() {}

    @Test(.disabled("No borderBackgroundColor (border.background per side) on .border"))
    func borderBackgrounds() {}
}
