import Testing

@testable import Stipple

@MainActor
@Suite struct ScreenReaderTests {
    private let bsu = Bytes.begin
    private let esu = Bytes.end

    private func makeWriter(width: Int = 80) -> (FrameWriter, RecordingOutput) {
        let output = RecordingOutput(size: Size(width: width, height: 24))
        let writer = FrameWriter(output: output, options: FrameWriterOptions(screenReader: true))
        return (writer, output)
    }

    @Test func drawsTheFrameWithoutHidingOrMovingTheCursor() {
        let (writer, output) = makeWriter()
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, "a\nb", esu])
    }

    @Test func unchangedFrameWithoutStaticOutputIsNotRewritten() {
        let (writer, output) = makeWriter()
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        _ = output.take()
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, esu])
    }

    @Test func changedFrameErasesThePreviousOneFirst() {
        let (writer, output) = makeWriter()
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        _ = output.take()
        writer.write(frame: "a\nc", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G", "a\nc", esu])
    }

    @Test func staticOutputIsWrittenBetweenTheEraseAndTheFrame() {
        let (writer, output) = makeWriter()
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        _ = output.take()
        writer.write(frame: "f", height: 1, staticOutput: "S\n")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G", "S\n", "f", esu])
    }

    @Test func framesAreWrappedToTheTerminalWidth() {
        let (writer, output) = makeWriter(width: 5)
        writer.write(frame: "hello world", height: 2, staticOutput: "")
        // A line that holds only the space the break fell on, as TextLayout.wrap gives it.
        #expect(output.take() == [bsu, "hello\n \nworld", esu])
    }

    @Test func styledTextKeepsItsStyleOnEveryWrappedLine() {
        let (writer, output) = makeWriter(width: 3)
        writer.write(frame: "\u{1B}[31mab cd\u{1B}[0m", height: 2, staticOutput: "")
        let written = output.take()
        #expect(written.count == 3)
        // Each wrapped line is encoded on its own, so each one opens and closes its style.
        let lines = written[1].split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines == ["\u{1B}[31mab \u{1B}[39m", "\u{1B}[31mcd\u{1B}[39m"])
    }

    @Test func cursorPositionIsNeverShownOrHidden() {
        let (writer, output) = makeWriter()
        writer.setCursorPosition(CursorPosition(x: 2, y: 0))
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, "a\nb", esu])
    }

    @Test func writeAboveRedrawsTheFrameWithoutCursorPlacement() {
        let (writer, output) = makeWriter()
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        writer.writeAbove("log\n")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[G", "log\n", "a", esu])
    }
}
