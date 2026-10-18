/// A key for a value stored in `EnvironmentValues`.
public protocol EnvironmentKey {
    /// The value's type.
    associatedtype Value
    /// The value when no ancestor set one.
    static var defaultValue: Value { get }
}

/// Values that flow down the view hierarchy. Extend it with computed
/// properties over your own `EnvironmentKey`s, as in SwiftUI.
public struct EnvironmentValues {
    private var values: [ObjectIdentifier: Any] = [:]
    private var objects: [ObjectIdentifier: AnyObject] = [:]

    /// Creates an environment with every key at its default.
    public init() {}

    /// Reads or writes the value for `key`.
    public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
        get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }

    func object<Object: AnyObject>(of type: Object.Type) -> Object? {
        objects[ObjectIdentifier(type)] as? Object
    }

    mutating func setObject<Object: AnyObject>(_ object: Object?) {
        objects[ObjectIdentifier(Object.self)] = object
    }
}
