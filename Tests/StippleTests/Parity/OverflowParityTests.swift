import Testing

@testable import Stipple

/// Ports of Ink's `overflow.tsx`. `overflow="hidden"` is `.clipped()` on a fixed frame;
/// negative margins are `.offset`.
@MainActor
struct OverflowParityTests {
    private func box(_ content: String, width: Int? = nil) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let inner = width ?? (lines.map { TextMetrics.width(of: $0) }.max() ?? 0)
        let pad = { (line: String) in line + String(repeating: " ", count: inner - TextMetrics.width(of: line)) }
        let bar = String(repeating: "─", count: inner)
        return (["╭\(bar)╮"] + lines.map { "│\(pad($0))│" } + ["╰\(bar)╯"]).joined(separator: "\n")
    }

    private func clippedX(_ text: String, inner: Int, content: Int, offset: Int = 0) -> some View {
        Text(text)
            .frame(width: content, alignment: .leading)
            .fixedSize()
            .offset(x: offset)
            .frame(width: inner, alignment: .leading)
            .clipped()
    }

    // MARK: horizontal

    @Test func singleTextNode() {
        #expect(plain(clippedX("Hello World", inner: 6, content: 16)) == "Hello")
    }

    @Test func zeroWidthContainer() {
        let view = HStack {
            Text("hello").frame(width: 0, alignment: .leading).clipped()
            Text("|")
        }
        #expect(plain(view) == "|")
    }

    @Test func singleTextNodeWithBorder() {
        #expect(plain(clippedX("Hello World", inner: 4, content: 16).border(.rounded)) == box("Hell"))
    }

    @Test func boxWithBorderInsideOverflowContainer() {
        let view = Text("Hello World").frame(width: 14, alignment: .leading).border(.rounded)
            .fixedSize().frame(width: 6, alignment: .leading).clipped()
        #expect(plain(view) == "╭─────\n│Hello\n╰─────")
    }

    @Test func multipleTextNodes() {
        let view = HStack(spacing: 0) {
            Text("Hello ")
            Text("World")
        }
        .fixedSize().frame(width: 6, alignment: .leading).clipped()
        #expect(plain(view) == "Hello")
    }

    @Test func multipleBoxesInsideOverflowContainer() {
        let view = HStack(spacing: 0) {
            Text("Hello ").frame(width: 6, alignment: .leading)
            Text("World").frame(width: 6, alignment: .leading)
        }
        .fixedSize().frame(width: 6, alignment: .leading).clipped()
        #expect(plain(view) == "Hello")
    }

    @Test func boxBeforeLeftEdge() {
        #expect(plain(clippedX("Hello", inner: 6, content: 6, offset: -12)).isEmpty)
    }

    @Test func boxBeforeLeftEdgeWithBorder() {
        #expect(plain(clippedX("Hello", inner: 6, content: 6, offset: -12).border(.rounded)) == box("      "))
    }

    @Test func boxIntersectingLeftEdge() {
        #expect(plain(clippedX("Hello World", inner: 6, content: 12, offset: -3)) == "lo Wor")
        #expect(plain(clippedX("Hello World", inner: 6, content: 12, offset: -3).border(.rounded)) == box("lo Wor"))
    }

    @Test func boxAfterRightEdge() {
        #expect(plain(clippedX("Hello", inner: 6, content: 6, offset: 6)).isEmpty)
    }

    @Test func boxIntersectingRightEdge() {
        #expect(plain(clippedX("Hello", inner: 6, content: 6, offset: 3)) == "   Hel")
    }

    // MARK: vertical

    private func clippedY(_ text: String, inner: Int, content: Int, offset: Int = 0) -> some View {
        Text(text)
            .frame(height: content, alignment: .topLeading)
            .fixedSize()
            .offset(y: offset)
            .frame(height: inner, alignment: .topLeading)
            .clipped()
    }

    @Test func singleTextNodeVertically() {
        #expect(plain(Text("Hello\nWorld").frame(height: 1, alignment: .topLeading).clipped()) == "Hello")
    }

    @Test func singleTextNodeVerticallyWithBorder() {
        let view = Text("Hello\nWorld").frame(width: 18, height: 1, alignment: .topLeading).clipped().border(.rounded)
        #expect(plain(view) == box("Hello", width: 18))
    }

    @Test func multipleBoxesVertically() {
        let view = VStack {
            Text("Line #1")
            Text("Line #2")
            Text("Line #3")
            Text("Line #4")
        }
        .fixedSize().frame(height: 2, alignment: .topLeading).clipped()
        #expect(plain(view) == "Line #1\nLine #2")
    }

    @Test func multipleBoxesVerticallyWithBorder() {
        let view = VStack {
            Text("Line #1")
            Text("Line #2")
            Text("Line #3")
            Text("Line #4")
        }
        .fixedSize().frame(width: 7, height: 2, alignment: .topLeading).clipped().border(.rounded)
        #expect(plain(view) == box("Line #1\nLine #2"))
    }

    @Test func boxAboveTopEdge() {
        #expect(plain(clippedY("Hello\nWorld", inner: 1, content: 2, offset: -2)).isEmpty)
    }

    @Test func boxIntersectingTopEdge() {
        #expect(plain(clippedY("Hello\nWorld", inner: 1, content: 2, offset: -1)) == "World")
    }

    @Test func boxBelowBottomEdge() {
        #expect(plain(clippedY("Hello\nWorld", inner: 1, content: 2, offset: 1)).isEmpty)
    }

    @Test func boxIntersectingBottomEdge() {
        #expect(plain(clippedY("Hello\nWorld", inner: 1, content: 2)) == "Hello")
    }

    // MARK: both axes

    @Test func clipsBothAxes() {
        let view = Text("ABCDEF\nGHIJKL").fixedSize().frame(width: 3, height: 1, alignment: .topLeading).clipped()
        #expect(plain(view) == "ABC")
    }

    @Test func boxIntersectingTopLeftEdge() {
        let view = Text("AAAA\nBBBB\nCCCC\nDDDD")
            .fixedSize()
            .offset(x: -2, y: -2)
            .frame(width: 4, height: 4, alignment: .topLeading)
            .clipped()
        #expect(plain(view) == "CC\nDD\n\n")
    }

    @Test(.disabled("Per-axis overflow (overflowX/overflowY=visible) has no counterpart: .clipped() clips both axes"))
    func perAxisOverflow() {}

    @Test(.disabled("Ink's Transform passes a line index through vertical clipping; Stipple has no textTransform yet"))
    func transformLineIndicesSurviveClipping() {}
}
