import Testing

@testable import Stipple

@MainActor
@Suite struct FrameWriterTests {
    private let bsu = Bytes.begin
    private let esu = Bytes.end

    @Test func nonInteractiveWritesOnlyStaticOutputAndTheFinalFrame() {
        let output = RecordingOutput(isTerminal: false)
        let writer = FrameWriter(output: output)
        writer.write(frame: "hello", height: 1, staticOutput: "")
        #expect(output.take().isEmpty)
        writer.write(frame: "bye", height: 1, staticOutput: "S\n")
        #expect(output.take() == ["S\n"])
        writer.finish()
        #expect(output.take() == ["bye\n"])
    }

    @Test func interactiveFlagOverridesTheTerminalCheck() {
        let output = RecordingOutput(isTerminal: true)
        let writer = FrameWriter(output: output, options: FrameWriterOptions(interactive: false))
        writer.write(frame: "x", height: 1, staticOutput: "")
        writer.finish()
        #expect(output.take() == ["x\n"])
    }

    @Test func debugAppendsEveryFrameInFull() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output, options: FrameWriterOptions(debug: true))
        writer.write(frame: "a", height: 1, staticOutput: "")
        #expect(output.take() == ["a"])
        writer.write(frame: "b", height: 1, staticOutput: "s1\n")
        #expect(output.take() == ["s1\nb"])
        writer.write(frame: "b", height: 1, staticOutput: "")
        #expect(output.take() == ["s1\nb"])
        writer.finish()
        #expect(output.take().isEmpty)
    }

    @Test func debugWriteAboveAndClearDoNotEraseTheFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output, options: FrameWriterOptions(debug: true))
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        writer.writeAbove("X")
        #expect(output.take() == ["Xa"])
        writer.clear()
        #expect(output.take().isEmpty)
    }

    @Test func interactiveDrawsChangedFramesOnly() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, Bytes.hide, "a\nb\n", esu])

        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take().isEmpty)

        writer.write(frame: "a\nc", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[Ga\nc\n", esu])

        writer.finish()
        #expect(output.take() == [Bytes.show])
    }

    @Test func staticOutputIsWrittenAboveTheRedrawnFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "f", height: 1, staticOutput: "")
        _ = output.take()
        writer.write(frame: "f2", height: 1, staticOutput: "S\n")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G", "S\n", "f2\n", esu])
        #expect(writer.hasRenderedStaticOutput)
        writer.staticChanged()
        #expect(!writer.hasRenderedStaticOutput)
    }

    @Test func overflowingFrameIsClearedWithAnAbsoluteErase() {
        let output = RecordingOutput(size: Size(width: 80, height: 3))
        let writer = FrameWriter(output: output)
        writer.write(frame: "a\nb\nc\nd", height: 4, staticOutput: "")
        _ = output.take()
        writer.write(frame: "a\nb\nc\ne", height: 4, staticOutput: "")
        #expect(output.take() == [bsu, "\u{1B}[1;1H\u{1B}[Ja\nb\nc\ne", esu])
    }

    @Test func shrinkingViewportUnderAFullscreenFrameWalksUpFromTheCursor() {
        let output = RecordingOutput(size: Size(width: 80, height: 4))
        let writer = FrameWriter(output: output)
        writer.setCursorPosition(CursorPosition(x: 0, y: 1))
        writer.write(frame: "a\nb\nc\nd", height: 4, staticOutput: "")
        #expect(output.take() == [bsu, Bytes.hide, "a\nb\nc\nd\u{1B}[2A\u{1B}[1G" + Bytes.show, esu])

        output.size = Size(width: 80, height: 3)
        writer.write(frame: "a\nb\nc\ne", height: 4, staticOutput: "")
        #expect(
            output.take()
                == [bsu, "\u{1B}[1A\u{1B}[1G\u{1B}[Ja\nb\nc\ne", "\u{1B}[2A\u{1B}[1G" + Bytes.show, esu]
        )
    }

    @Test func alternateScreenEntersReplaysStaticOutputAndLeaves() {
        let output = RecordingOutput(size: Size(width: 80, height: 3))
        let writer = FrameWriter(output: output, options: FrameWriterOptions(alternateScreen: true))
        #expect(output.take() == ["\u{1B}[?1049h" + Bytes.hide])

        writer.write(frame: "a\nb\nc\nd", height: 4, staticOutput: "S\n")
        #expect(output.take() == [bsu, "S\n", Bytes.hide, "a\nb\nc\nd", esu])

        writer.write(frame: "a\nb\nc\ne", height: 4, staticOutput: "T\n")
        #expect(output.take() == [bsu, "\u{1B}[1;1H\u{1B}[JS\nT\na\nb\nc\ne", esu])

        writer.finish()
        #expect(output.take() == [Bytes.show, "\u{1B}[?1049l" + Bytes.show])
    }

    @Test func alternateScreenIsIgnoredWhenNotInteractive() {
        let output = RecordingOutput(isTerminal: false)
        let writer = FrameWriter(output: output, options: FrameWriterOptions(alternateScreen: true))
        writer.finish()
        #expect(output.take() == ["\n"])
    }

    @Test func finalFrameIsDrawnBeforeTheCursorIsShown() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        writer.finish(finalFrame: FrameWriter.Frame(text: "b", height: 1, staticOutput: ""))
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[Gb\n", esu, Bytes.show])
    }

    @Test func writesAfterFinishAreIgnored() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.finish()
        _ = output.take()
        writer.finish()
        writer.write(frame: "x", height: 1, staticOutput: "")
        writer.writeAbove("y")
        writer.clear()
        #expect(output.take().isEmpty)
    }

    @Test func writeAboveErasesTheFrameWritesTextAndRedrawsTheFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        writer.writeAbove("log line\n")
        #expect(output.take() == [bsu, "\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G", "log line\n", "a\n", esu])
    }

    @Test func writeAboveWritesPlainTextWhenNotInteractive() {
        let output = RecordingOutput(isTerminal: false)
        let writer = FrameWriter(output: output)
        writer.writeAbove("x")
        #expect(output.take() == ["x"])
    }

    @Test func resizingNarrowerErasesTheFrameAndTheNextWriteDrawsIt() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        _ = output.take()

        output.size = Size(width: 60, height: 24)
        writer.resized()
        #expect(output.take() == ["\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G"])

        writer.write(frame: "a\nb", height: 2, staticOutput: "")
        #expect(output.take() == [bsu, "a\nb\n", esu])
    }

    @Test func resizingShorterWithoutCursorKeepsTheFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        output.size = Size(width: 80, height: 20)
        writer.resized()
        #expect(output.take().isEmpty)
    }

    @Test func resizingShorterWithCursorErasesTheFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.setCursorPosition(CursorPosition(x: 0, y: 0))
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        output.size = Size(width: 80, height: 20)
        writer.resized()
        // A cursor-relative erase: hide, back to column 0, erase down.
        #expect(output.take() == [Bytes.hide + "\u{1B}[1G\u{1B}[J"])
    }

    @Test func resizeIsIgnoredWhenNotInteractive() {
        let output = RecordingOutput(isTerminal: false)
        let writer = FrameWriter(output: output)
        output.size = Size(width: 10, height: 2)
        writer.resized()
        #expect(output.take().isEmpty)
    }

    @Test func clearErasesTheFrameAndTheNextWriteRedrawsIt() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.write(frame: "a", height: 1, staticOutput: "")
        _ = output.take()
        writer.clear()
        #expect(output.take() == ["\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G"])
        writer.write(frame: "a", height: 1, staticOutput: "")
        #expect(output.take() == [bsu, "a\n", esu])
    }

    @Test func cursorPositionIsAppliedToTheFrame() {
        let output = RecordingOutput()
        let writer = FrameWriter(output: output)
        writer.setCursorPosition(CursorPosition(x: 1, y: 0))
        writer.write(frame: "ab", height: 1, staticOutput: "")
        #expect(output.take() == [bsu, Bytes.hide, "ab\n\u{1B}[1A\u{1B}[2G" + Bytes.show, esu])

        writer.write(frame: "ab", height: 1, staticOutput: "")
        #expect(output.take().isEmpty)

        writer.setCursorPosition(CursorPosition(x: 2, y: 0))
        writer.write(frame: "ab", height: 1, staticOutput: "")
        #expect(output.take() == [bsu, Bytes.hide + "\u{1B}[1B\u{1B}[1G\u{1B}[1A\u{1B}[3G" + Bytes.show, esu])
    }
}
