import Testing

@testable import Stipple

/// One detection example: an environment, whether stdout is a terminal, and the expected depth.
struct Detection: Sendable {
    let environment: [String: String]
    let isTerminal: Bool
    let expected: ColorDepth

    init(_ environment: [String: String], _ isTerminal: Bool, _ expected: ColorDepth) {
        self.environment = environment
        self.isTerminal = isTerminal
        self.expected = expected
    }
}

@Suite struct ColorDepthTests {
    // MARK: detection

    @Test(
        arguments: [
            Detection([:], true, .monochrome),
            Detection([:], false, .monochrome),
            Detection(["FORCE_COLOR": "0", "COLORTERM": "truecolor"], true, .monochrome),
            Detection(["FORCE_COLOR": "false"], true, .monochrome),
            Detection(["FORCE_COLOR": "1"], false, .ansi16),
            Detection(["FORCE_COLOR": "2", "COLORTERM": "truecolor"], true, .ansi256),
            Detection(["FORCE_COLOR": "3"], false, .trueColor),
            Detection(["FORCE_COLOR": "7"], false, .trueColor),
            Detection(["FORCE_COLOR": "true"], false, .ansi16),
            Detection(["FORCE_COLOR": "true", "TERM": "dumb"], false, .ansi16),
            Detection(["FORCE_COLOR": "", "COLORTERM": "truecolor"], false, .trueColor),
            Detection(["FORCE_COLOR": "high", "TERM": "xterm"], false, .monochrome),
            Detection(["NO_COLOR": "1", "COLORTERM": "truecolor"], true, .monochrome),
            Detection(["NO_COLOR": "", "TERM": "xterm"], true, .ansi16),
            Detection(["NO_COLOR": "1", "FORCE_COLOR": "2"], true, .ansi256),
            Detection(["TF_BUILD": "1", "AGENT_NAME": "a"], false, .ansi16),
            Detection(["TERM": "dumb", "COLORTERM": "truecolor"], true, .monochrome),
            Detection(["CI": "true", "GITHUB_ACTIONS": "true"], true, .trueColor),
            Detection(["CI": "true", "GITLAB_CI": "true"], true, .ansi16),
            Detection(["CI": "true", "CI_NAME": "codeship"], true, .ansi16),
            Detection(["CI": "true", "TERM": "xterm-256color"], true, .monochrome),
            Detection(["TEAMCITY_VERSION": "2023.1.1"], true, .ansi16),
            Detection(["TEAMCITY_VERSION": "9.0.5"], true, .monochrome),
            Detection(["COLORTERM": "truecolor"], true, .trueColor),
            Detection(["COLORTERM": "24bit"], true, .trueColor),
            Detection(["COLORTERM": "yes"], true, .ansi16),
            Detection(["TERM": "xterm-kitty"], true, .trueColor),
            Detection(["TERM": "xterm-ghostty"], true, .trueColor),
            Detection(["TERM": "wezterm"], true, .trueColor),
            Detection(["TERM_PROGRAM": "iTerm.app", "TERM_PROGRAM_VERSION": "3.5.0"], true, .trueColor),
            Detection(["TERM_PROGRAM": "iTerm.app", "TERM_PROGRAM_VERSION": "2.9"], true, .ansi256),
            Detection(["TERM_PROGRAM": "Apple_Terminal", "TERM": "xterm-256color"], true, .ansi256),
            Detection(["TERM_PROGRAM": "vscode", "TERM": "xterm-256color"], true, .ansi256),
            Detection(["TERM": "screen-256"], true, .ansi256),
            Detection(["TERM": "XTERM-256COLOR"], true, .ansi256),
            Detection(["TERM": "xterm"], true, .ansi16),
            Detection(["TERM": "linux"], true, .ansi16),
            Detection(["TERM": "unknown", "COLORTERM": "yes"], true, .ansi16),
            Detection(["TERM": "unknown"], true, .monochrome),
        ])
    func detection(_ example: Detection) {
        #expect(ColorDepth.detect(environment: example.environment, isTerminal: example.isTerminal) == example.expected)
    }

