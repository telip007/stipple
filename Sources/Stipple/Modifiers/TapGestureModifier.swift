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
        interaction { $0.tapHandlers.append((max(1, count), action)) }
    }

    /// Calls `action` with `true` when the pointer moves onto the view and
    /// `false` when it leaves, as SwiftUI's `onHover`. Needs
    /// ``RenderOptions/mouseReporting`` and the alternate screen. While any
    /// view has a hover handler, the runtime asks the terminal for motion
    /// reports (`?1003`), so the pointer is tracked without a button held.
    public func onHover(perform action: @escaping @MainActor (Bool) -> Void) -> some View {
        interaction { $0.hoverHandlers.append(action) }
    }
}
