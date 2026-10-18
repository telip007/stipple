/// Decides when a frame must be drawn with a full clear instead of an in-place diff.
/// Port of `shouldClearTerminalForFrame` in `ink.tsx`.
enum FullClear {
    /// The facts about the previous and next frame that the decision depends on.
    struct Context: Equatable, Sendable {
        /// Whether the output is a terminal. Non-terminals never clear.
        var isTerminal: Bool
        /// Rows in the viewport now.
        var viewportRows: Int
        /// Rows in the viewport when the previous frame was drawn.
        var previousViewportRows: Int
        /// Height of the previous frame.
        var previousOutputHeight: Int
        /// Height of the next frame.
        var nextOutputHeight: Int
        /// Whether this is the final frame, drawn on finish.
        var isFinishing: Bool
    }

    /// Whether the next frame needs a full clear.
    static func isNeeded(_ context: Context) -> Bool {
        guard context.isTerminal else { return false }
        let wasFullscreen = context.previousOutputHeight >= context.viewportRows
        let isOverflowing = context.nextOutputHeight > context.viewportRows
        let wasOverflowing = context.previousOutputHeight > context.viewportRows
        let hadPreviousFrame = context.previousOutputHeight > 0
        let isLeavingFullscreen = wasFullscreen && context.nextOutputHeight < context.viewportRows
        let isViewportShrinking = context.viewportRows < context.previousViewportRows
        // An overflowing frame has no reliable diff. A shrinking viewport moves the frame under the cursor.
        // The final frame on a fullscreen output clears once, so the terminal is not left scrolled.
        return wasOverflowing
            || (isOverflowing && hadPreviousFrame)
            || isLeavingFullscreen
            || (isViewportShrinking && wasFullscreen)
            || (context.isFinishing && wasFullscreen)
    }
}
