@testable import Stipple

/// Helpers for porting Ink's `renderToString` tests. Ink's test renderer is 100 columns wide.
@MainActor
func render(_ view: some View, width: Int = 100) -> String {
    Stipple.renderToString(view, width: width)
}

/// Output with all ANSI escapes removed (Ink tests use `strip-ansi`).
@MainActor
func plain(_ view: some View, width: Int = 100) -> String {
    ANSIText.parse(render(view, width: width)).map(\.text).joined()
}

/// Whether `output` and `expected` (written with chalk-style escapes) draw the same
/// styled text. Compares runs, so combined and separate SGR sequences are equal.
func sameStyledText(_ output: String, _ expected: String) -> Bool {
    ANSIText.parse(output) == ANSIText.parse(expected)
}
