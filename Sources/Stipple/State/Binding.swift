/// A read-write reference to a value owned elsewhere, usually `@State` in an ancestor.
@MainActor
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
    private let getter: @MainActor () -> Value
    private let setter: @MainActor (Value) -> Void

    /// Creates a binding from a getter and a setter.
    public init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) {
        getter = get
        setter = set
    }

    /// Unwraps a binding passed to a view's initializer: `self._value = value`.
    public init(projectedValue: Self) {
        self = projectedValue
    }

    /// A binding that never changes.
    public static func constant(_ value: Value) -> Self {
        Self(get: { value }, set: { _ in })
    }

    /// The referenced value.
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    /// The binding itself: `$value`.
    public var projectedValue: Self { self }

    /// A binding to a property of the value: `$settings.name`.
    public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Binding<Member> {
        Binding<Member>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 },
        )
    }
}
