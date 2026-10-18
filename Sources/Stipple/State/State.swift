public import Observation

/// Observable storage behind `@State`; lives in the view's node.
@MainActor
final class StateBox<Value>: Observable {
    private let registrar = ObservationRegistrar()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        get {
            registrar.access(self, keyPath: \.value)
            return storage
        }
        set {
            registrar.withMutation(of: self, keyPath: \.value) { storage = newValue }
        }
    }
}

/// Holds the node-owned box once a view is installed.
@MainActor
final class StateLink<Value> {
    var box: StateBox<Value>?
}

/// State owned by a view. Changing it re-evaluates the bodies that read it.
///
/// ```swift
/// @State private var count = 0
/// ```
@MainActor
@propertyWrapper
public struct State<Value>: DynamicPropertyLink {
    private let initialValue: Value
    private let link = StateLink<Value>()

    /// Creates state with an initial value.
    public init(wrappedValue: Value) {
        initialValue = wrappedValue
    }

    /// Creates state with an initial value.
    public init(initialValue: Value) {
        self.initialValue = initialValue
    }

    /// The current value. Reading it outside `body` (e.g. in `init`) sees
    /// the initial value.
    public var wrappedValue: Value {
        get { link.box?.value ?? initialValue }
        nonmutating set {
            if let box = link.box {
                box.value = newValue
            }
        }
    }

    /// A binding to the value, for child views: `$count`.
    public var projectedValue: Binding<Value> {
        let link = link
        let initialValue = initialValue
        return Binding(get: { link.box?.value ?? initialValue }, set: { link.box?.value = $0 })
    }

    func install(in node: ViewNode, index: Int) {
        let initialValue = initialValue
        link.box = node.storage(at: index) { StateBox(initialValue) }
    }
}

extension State where Value: ExpressibleByNilLiteral {
    /// Creates optional state that starts as `nil`.
    public init() {
        self.init(wrappedValue: nil)
    }
}
