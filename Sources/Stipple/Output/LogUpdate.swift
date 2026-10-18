/// Rewrites the live frame in place. Port of `log-update.ts`.
///
/// The standard variant erases the previous frame and writes the new one. The
/// incremental variant diffs the lines and rewrites only the ones that changed.
/// Each call writes straight to the output, with no throttling.
@MainActor
final class LogUpdate {
    private let output: any TerminalOutput
    private let showCursor: Bool
    private let incremental: Bool
    private var previousLines: [String] = []
    private var previousOutput = ""
    private var previousColumns: Int
    private var hasHiddenCursor = false
    private var requestedCursor: CursorPosition?
    private var cursorIsDirty = false
    private var previousCursorPosition: CursorPosition?
    private var wasCursorShown = false

    /// Creates a log that writes to `output`.
    /// - Parameters:
    ///   - output: Where the escape sequences and the frame are written.
    ///   - incremental: Diff lines instead of erasing and rewriting the frame.
    ///   - showCursor: Leave the cursor visible instead of hiding it while rendering.
    init(output: any TerminalOutput, incremental: Bool = false, showCursor: Bool = false) {
        self.output = output
        self.incremental = incremental
        self.showCursor = showCursor
        previousColumns = output.size.width
    }

    /// Where the last render or sync left the cursor, relative to the top of that
    /// frame. Nil when no cursor position was active, or after a clear, reset or done.
    var cursorPosition: CursorPosition? {
        previousCursorPosition
    }

    /// Whether `setCursorPosition(_:)` was called since the last render or sync.
    var isCursorDirty: Bool {
        cursorIsDirty
    }

    /// Sets the cursor position for the next render or sync. Nil removes it.
    func setCursorPosition(_ position: CursorPosition?) {
        requestedCursor = position
        cursorIsDirty = true
    }

    /// Whether `render(_:)` would write anything for `text`.
    func willRender(_ text: String) -> Bool {
        hasChanges(text, activeCursor: pendingCursor)
    }

    /// Writes `text` as the live frame. Returns false when nothing changed.
    @discardableResult
    func render(_ text: String) -> Bool {
        hideCursorIfNeeded()
        let cursor = activeCursor()
        let hasCursorChanged = CursorHelpers.changed(cursor, previousCursorPosition)
        guard hasChanges(text, activeCursor: cursor) else { return false }

        let columnsUnchanged = previousColumns == output.size.width
        previousColumns = output.size.width
        let lines = splitLines(text)

        if text == previousOutput && hasCursorChanged {
            emit(
                CursorHelpers.cursorOnly(
                    cursorWasShown: wasCursorShown,
                    previousLineCount: previousLines.count,
                    previousCursorPosition: previousCursorPosition,
                    cursorPosition: cursor
                )
            )
        } else {
            if incremental {
                writeIncremental(text, lines: lines, columnsUnchanged: columnsUnchanged, cursor: cursor)
            } else {
                writeStandard(text, lines: lines, cursor: cursor)
            }
            previousOutput = text
            previousLines = lines
        }
        previousCursorPosition = cursor
        wasCursorShown = cursor != nil
        return true
    }

    /// Erases the live frame and forgets it.
    func clear() {
        emit(
            CursorHelpers.eraseFrame(
                previousLineCount: previousLines.count,
                previousCursorPosition: previousCursorPosition
            )
        )
        reset()
    }

    /// Leaves the cursor below the frame, forgets the frame and shows the cursor again
    /// (unless `showCursor` is set). Call this when rendering ends.
    func done() {
        emit(
            CursorHelpers.returnToBottom(
                previousLineCount: previousLines.count,
                previousCursorPosition: previousCursorPosition
            )
        )
        reset()
        if showCursor {
            return
        }
        emit(Escape.showCursor)
        hasHiddenCursor = false
    }

    /// Forgets the frame without erasing it. The next render writes the frame in full.
    func reset() {
        previousOutput = ""
        previousLines = []
        previousCursorPosition = nil
        wasCursorShown = false
    }

    /// Records `text` as the frame already on screen, without writing it.
    /// Use this after the frame was written some other way.
    func sync(_ text: String) {
        let cursor = activeCursor()
        previousColumns = output.size.width
        previousOutput = text
        previousLines = splitLines(text)
        if cursor == nil && wasCursorShown {
            emit(Escape.hideCursor)
        }
        if cursor != nil {
            emit(CursorHelpers.suffix(bottomLine: previousLines.count - 1, cursorPosition: cursor))
        }
        previousCursorPosition = cursor
        wasCursorShown = cursor != nil
    }

