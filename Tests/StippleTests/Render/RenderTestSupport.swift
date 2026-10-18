@testable import Stipple

/// `ESC`, to keep escape sequences in tests readable.
let esc = "\u{1B}"

func run(_ text: String, _ style: Style = .plain) -> StyledRun {
    StyledRun(text: text, style: style)
}

/// The text of each line, styles dropped.
func texts(_ lines: [[StyledRun]]) -> [String] {
    lines.map { $0.map(\.text).joined() }
}

func text(_ runs: [StyledRun]) -> String {
    runs.map(\.text).joined()
}

extension Style {
    static let red = Self(foreground: .red)
    static let blue = Self(foreground: .blue)
    static let onBlue = Self(background: .blue)
    static let onRed = Self(background: .red)
    static let onGreen = Self(background: .green)
}
