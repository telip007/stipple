/// A list where one row is selected and the keyboard moves the selection, as in
/// Ink's `ink-select-input`.
///
/// The list is focusable. While it has focus, ↑/↓ (or k/j) move the selection,
/// Home and End jump to the ends, and Enter calls `onSubmit` with the selected
/// element. The selected row shows a `›`. With `visibleRows` set, the list shows
/// that many rows and scrolls to keep the selection in view. With
/// ``RenderOptions/mouseReporting`` on the alternate screen, a click on a row
/// focuses the list and selects the row, and a double-click submits it.
///
/// ```swift
/// @State private var choice: Fruit.ID?
///
/// SelectionList(fruits, selection: $choice, visibleRows: 5) { fruit in
///     Text(fruit.name)
/// }
/// ```
///
/// `selection` is `nil` until the user picks something; the first arrow key
/// then selects the first row (or the last, for ↑).
public struct SelectionList<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let selection: Binding<ID?>
    private let visibleRows: Int?
    private let autoFocus: Bool
    private let onSubmit: (@MainActor (Data.Element) -> Void)?
    @Environment(\.submitAction) private var submitAction
    private let row: @MainActor (Data.Element) -> Row
    @State private var scrollOffset = 0

    /// Creates a list whose elements are identified by `id`.
    /// - Parameters:
    ///   - data: The choices, in display order.
    ///   - id: The key path to each element's identifier.
    ///   - selection: The identifier of the selected element, or `nil`.
    ///   - visibleRows: How many rows to show at once. Nil shows them all.
    ///   - autoFocus: Whether the list takes focus when it appears.
    ///   - onSubmit: Called with the selected element when Enter is pressed.
    ///   - row: The content of one row.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<ID?>,
        visibleRows: Int? = nil,
        autoFocus: Bool = true,
        onSubmit: (@MainActor (Data.Element) -> Void)? = nil,
        @ViewBuilder row: @escaping @MainActor (Data.Element) -> Row
    ) {
        self.data = data
        self.id = id
        self.selection = selection
        self.visibleRows = visibleRows
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.row = row
    }

    /// The list's rows: the visible window, with the selected row marked.
    public var body: some View {
        let items = Array(data)
        let selected = selectedPosition(in: items)
        let window = visibleWindow(count: items.count, selected: selected)
        VStack(alignment: .leading) {
            ForEach(window) { position in
                rowView(items[position], isSelected: position == selected)
            }
        }
        .focusable(true, autoFocus: autoFocus)
        .onKeyPress(keys: [.upArrow, .character("k")]) { _ in moveSelection(by: -1) }
        .onKeyPress(keys: [.downArrow, .character("j")]) { _ in moveSelection(by: 1) }
        .onKeyPress(.home) { jumpSelection(to: 0) }
        .onKeyPress(.end) { jumpSelection(to: Int.max) }
        .onKeyPress(.return) { submitSelection() }
    }

    // The key handlers read the selection when the key arrives, not when the
    // view was built, so keys pressed before a redraw still act on the latest selection.

    /// Moves one row up or down from the current selection. With nothing selected,
    /// ↓ picks the first row and ↑ the last.
    private func moveSelection(by delta: Int) -> KeyPress.Result {
        let items = Array(data)
        let target = selectedPosition(in: items).map { $0 + delta } ?? (delta > 0 ? 0 : items.count - 1)
        return select(target, in: items)
    }

    /// Selects `position`, or the last row when `position` is past the end.
    private func jumpSelection(to position: Int) -> KeyPress.Result {
        let items = Array(data)
        return select(min(position, items.count - 1), in: items)
    }

    /// Calls `onSubmit` with the selected element, if there is one.
    private func submitSelection() -> KeyPress.Result {
        let items = Array(data)
        guard let position = selectedPosition(in: items) else { return .ignored }
        if let onSubmit {
            onSubmit(items[position])
        } else {
            submitAction?()
        }
        return .handled
    }

    private func rowView(_ item: Data.Element, isSelected: Bool) -> some View {
        let itemID = item[keyPath: id]
        return HStack(spacing: 1) {
            Text(isSelected ? "›" : " ").foregroundStyle(.cyan)
            if isSelected {
                row(item).foregroundStyle(.cyan).bold()
            } else {
                row(item)
            }
        }
        .onTapGesture { selectClicked(itemID) }
        .onTapGesture(count: 2) {
            selectClicked(itemID)
            _ = submitSelection()
        }
    }

    /// Selects the row with `itemID`, for a click.
    private func selectClicked(_ itemID: ID) {
        let items = Array(data)
        guard let position = items.firstIndex(where: { $0[keyPath: id] == itemID }) else { return }
        _ = select(position, in: items)
    }

    /// The position of the selected element, or nil when nothing is selected.
    private func selectedPosition(in items: [Data.Element]) -> Int? {
        guard let selected = selection.wrappedValue else { return nil }
        return items.firstIndex { $0[keyPath: id] == selected }
    }

    /// The rows to draw. Without a limit, all of them.
    private func visibleWindow(count: Int, selected: Int?) -> Range<Int> {
        guard let limit = visibleRows.map({ max($0, 1) }), limit < count else { return 0..<count }
        let start = Self.scrolledStart(offset: scrollOffset, selected: selected, count: count, limit: limit)
        return start..<(start + limit)
    }

    /// Selects `position`, clamped to the list, and scrolls so that it stays visible.
    private func select(_ position: Int, in items: [Data.Element]) -> KeyPress.Result {
        guard !items.isEmpty else { return .ignored }
        let clamped = min(max(position, 0), items.count - 1)
        selection.wrappedValue = items[clamped][keyPath: id]
        if let visibleRows {
            scrollOffset = Self.scrolledStart(
                offset: scrollOffset, selected: clamped, count: items.count, limit: max(visibleRows, 1))
        }
        return .handled
    }

    /// The first visible row for a window of `limit` rows that must show `selected`.
    /// The offset moves only as far as needed, as Ink's select input does.
    static func scrolledStart(offset: Int, selected: Int?, count: Int, limit: Int) -> Int {
        var start = min(max(offset, 0), max(count - limit, 0))
        if let selected {
            if selected < start { start = selected }
            if selected >= start + limit { start = selected - limit + 1 }
        }
        return start
    }
}

extension SelectionList where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates a list of identifiable elements, identified by their `id`.
    public init(
        _ data: Data,
        selection: Binding<ID?>,
        visibleRows: Int? = nil,
        autoFocus: Bool = true,
        onSubmit: (@MainActor (Data.Element) -> Void)? = nil,
        @ViewBuilder row: @escaping @MainActor (Data.Element) -> Row
    ) {
        self.init(
            data,
            id: \Data.Element.id,
            selection: selection,
            visibleRows: visibleRows,
            autoFocus: autoFocus,
            onSubmit: onSubmit,
            row: row
        )
    }
}
