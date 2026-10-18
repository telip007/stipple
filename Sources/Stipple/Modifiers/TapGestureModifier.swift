extension View {
    /// Calls `action` when the view is clicked `count` times in a row, as
    /// SwiftUI's `onTapGesture`. Needs ``RenderOptions/mouseReporting`` and
    /// the alternate screen, where the runtime knows which cell is under the
    /// pointer. A click is a left-button press and release on the same view;
    /// presses within half a second on the same cell count as one series.
    /// The innermost view under the pointer that has a tap handler gets the
    /// click. For each count only the innermost handler runs, so a tap on a
    /// view inside a tappable row doesn't also tap the row.
    public func onTapGesture(count: Int = 1, perform action: @escaping @MainActor () -> Void) -> some View {
        modified { node, _ in
            // A layout gives the node a frame of its own to hit-test.
            node.layout = PassThroughLayout()
            if node.environment.isEnabled { node.behaviors.tapHandlers.append((max(1, count), action)) }
        }
    }
}
