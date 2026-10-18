/// Which view has keyboard focus, as a value you can read and set.
///
/// ```swift
/// enum Field { case name, email }
/// @FocusState private var focus: Field?
///
/// TextLine(...).focused($focus, equals: .name)
/// ```
///
/// With `Bool`, use `.focused($isFocused)`.
@MainActor
@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicPropertyLink {
    private let startValue: Value
    private let link = StateLink<Value>()

    /// A binding to a focus state, passed to `.focused(_:equals:)`.
    @MainActor
    public struct Binding {
        let get: @MainActor () -> Value
        let set: @MainActor (Value) -> Void

        /// The current focus value.
        public var wrappedValue: Value {
            get { get() }
            nonmutating set { set(newValue) }
        }
    }

    /// Creates focus state with an initial value. An optional focus state
    /// declared without one starts as `nil`.
    public init(wrappedValue: Value) {
        startValue = wrappedValue
    }

    /// The current value. Setting it moves focus.
    public var wrappedValue: Value {
        get { link.box?.value ?? startValue }
        nonmutating set { link.box?.value = newValue }
    }

    /// A binding for `.focused(_:equals:)`.
    public var projectedValue: Binding {
        let link = link
        let startValue = startValue
        return Binding(get: { link.box?.value ?? startValue }, set: { link.box?.value = $0 })
    }

    func install(in node: ViewNode, index: Int) {
        let startValue = startValue
        link.box = node.storage(at: index) { StateBox(startValue) }
    }
}

extension FocusState where Value == Bool {
    /// Creates focus state that starts unfocused.
    public init() {
        self.init(wrappedValue: false)
    }
}

extension View {
    /// Makes the view focusable. Tab and Shift-Tab move focus between
    /// focusable views in order; Escape clears focus. Key handlers inside a
    /// focusable view only run while it has focus.
    public func focusable(_ isFocusable: Bool = true, autoFocus: Bool = false) -> some View {
        behavior { behaviors in
            behaviors.focus = FocusRegistration(
                isEnabled: isFocusable,
                autoFocus: autoFocus,
                isRequested: { nil },
                update: { _ in },
            )
        }
    }

    /// Makes the view focusable and ties its focus to `binding`: focused
    /// while `binding` equals `value`.
    public func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> some View {
        behavior { behaviors in
            behaviors.focus = FocusRegistration(
                isEnabled: true,
                autoFocus: false,
                isRequested: { binding.wrappedValue == value },
                update: { isFocused in
                    if isFocused {
                        binding.wrappedValue = value
                    } else if binding.wrappedValue == value {
                        binding.wrappedValue = nil
                    }
                },
            )
        }
    }

    /// Makes the view focusable and ties its focus to a Boolean binding.
    public func focused(_ binding: FocusState<Bool>.Binding) -> some View {
        behavior { behaviors in
            behaviors.focus = FocusRegistration(
                isEnabled: true,
                autoFocus: false,
                isRequested: { binding.wrappedValue },
                update: { binding.wrappedValue = $0 },
            )
        }
    }
}
