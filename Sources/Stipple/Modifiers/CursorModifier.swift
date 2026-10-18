extension View {
    /// Shows the terminal cursor at `position` (column, row) relative to this
    /// view's top-left corner, or hides it with `nil` (Ink's `useCursor`).
    /// Input methods (IME) draw their candidate window at the cursor, so
    /// text inputs should place it at the insertion point.
    public func cursorPosition(_ position: Point?) -> some View {
        modified { node, _ in
            node.layout = PassThroughLayout()
            node.behaviors.cursorPosition = position
        }
    }
}