    // MARK: - Private

    /// The requested cursor, but only when it was set since the last render.
    /// Stale positions must not persist after the component that set them unmounts.
    private var pendingCursor: CursorPosition? {
        cursorIsDirty ? requestedCursor : nil
    }

    /// `pendingCursor`, consumed by a render or sync, which clears the dirty flag.
    private func activeCursor() -> CursorPosition? {
        let cursor = pendingCursor
        cursorIsDirty = false
        return cursor
    }

    private func hasChanges(_ text: String, activeCursor cursor: CursorPosition?) -> Bool {
        text != previousOutput || CursorHelpers.changed(cursor, previousCursorPosition)
    }

    private func hideCursorIfNeeded() {
        guard !showCursor, !hasHiddenCursor else { return }
        emit(Escape.hideCursor)
        hasHiddenCursor = true
    }

    private func writeStandard(_ text: String, lines: [String], cursor: CursorPosition?) {
        let returnPrefix = CursorHelpers.returnToBottomPrefix(
            wasCursorShown: wasCursorShown,
            previousLineCount: previousLines.count,
            previousCursorPosition: previousCursorPosition
        )
        let suffix = CursorHelpers.suffix(bottomLine: lines.count - 1, cursorPosition: cursor)
        emit(returnPrefix + Escape.eraseLines(previousLines.count) + text + suffix)
    }

    private func writeIncremental(
        _ text: String,
        lines: [String],
        columnsUnchanged: Bool,
        cursor: CursorPosition?
    ) {
        let returnPrefix = CursorHelpers.returnToBottomPrefix(
            wasCursorShown: wasCursorShown,
            previousLineCount: previousLines.count,
            previousCursorPosition: previousCursorPosition
        )
        if text == "\n" || previousOutput.isEmpty {
            let suffix = CursorHelpers.suffix(bottomLine: lines.count - 1, cursorPosition: cursor)
            emit(returnPrefix + Escape.eraseLines(previousLines.count) + text + suffix)
            return
        }

        let visibleCount = visibleLineCount(lines, text: text)
        let previousVisible = visibleLineCount(previousLines, text: previousOutput)
        var buffer = returnPrefix
        if visibleCount < previousVisible {
            // Erase the rows the shorter frame left behind, and the trailing slot when the old frame had one.
            let extraSlot = previousOutput.hasSuffix("\n") ? 1 : 0
            buffer += Escape.eraseLines(previousVisible - visibleCount + extraSlot) + Escape.cursorUp(visibleCount)
        } else if previousLines.count > 1 {
            buffer += Escape.cursorUp(previousLines.count - 1)
        }

        let sameLineCount = columnsUnchanged && lines.count == previousLines.count
        let hasTrailingNewline = text.hasSuffix("\n")
        for index in 0..<visibleCount {
            let isLastLine = index == visibleCount - 1
            // Unchanged rows are skipped. A newline on a new row scrolls the terminal bottom.
            if index < previousVisible && lines[index] == previousLines[index] {
                if !isLastLine || hasTrailingNewline {
                    buffer += Escape.cursorNextLine
                }
                continue
            }
            let changedLine =
                sameLineCount
                ? lineUpdate(previous: previousLines[index], next: lines[index], columns: output.size.width)
                : Escape.cursorTo(0) + Escape.eraseEndLine + lines[index]
            // No newline after the last row when the text has none (fullscreen mode).
            buffer += changedLine + (isLastLine && !hasTrailingNewline ? "" : "\n")
        }
        buffer += CursorHelpers.suffix(bottomLine: lines.count - 1, cursorPosition: cursor)
        emit(buffer)
    }

    /// The number of rows `lines` shows: the trailing empty element of a text
    /// ending in a newline is not a row.
    private func visibleLineCount(_ lines: [String], text: String) -> Int {
        text.hasSuffix("\n") ? lines.count - 1 : lines.count
    }

    private func emit(_ text: String) {
        guard !text.isEmpty else { return }
        output.write(text)
    }
}

/// Splits on `\n` only, keeping a trailing empty element, as `String.split("\n")` does in JavaScript.
func splitLines(_ text: String) -> [String] {
    var lines = [""]
    for scalar in text.unicodeScalars {
        if scalar == "\n" {
            lines.append("")
        } else {
            lines[lines.count - 1].unicodeScalars.append(scalar)
        }
    }
    return lines
}
