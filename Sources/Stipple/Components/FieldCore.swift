/// One line of a text field as it is shown: the cells of the text, or of the
/// placeholder while the text is empty, and where the caret is.
struct FieldLine: Equatable {
    /// The cells shown, in order.
    let cells: [FieldCell]
    /// The cell under the caret; `cells.count` puts it after the last cell.
    let cursor: Int
    /// Whether the placeholder is shown.
    let isPlaceholder: Bool

    init(text: String, placeholder: String, isSecure: Bool, cursor: Int) {
        isPlaceholder = text.isEmpty
        let shown: String
        if isPlaceholder {
            shown = placeholder
        } else if isSecure {
            shown = String(repeating: "*", count: text.count)
        } else {
            shown = text
        }
        cells = FieldCell.cells(of: shown)
        // The caret sits on the placeholder's first character, whatever the offset.
        self.cursor = isPlaceholder ? 0 : min(max(cursor, 0), cells.count)
    }

    /// The part of the line that fits in `width` columns, scrolled so the caret stays visible.
    func window(width: Int) -> FieldWindow {
        let end = cells.last.map { $0.column + $0.width } ?? 0
        let caretColumn = cursor < cells.count ? cells[cursor].column : end
        let start = max(0, caretColumn - width + 1)
        let visible = cells.indices.filter { cells[$0].column >= start && cells[$0].column < start + width }
        return FieldWindow(
            before: visible.filter { $0 < cursor }.map { cells[$0] },
            current: cursor < cells.count && visible.contains(cursor) ? cells[cursor] : nil,
            after: visible.filter { $0 > cursor }.map { cells[$0] },
            caretColumn: max(0, caretColumn - start))
    }
}

/// A character cell of a text field: its text, the column it starts at and its width.
struct FieldCell: Equatable {
    let text: String
    let column: Int
    let width: Int

    /// The cells of `string`, one per grapheme cluster.
    static func cells(of string: String) -> [Self] {
        var column = 0
        var cells: [Self] = []
        for character in string {
            let text = String(character)
            let width = TextMetrics.width(of: text)
            cells.append(Self(text: text, column: column, width: width))
            column += width
        }
        return cells
    }
}

/// The visible part of a ``FieldLine``.
struct FieldWindow: Equatable {
    /// Visible cells left of the caret.
    let before: [FieldCell]
    /// The visible cell under the caret, or `nil` when the caret is past the end.
    let current: FieldCell?
    /// Visible cells right of the caret.
    let after: [FieldCell]
    /// The caret's column, relative to the window's left edge.
    let caretColumn: Int
}

/// The primitive a text field draws with. It carries the focus registration and
/// key handler on the same node, so focus and keys stay together.
struct FieldCore: View, PrimitiveView {
    let line: FieldLine
    let focus: FocusRegistration?
    let handleKey: @MainActor (KeyPress) -> KeyPress.Result
    let handlePaste: @MainActor (String) -> Void

    /// Never called: the field is a built-in view.
    typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = FieldLayout(line: line)
        node.behaviors.focus =
            focus
            ?? FocusRegistration(
                isEnabled: true, autoFocus: false, isRequested: { nil }, update: { _ in })
        node.behaviors.keyHandlers.append(handleKey)
        node.behaviors.pasteHandlers.append(handlePaste)
        return []
    }
}

/// Lays out one line and draws it, with the caret inverted while the field has focus.
struct FieldLayout: NodeLayout {
    let line: FieldLine

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        // One column past the text is where the caret sits at the end.
        let ideal = line.cells.reduce(0) { $0 + $1.width } + 1
        return Size(width: proposal.width.map { min($0, ideal) } ?? ideal, height: 1)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        // The terminal cursor goes to the caret, so input methods place their candidates there.
        node.behaviors.cursorPosition =
            Self.isFocused(node)
            ? Point(x: line.window(width: bounds.size.width).caretColumn, y: 0) : nil
    }

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        let frame = node.frame
        let window = line.window(width: frame.size.width)
        let base = node.environment.textStyle.resolved(background: node.environment.inheritedBackground)
        var plain = base
        if line.isPlaceholder {
            plain.attributes.insert(.dim)
        }
        let runs: [StyledRun]
        if Self.isFocused(node) {
            var caret = base
            caret.attributes.insert(.inverse)
            runs = [
                StyledRun(text: Self.joined(window.before), style: plain),
                StyledRun(text: window.current?.text ?? " ", style: caret),
                StyledRun(text: Self.joined(window.after), style: plain),
            ]
        } else {
            runs = [
                StyledRun(
                    text: Self.joined(window.before + (window.current.map { [$0] } ?? []) + window.after), style: plain)
            ]
        }
        canvas.write(runs, at: Point(x: frame.minX, y: frame.minY), clip: clip)
    }

    private static func isFocused(_ node: ViewNode) -> Bool {
        node.graph.focus.focusedNode === node
    }

    private static func joined(_ cells: [FieldCell]) -> String {
        cells.map(\.text).joined()
    }
}
