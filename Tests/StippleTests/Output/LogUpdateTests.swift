import Testing

@testable import Stipple

@MainActor
@Suite struct LogUpdateTests {
    @Test func standardRewritesTheWholeFrame() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        #expect(log.render("a\nb"))
        #expect(output.take() == [Bytes.hide, "a\nb"])

        #expect(log.render("a\nc"))
        #expect(output.take() == ["\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[Ga\nc"])

        #expect(!log.render("a\nc"))
        #expect(output.take().isEmpty)
    }

    @Test func clearErasesTheFrameAndDoneShowsTheCursor() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.render("a\nb")
        _ = output.take()

        log.clear()
        #expect(output.take() == ["\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G"])

        log.done()
        #expect(output.take() == [Bytes.show])
    }

    @Test func showCursorKeepsTheCursorVisible() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, showCursor: true)
        log.render("x")
        log.done()
        #expect(output.take() == ["x"])
    }

    @Test func cursorPositionIsAppliedOnRenderAndConsumed() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        #expect(log.isCursorDirty)
        #expect(log.render("a\nb"))
        #expect(!log.isCursorDirty)
        #expect(log.cursorPosition == CursorPosition(x: 0, y: 0))
        #expect(output.take() == [Bytes.hide, "a\nb\u{1B}[1A\u{1B}[1G" + Bytes.show])
    }

    @Test func unchangedTextAndCursorWritesNothing() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        log.render("a\nb")
        _ = output.take()

        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        #expect(!log.willRender("a\nb"))
        #expect(!log.render("a\nb"))
        #expect(output.take().isEmpty)
    }

    @Test func movingOnlyTheCursorRepositionsIt() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        log.render("a\nb")
        _ = output.take()

        log.setCursorPosition(CursorPosition(x: 1, y: 1))
        #expect(log.willRender("a\nb"))
        #expect(log.isCursorDirty)
        #expect(log.render("a\nb"))
        #expect(output.take() == [Bytes.hide + "\u{1B}[1B\u{1B}[1G\u{1B}[2G" + Bytes.show])
    }

    @Test func clearAndDoneReturnFromACursorPosition() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        log.render("a\nb")
        _ = output.take()

        log.clear()
        #expect(output.take() == [Bytes.hide + "\u{1B}[1G\u{1B}[J"])
        #expect(log.cursorPosition == nil)

        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        log.render("a\nb")
        _ = output.take()
        log.done()
        #expect(output.take() == ["\u{1B}[1B\u{1B}[1G", Bytes.show])
    }

    @Test func syncRecordsTheFrameWithoutWritingIt() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.sync("a\nb")
        #expect(output.take().isEmpty)
        #expect(!log.render("a\nb"))
        #expect(output.take() == [Bytes.hide])

        log.setCursorPosition(CursorPosition(x: 0, y: 0))
        log.sync("a\nb")
        #expect(output.take() == ["\u{1B}[1A\u{1B}[1G" + Bytes.show])
        #expect(log.cursorPosition == CursorPosition(x: 0, y: 0))

        log.sync("a\nb")
        #expect(output.take() == [Bytes.hide])
        #expect(log.cursorPosition == nil)
    }

    @Test func resetForgetsTheFrameWithoutErasingIt() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output)
        log.render("a")
        _ = output.take()
        log.reset()
        log.render("a")
        #expect(output.take() == ["a"])
    }

    @Test func incrementalFirstWriteIsPlain() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a\nb\nc")
        #expect(output.take() == [Bytes.hide, "a\nb\nc"])
    }

    @Test func incrementalRewritesOnlyChangedLines() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a\nb\nc")
        _ = output.take()
        log.render("a\nb\nd")
        #expect(output.take() == ["\u{1B}[2A\u{1B}[E\u{1B}[E\u{1B}[1G\u{1B}[Kd"])
    }

    @Test func incrementalShrinkErasesTheRowsLeftBehind() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a\nb\nd")
        _ = output.take()
        log.render("a")
        #expect(output.take() == ["\u{1B}[2K\u{1B}[1A\u{1B}[2K\u{1B}[G\u{1B}[1A"])
    }

    @Test func incrementalGrowthWritesTheNewRow() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a")
        _ = output.take()
        log.render("a\nb")
        #expect(output.take() == ["\u{1B}[E\u{1B}[1G\u{1B}[Kb"])
    }

    @Test func incrementalNewlineOnlyRedrawsTheFrame() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a")
        _ = output.take()
        log.render("\n")
        #expect(output.take() == ["\u{1B}[2K\u{1B}[G\n"])
    }

    @Test func incrementalKeepsTrailingNewlineWhenRowsAreSkipped() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a\nb\n")
        _ = output.take()
        log.render("a\nc\n")
        #expect(output.take() == ["\u{1B}[2A\u{1B}[E\u{1B}[1G\u{1B}[Kc\n"])
    }

    @Test func incrementalRepaintsWholeRowsWhenColumnsChange() {
        let output = RecordingOutput()
        let log = LogUpdate(output: output, incremental: true)
        log.render("a\nb")
        _ = output.take()
        output.size = Size(width: 40, height: 24)
        log.render("a\nc")
        #expect(output.take() == ["\u{1B}[1A\u{1B}[E\u{1B}[1G\u{1B}[Kc"])
    }
}
