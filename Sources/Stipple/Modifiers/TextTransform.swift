extension View {
    /// Rewrites every line of text in this view right before it is drawn,
    /// given the line (with its ANSI styling) and its index (Ink's `<Transform>`).
    /// Layout measures the untransformed text, so keep the width unchanged,
    /// e.g. for gradients or recoloring. Screen readers see the original text.
    public func textTransform(_ transform: @escaping @MainActor (_ line: String, _ index: Int) -> String) -> some View {
        environmentChange { environment in
            let outer = environment.textTransform
            environment.textTransform = { line, index in transform(outer?(line, index) ?? line, index) }
        }
    }
}

struct TextTransformKey: EnvironmentKey {
    static var defaultValue: (@MainActor (String, Int) -> String)? { nil }
}

extension EnvironmentValues {
    var textTransform: (@MainActor (String, Int) -> String)? {
        get { self[TextTransformKey.self] }
        set { self[TextTransformKey.self] = newValue }
    }
}
