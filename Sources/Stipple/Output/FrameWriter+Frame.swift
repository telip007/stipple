/// The frame drawing behind `FrameWriter`: debug, non-interactive and interactive frames,
/// full clears and static output. Port of `renderFrame` and `renderInteractiveFrame` in `ink.tsx`.
extension FrameWriter {
    var shouldSynchronize: Bool {
        interactive && output.isTerminal
    }

    func write(_ frame: Frame) {
        guard !isFinished else { return }
        // After a clear the drawn frame is gone, so the next frame is drawn even when unchanged.
        if lastOutputHeight == 0, !lastOutput.isEmpty, !isUnmounting {
            lastOutputToRender = ""
        }
        if options.debug {
            renderDebug(frame)
        } else if !interactive {
            renderNonInteractive(frame)
        } else {
            if !frame.staticOutput.isEmpty {
                hasRenderedStaticOutput = true
                if alternateScreen {
                    fullStaticOutput += frame.staticOutput
                }
            }
            renderInteractive(frame)
        }
    }

    /// Debug mode: append the static output and the frame in full.
    func renderDebug(_ frame: Frame) {
        if !frame.staticOutput.isEmpty {
            fullStaticOutput += frame.staticOutput
            hasRenderedStaticOutput = true
        }
        lastOutput = frame.text
        lastOutputToRender = frame.text
        lastOutputHeight = frame.height
        emit(fullStaticOutput + frame.text)
    }

    /// Non-interactive mode writes no escapes. Static output is written as it comes,
    /// and the frame is kept for finish.
    func renderNonInteractive(_ frame: Frame) {
        emit(frame.staticOutput)
        lastOutput = frame.text
        lastOutputToRender = frame.text + "\n"
        lastOutputHeight = frame.height
    }

    func renderInteractive(_ frame: Frame) {
        let isTerminal = output.isTerminal
        let viewportRows = isTerminal ? output.size.height : 24
        let outputToRender = isTerminal && frame.height >= viewportRows ? frame.text : frame.text + "\n"
        let shouldClear = FullClear.isNeeded(
            FullClear.Context(
                isTerminal: isTerminal,
                viewportRows: viewportRows,
                previousViewportRows: lastTerminalHeight,
                previousOutputHeight: lastOutputHeight,
                nextOutputHeight: frame.height,
                isFinishing: isUnmounting
            )
        )
        let previousViewportRows = lastTerminalHeight
        lastTerminalHeight = viewportRows

        if !shouldClear, frame.staticOutput.isEmpty, outputToRender == lastOutputToRender, !log.isCursorDirty {
            return
        }

        log.setCursorPosition(cursorPosition)
        if shouldClear {
            redrawFully(
                frame, outputToRender: outputToRender, viewportRows: viewportRows,
                previousViewportRows: previousViewportRows)
        } else if frame.staticOutput.isEmpty {
            drawLive(outputToRender)
        } else {
            drawWithStatic(frame, outputToRender: outputToRender)
        }
        lastOutput = frame.text
        lastOutputToRender = outputToRender
        lastOutputHeight = frame.height
    }

    /// Erases the previous frame in one step, then draws the static output and the frame.
    func redrawFully(
        _ frame: Frame,
        outputToRender: String,
        viewportRows: Int,
        previousViewportRows: Int
    ) {
        let sync = shouldSynchronize
        if sync {
            emit(Escape.beginSynchronizedUpdate)
        }
        if alternateScreen {
            // The alternate screen has no scrollback, so the static output is replayed with the frame.
            emit(Escape.homeAndEraseDown + fullStaticOutput + outputToRender)
        } else if lastOutputHeight >= viewportRows {
            let prefix = eraseFramePrefix(viewportRows: viewportRows, previousViewportRows: previousViewportRows)
            emit(prefix + frame.staticOutput + outputToRender)
        } else {
            // The previous frame covers the bottom of the viewport only. Erase it relative to the cursor.
            log.clear()
            emit(frame.staticOutput + outputToRender)
        }
        log.sync(outputToRender)
        if sync {
            emit(Escape.endSynchronizedUpdate)
        }
    }

    /// The escape that erases a frame which filled the viewport. It starts at the
    /// absolute origin, or walks up from the committed cursor when the terminal lost rows.
    func eraseFramePrefix(viewportRows: Int, previousViewportRows: Int) -> String {
        guard let previousCursor = log.cursorPosition, viewportRows < previousViewportRows else {
            return Escape.homeAndEraseDown
        }
        let up = previousCursor.y > 0 ? Escape.cursorUp(previousCursor.y) : ""
        return up + Escape.cursorTo(0) + Escape.eraseDown
    }

    func drawWithStatic(_ frame: Frame, outputToRender: String) {
        let sync = shouldSynchronize
        if sync {
            emit(Escape.beginSynchronizedUpdate)
        }
        log.clear()
        emit(frame.staticOutput)
        log.render(outputToRender)
        if sync {
            emit(Escape.endSynchronizedUpdate)
        }
    }

    func drawLive(_ outputToRender: String) {
        // Synchronized output only brackets a write that changes the screen.
        let sync = shouldSynchronize && log.willRender(outputToRender)
        if sync {
            emit(Escape.beginSynchronizedUpdate)
        }
        log.render(outputToRender)
        if sync {
            emit(Escape.endSynchronizedUpdate)
        }
    }

    /// Redraws the frame after console output was written above it.
    func restoreLastOutput() {
        log.setCursorPosition(cursorPosition)
        log.render(lastOutputToRender.isEmpty ? lastOutput + "\n" : lastOutputToRender)
    }

    func emit(_ text: String) {
        guard !text.isEmpty else { return }
        output.write(text)
    }
}