    @Test func depthsAreOrdered() {
        #expect(ColorDepth.allCases.sorted() == [.monochrome, .ansi16, .ansi256, .trueColor])
    }

    // MARK: conversions (expected values from ansi-styles)

    @Test(
        arguments: [
            [255, 0, 0, 196, 9], [0, 255, 0, 46, 10], [0, 0, 255, 21, 12], [255, 128, 0, 214, 11],
            [100, 149, 237, 111, 14], [0, 0, 0, 16, 0], [255, 255, 255, 231, 15], [128, 128, 128, 244, 7],
            [7, 7, 7, 16, 0], [249, 249, 249, 231, 15], [51, 102, 153, 67, 4], [200, 30, 90, 168, 1],
        ] as [[UInt8]])
    func rgbConversions(_ values: [UInt8]) {
        let (palette, ansi) = (values[3], values[4])
        let color = Color(red: values[0], green: values[1], blue: values[2])
        #expect(color.reduced(to: .trueColor) == color)
        #expect(color.reduced(to: .ansi256) == .palette(palette))
        #expect(color.reduced(to: .ansi16) == Color(.ansi(ansi)))
        #expect(color.reduced(to: .monochrome) == nil)
    }

    @Test(
        arguments: [
            (0, 0), (7, 7), (8, 8), (15, 15), (16, 0), (21, 12), (46, 10), (196, 9), (226, 11), (231, 15),
            (232, 0), (244, 7), (255, 7), (102, 0), (59, 0), (145, 7),
        ] as [(UInt8, UInt8)])
    func paletteConversions(palette: UInt8, ansi: UInt8) {
        #expect(Color.palette(palette).reduced(to: .ansi256) == .palette(palette))
        #expect(Color.palette(palette).reduced(to: .ansi16) == Color(.ansi(ansi)))
    }

    @Test func ansiColorsStayAtEveryDepthButMonochrome() {
        for depth in [ColorDepth.ansi16, .ansi256, .trueColor] {
            #expect(Color.brightRed.reduced(to: depth) == .brightRed)
        }
        #expect(Color.red.reduced(to: .monochrome) == nil)
    }

    // MARK: encoding

    @Test func encodingReducesColorsAndKeepsAttributes() {
        var canvas = Canvas(width: 2, height: 1)
        let style = Style(
            foreground: Color(red: 255, green: 0, blue: 0), background: .palette(21), attributes: .bold)
        canvas.write([run("ab", style)], at: .zero)
        #expect(canvas.encodedLines() == ["\(esc)[1;38;2;255;0;0;48;5;21mab\(esc)[22;39;49m"])
        #expect(canvas.encodedLines(colorDepth: .ansi256) == ["\(esc)[1;38;5;196;48;5;21mab\(esc)[22;39;49m"])
        #expect(canvas.encodedLines(colorDepth: .ansi16) == ["\(esc)[1;91;104mab\(esc)[22;39;49m"])
        #expect(canvas.encodedLines(colorDepth: .monochrome) == ["\(esc)[1mab\(esc)[22m"])
    }

    @Test func monochromeDropsStylesThatOnlyColor() {
        var canvas = Canvas(width: 2, height: 1)
        canvas.write([run("a", .red), run("b", .blue)], at: .zero)
        #expect(canvas.encodedLines(colorDepth: .monochrome) == ["ab"])
    }

    @Test @MainActor func renderToStringTakesADepth() {
        let view = Text("hi").foregroundStyle(Color(red: 0, green: 0, blue: 255))
        #expect(Stipple.renderToString(view, width: 4) == "\(esc)[38;2;0;0;255mhi\(esc)[39m")
        #expect(Stipple.renderToString(view, width: 4, colorDepth: .ansi16) == "\(esc)[94mhi\(esc)[39m")
        #expect(Stipple.renderToString(view, width: 4, colorDepth: .monochrome) == "hi")
    }
}
