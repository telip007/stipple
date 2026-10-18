struct TextStyleKey: EnvironmentKey {
    static let defaultValue = TextStyle()
}

struct InheritedBackgroundKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

struct LineLimitKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

struct TruncationModeKey: EnvironmentKey {
    static let defaultValue = TruncationMode.tail
}

struct MultilineTextAlignmentKey: EnvironmentKey {
    static let defaultValue = TextAlignment.leading
}

extension EnvironmentValues {
    /// Text styling set by style modifiers on ancestors.
    var textStyle: TextStyle {
        get { self[TextStyleKey.self] }
        set { self[TextStyleKey.self] = newValue }
    }

    /// The background color painted behind this view by an ancestor's `.background(_:)`.
    var inheritedBackground: Color? {
        get { self[InheritedBackgroundKey.self] }
        set { self[InheritedBackgroundKey.self] = newValue }
    }

    /// The maximum number of lines text may take; `nil` for no limit.
    public var lineLimit: Int? {
        get { self[LineLimitKey.self] }
        set { self[LineLimitKey.self] = newValue }
    }

    /// Where text that doesn't fit is shortened.
    public var truncationMode: TruncationMode {
        get { self[TruncationModeKey.self] }
        set { self[TruncationModeKey.self] = newValue }
    }

    /// How lines of multi-line text align.
    public var multilineTextAlignment: TextAlignment {
        get { self[MultilineTextAlignmentKey.self] }
        set { self[MultilineTextAlignmentKey.self] = newValue }
    }
}
