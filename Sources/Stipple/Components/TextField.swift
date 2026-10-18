/// A single-line text input, as SwiftUI's `TextField`.
///
/// The field is focusable: Tab moves to it, and its key handling runs only
/// while it has focus. Pass `.focusable(autoFocus: true)` to focus it when it
/// first appears, or tie focus to a `@FocusState` with `.focused(_:equals:)`.
/// Return calls the action from ``View/onSubmit(_:)`` of an ancestor.
///
/// Editing keys follow readline. Ctrl-D deletes the character after the
/// insertion point, except when the text is empty: then the field leaves it
/// unhandled, so an ancestor's `.onKeyPress` can treat it as end-of-file.
///
/// When the bound text is changed from outside, for example cleared in
/// `onSubmit` or replaced with a history entry, the insertion point moves to
/// the end of the new text.
///
/// ```swift
/// @State private var name = ""
/// TextField("Name", text: $name)
///     .focusable(autoFocus: true)
///     .onSubmit { save(name) }
/// ```
///
/// The terminal cursor sits at the insertion point, so input methods work, and
/// the character under it is drawn inverted, as Ink's text input does.
public struct TextField: View {
    let placeholder: String
    let text: Binding<String>
    let isSecure: Bool
    var focus: FocusRegistration?

    /// Creates a text field. The placeholder is dimmed while the text is empty.
    public init(_ placeholder: String, text: Binding<String>) {
        self.init(placeholder: placeholder, text: text, isSecure: false)
    }

    init(placeholder: String, text: Binding<String>, isSecure: Bool) {
        self.placeholder = placeholder
        self.text = text
        self.isSecure = isSecure
    }

    /// The field's contents, built from its text and focus.
    public var body: some View {
        EditableText(placeholder: placeholder, text: text, isSecure: isSecure, focus: focus)
    }

    /// Makes the field focusable, or not. With `autoFocus`, it takes focus when it first appears
    /// if nothing else has focus.
    public func focusable(_ isFocusable: Bool = true, autoFocus: Bool = false) -> Self {
        updatingFocus { registration in
            registration.isEnabled = isFocusable
            registration.autoFocus = autoFocus
        }
    }

    /// Ties focus to `binding`: the field is focused while the binding equals `value`.
    public func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> Self {
        updatingFocus { registration in
            registration.isRequested = { binding.wrappedValue == value }
            registration.update = { isFocused in
                if isFocused {
                    binding.wrappedValue = value
                } else if binding.wrappedValue == value {
                    binding.wrappedValue = nil
                }
            }
        }
    }

    /// Ties focus to a Boolean binding: the field is focused while it is `true`.
    public func focused(_ binding: FocusState<Bool>.Binding) -> Self {
        updatingFocus { registration in
            registration.isRequested = { binding.wrappedValue }
            registration.update = { binding.wrappedValue = $0 }
        }
    }

    private func updatingFocus(_ change: (inout FocusRegistration) -> Void) -> Self {
        var copy = self
        var registration =
            copy.focus
            ?? FocusRegistration(
                isEnabled: true, autoFocus: false, isRequested: { nil }, update: { _ in })
        change(&registration)
        copy.focus = registration
        return copy
    }
}

/// A single-line text input that shows each character as `*`, as SwiftUI's `SecureField`.
///
/// It takes the same focus modifiers as ``TextField``.
public struct SecureField: View {
    var field: TextField

    /// Creates a secure field. The placeholder is dimmed while the text is empty.
    public init(_ placeholder: String, text: Binding<String>) {
        field = TextField(placeholder: placeholder, text: text, isSecure: true)
    }

    /// The field's contents, built from the wrapped text field.
    public var body: some View {
        field
    }

    /// Makes the field focusable, or not. See ``TextField/focusable(_:autoFocus:)``.
    public func focusable(_ isFocusable: Bool = true, autoFocus: Bool = false) -> Self {
        var copy = self
        copy.field = field.focusable(isFocusable, autoFocus: autoFocus)
        return copy
    }

    /// Ties focus to `binding`. See ``TextField/focused(_:equals:)``.
    public func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> Self {
        var copy = self
        copy.field = field.focused(binding, equals: value)
        return copy
    }

    /// Ties focus to a Boolean binding. See ``TextField/focused(_:)``.
    public func focused(_ binding: FocusState<Bool>.Binding) -> Self {
        var copy = self
        copy.field = field.focused(binding)
        return copy
    }
}

extension View {
    /// Calls `action` when Return is pressed in a text field inside this view, as SwiftUI's `onSubmit`.
    public func onSubmit(_ action: @escaping @MainActor () -> Void) -> some View {
        environmentChange { $0.submitAction = action }
    }
}

struct SubmitActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}

extension EnvironmentValues {
    /// The action from the nearest ``View/onSubmit(_:)``, if any.
    var submitAction: (@MainActor () -> Void)? {
        get { self[SubmitActionKey.self] }
        set { self[SubmitActionKey.self] = newValue }
    }
}
