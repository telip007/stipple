/// The stateful part of a text field: it owns the insertion point and turns
/// key presses and pastes into edits of the bound text.
struct EditableText: View {
    let placeholder: String
    let text: Binding<String>
    let isSecure: Bool
    let focus: FocusRegistration?
    @State private var cursor = 0
    @Environment(\.submitAction) private var submitAction

    init(placeholder: String, text: Binding<String>, isSecure: Bool, focus: FocusRegistration?) {
        self.placeholder = placeholder
        self.text = text
        self.isSecure = isSecure
        self.focus = focus
    }

    var body: some View {
        let value = text.wrappedValue
        let cursorBinding = $cursor
        let textBinding = text
        let submit = submitAction
        return FieldCore(
            line: FieldLine(text: value, placeholder: placeholder, isSecure: isSecure, cursor: cursor),
            focus: focus,
            handleKey: { press in
                guard let command = TextEditing.Command(press) else { return .ignored }
                if command == .submit {
                    submit?()
                } else {
                    Self.edit(command, text: textBinding, cursor: cursorBinding)
                }
                return .handled
            },
            handlePaste: { pasted in
                Self.edit(.insert(pasted), text: textBinding, cursor: cursorBinding)
            })
    }

    /// Applies `command` to the bound text and cursor, writing only what changed.
    private static func edit(_ command: TextEditing.Command, text: Binding<String>, cursor: Binding<Int>) {
        var editing = TextEditing(text: text.wrappedValue, cursor: cursor.wrappedValue)
        editing.apply(command)
        if editing.text != text.wrappedValue {
            text.wrappedValue = editing.text
        }
        if editing.cursor != cursor.wrappedValue {
            cursor.wrappedValue = editing.cursor
        }
    }
}
