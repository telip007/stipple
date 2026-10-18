public import Observation

@MainActor
final class EnvironmentLink {
    var values: EnvironmentValues?
}

/// Reads a value from the environment, either by key path or, for
/// observable objects placed with `.environment(_:)`, by type.
///
/// ```swift
/// @Environment(\.exit) private var exit
/// @Environment(Model.self) private var model
/// ```
@MainActor
@propertyWrapper
public struct Environment<Value>: DynamicPropertyLink {
    private enum Source {
        case keyPath(KeyPath<EnvironmentValues, Value>)
        case object(@MainActor (EnvironmentValues) -> Value)
    }

    private let source: Source
    private let link = EnvironmentLink()

    /// Reads the environment value at `keyPath`.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        source = .keyPath(keyPath)
    }

    /// The current value. Reading it outside `body` sees the default environment.
    public var wrappedValue: Value {
        let values = link.values ?? EnvironmentValues()
        switch source {
        case .keyPath(let keyPath): return values[keyPath: keyPath]
        case .object(let read): return read(values)
        }
    }

    func install(in node: ViewNode, index: Int) {
        link.values = node.environment
    }
}

extension Environment where Value: AnyObject & Observable {
    /// Reads an observable object placed in the environment with
    /// `.environment(_:)`. Stops the program if no ancestor placed one.
    public init(_ type: Value.Type) {
        source = .object { values in
            guard let object = values.object(of: type) else {
                preconditionFailure("No \(type) in the environment; add .environment(_:) to an ancestor")
            }
            return object
        }
    }
}
