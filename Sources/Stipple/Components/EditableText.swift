/// The stateful part of a text field: it owns the insertion point and turns
/// key presses and pastes into edits of the bound text.
struct EditableText: View {
    let placeholder: String
    let text: Binding<String>
    let isSecure: Bool
    let focus: FocusRegistration?
    @State private var cursor = 0
    /// The text as the field last saw it: its initial value, then the result
    /// of each of its own edits. Any other value means the binding was changed from outside.
    @State private var editedText: String
    @Environment(\.submitAction) private var submitAction

    init(placeholder: String, text: Binding<String>, isSecure: Bool, focus: FocusRegistration?) {
        self.placeholder = placeholder
        self.text = text
        self.isSecure = isSecure
        self.focus = focus
        _editedText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        let value = text.wrappedValue
        let state = EditState(text: text, cursor: $cursor, editedText: $editedText)
        let submit = submitAction
        return FieldCore(
            line: FieldLine(text: value, placeholder: placeholder, isSecure: isSecure, cursor: state.current),
            focus: focus,
            handleKey: { press in
                guard let command = TextEditing.Command(press) else { return .ignored }
                // As in readline, Ctrl-D on an empty line is end-of-file: let ancestors handle it.
                if state.text.wrappedValue.isEmpty, TextEditing.Command.isEndOfFile(press) { return .ignored }
                if command == .submit {
                    submit?()
                } else {
                    state.apply(command)
                }
                return .handled
            },
            handlePaste: { pasted in
                state.apply(.insert(pasted))
            })
    }
}

/// The bindings an edit writes to, and the insertion point it starts from.
@MainActor
private struct EditState {
    let text: Binding<String>
    let cursor: Binding<Int>
    let editedText: Binding<String>

    /// The insertion point: the stored one, or after an outside change (a cleared
    /// input, a recalled history entry) the end of the new text, as in SwiftUI and shells.
    /// Read live, so several keys handled before the next redraw see each other's edits.
    var current: Int {
        let value = text.wrappedValue
        return editedText.wrappedValue == value ? cursor.wrappedValue : value.count
    }

    /// Applies `command` to the bound text and cursor, writing only what changed.
    func apply(_ command: TextEditing.Command) {
        var editing = TextEditing(text: text.wrappedValue, cursor: current)
        editing.apply(command)
        if editing.text != text.wrappedValue {
            text.wrappedValue = editing.text
        }
        if editing.cursor != cursor.wrappedValue {
            cursor.wrappedValue = editing.cursor
        }
        if editedText.wrappedValue != editing.text {
            editedText.wrappedValue = editing.text
        }
    }
}
