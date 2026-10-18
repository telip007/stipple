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
    /// Which values these are: environments sharing a revision hold the same
    /// values. Setting a value derives the next revision, and setting an equal
    /// value on the same revision again derives the same one, so a modifier
    /// that rebuilds hands its children an identical environment.
    private var revision = Revision()

    /// Creates an environment with every key at its default.
    public init() {}

    /// Reads or writes the value for `key`.
    public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
        get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
        set {
            let id = ObjectIdentifier(key)
            if let old = values[id], areEqual(old, newValue) { return }
            values[id] = newValue
            revision = revision.setting(id, to: newValue, isSame: areEqual)
        }
    }

    /// Whether `other` is known to hold the same values: a cheap check that
    /// can answer `false` for equal environments built separately.
    func isIdentical(to other: Self) -> Bool {
        revision === other.revision
    }

    func object<Object: AnyObject>(of type: Object.Type) -> Object? {
        objects[ObjectIdentifier(type)] as? Object
    }

    mutating func setObject<Object: AnyObject>(_ object: Object?) {
        let id = ObjectIdentifier(Object.self)
        guard objects[id] !== object else { return }
        objects[id] = object
        revision = revision.setting(id, to: object as Any) { ($0 as? Object) === ($1 as? Object) }
    }
}

/// The identity of one set of environment values.
private final class Revision {
    /// The revisions derived from this one, the last one per key.
    private var derived: [ObjectIdentifier: (value: Any, revision: Revision)] = [:]

    /// The revision for these values with `key` set to `value`.
    func setting(_ key: ObjectIdentifier, to value: Any, isSame: (Any, Any) -> Bool) -> Revision {
        if let last = derived[key], isSame(last.value, value) { return last.revision }
        let next = Revision()
        derived[key] = (value, next)
        return next
    }
}

/// Whether `lhs` and `rhs` are equal values of the same `Equatable` type;
/// `false` for anything else.
func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard let lhs = lhs as? any Equatable else { return false }
    return lhs.isEqual(to: rhs)
}

extension Equatable {
    fileprivate func isEqual(to other: Any) -> Bool {
        (other as? Self) == self
    }
}
