/// How many colors a terminal can show (chalk's color levels). Colors are
/// downsampled to the depth when frames are encoded: RGB to the nearest
/// 256-color entry, 256-color entries to the nearest of the 16 ANSI colors,
/// and no color at all for ``monochrome``, which keeps bold, italic and the
/// other attributes.
public enum ColorDepth: Int, Comparable, CaseIterable, Sendable {
    /// No colors; attributes only.
    case monochrome = 0
    /// The 16 ANSI colors.
    case ansi16 = 1
    /// The xterm 256-color palette.
    case ansi256 = 2
    /// 24-bit RGB.
    case trueColor = 3

    /// Whether `lhs` shows fewer colors than `rhs`.
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The depth a terminal supports, decided the way chalk's `supports-color` does.
    ///
    /// In order: `FORCE_COLOR` (`0`–`3` picks the depth, `true` or empty
    /// turns color on and detects the depth, `false` turns it off), then
    /// `NO_COLOR` (any non-empty value turns color off, see no-color.org),
    /// then Azure Pipelines (16 colors). Output that isn't a terminal gets
    /// no color unless forced. Then `TERM=dumb` (no color), CI systems
    /// (truecolor on GitHub Actions, Gitea Actions and CircleCI, 16 colors on
    /// Travis, AppVeyor, GitLab, Buildkite, Drone and Codeship), TeamCity,
    /// `COLORTERM=truecolor` or `24bit`, kitty, Ghostty and WezTerm (truecolor),
    /// `TERM_PROGRAM` iTerm 3+ (truecolor, older 256) and Apple Terminal
    /// (256), a `TERM` ending in `-256` or `-256color` (256), and finally a
    /// `TERM` that looks like a color terminal or any `COLORTERM` (16).
    ///
    /// - Parameters:
    ///   - environment: The environment variables to read.
    ///   - isTerminal: Whether the output stream is a terminal.
    /// - Returns: The detected depth.
    public static func detect(environment: [String: String], isTerminal: Bool) -> Self {
        let force = forcedDepth(environment)
        if force == .monochrome { return .monochrome }
        if let force, let value = environment["FORCE_COLOR"], isDigits(value) { return force }
        if force == nil, let noColor = environment["NO_COLOR"], !noColor.isEmpty { return .monochrome }
        if environment["TF_BUILD"] != nil, environment["AGENT_NAME"] != nil { return .ansi16 }
        if !isTerminal, force == nil { return .monochrome }
        let minimum = force ?? .monochrome
        if environment["TERM"] == "dumb" { return minimum }
        if environment["CI"] != nil { return ciDepth(environment) ?? minimum }
        if let version = environment["TEAMCITY_VERSION"] {
            return version.firstMatch(of: /^(?:9\.0*[1-9]\d*\.|\d{2,}\.)/) != nil ? .ansi16 : .monochrome
        }
        return terminalDepth(environment) ?? minimum
    }

    /// `FORCE_COLOR` as a depth: `nil` when unset or unreadable, ``ansi16``
    /// for `true` and empty, otherwise the number capped at 3.
    private static func forcedDepth(_ environment: [String: String]) -> Self? {
        guard let value = environment["FORCE_COLOR"] else { return nil }
        switch value {
        case "true", "": return .ansi16
        case "false": return .monochrome
        default:
            guard isDigits(value), let level = Int(value.prefix(4)) else { return nil }
            return Self(rawValue: min(level, 3))
        }
    }

    private static func isDigits(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func ciDepth(_ environment: [String: String]) -> Self? {
        if ["GITHUB_ACTIONS", "GITEA_ACTIONS", "CIRCLECI"].contains(where: { environment[$0] != nil }) {
            return .trueColor
        }
        let basic = ["TRAVIS", "APPVEYOR", "GITLAB_CI", "BUILDKITE", "DRONE"]
        if basic.contains(where: { environment[$0] != nil }) || environment["CI_NAME"] == "codeship" {
            return .ansi16
        }
        return nil
    }

    private static func terminalDepth(_ environment: [String: String]) -> Self? {
        let term = environment["TERM"] ?? ""
        if ["truecolor", "24bit"].contains(environment["COLORTERM"]) { return .trueColor }
        if ["xterm-kitty", "xterm-ghostty", "wezterm"].contains(term) { return .trueColor }
        switch environment["TERM_PROGRAM"] {
        case "iTerm.app":
            let major = (environment["TERM_PROGRAM_VERSION"] ?? "").split(separator: ".").first.flatMap { Int($0) }
            return (major ?? 0) >= 3 ? .trueColor : .ansi256
        case "Apple_Terminal":
            return .ansi256
        default:
            break
        }
        if term.firstMatch(of: /(?i)-256(?:color)?$/) != nil { return .ansi256 }
        if term.firstMatch(of: /(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/) != nil {
            return .ansi16
        }
        return environment["COLORTERM"] != nil ? .ansi16 : nil
    }
}

extension Color {
    /// This color as the closest one `depth` can show, or `nil` for ``ColorDepth/monochrome``.
    func reduced(to depth: ColorDepth) -> Color? {
        switch (representation, depth) {
        case (_, .monochrome):
            return nil
        case (.rgb(let red, let green, let blue), .ansi256):
            return .palette(Self.paletteIndex(red: red, green: green, blue: blue))
        case (.rgb(let red, let green, let blue), .ansi16):
            return Color(.ansi(Self.ansiIndex(palette: Self.paletteIndex(red: red, green: green, blue: blue))))
        case (.palette(let index), .ansi16):
            return Color(.ansi(Self.ansiIndex(palette: index)))
        default:
            return self
        }
    }

    /// The nearest xterm-256 entry: the grey ramp for greys, else the 6×6×6
    /// cube (ansi-styles' `rgbToAnsi256`).
    static func paletteIndex(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
        if red == green, green == blue {
            if red < 8 { return 16 }
            if red > 248 { return 231 }
            return UInt8((Double(Int(red) - 8) / 247 * 24).rounded() + 232)
        }
        func level(_ component: UInt8) -> Int { Int((Double(component) / 255 * 5).rounded()) }
        return UInt8(16 + 36 * level(red) + 6 * level(green) + level(blue))
    }

    /// The nearest of the 16 ANSI colors to a 256-color entry, 0–7 normal and
    /// 8–15 bright (ansi-styles' `ansi256ToAnsi`).
    static func ansiIndex(palette index: UInt8) -> UInt8 {
        if index < 16 { return index }
        let red: Double
        let green: Double
        let blue: Double
        if index >= 232 {
            red = Double((Int(index) - 232) * 10 + 8) / 255
            green = red
            blue = red
        } else {
            let code = Int(index) - 16
            red = Double(code / 36) / 5
            green = Double(code % 36 / 6) / 5
            blue = Double(code % 6) / 5
        }
        let value = max(red, green, blue) * 2
        if value == 0 { return 0 }
        let bits = Int(blue.rounded()) << 2 | Int(green.rounded()) << 1 | Int(red.rounded())
        return UInt8(bits + (value == 2 ? 8 : 0))
    }
}

extension Style {
    /// This style with its colors reduced to `depth`; attributes and link stay.
    func reduced(to depth: ColorDepth) -> Style {
        guard depth != .trueColor else { return self }
        var style = self
        style.foreground = foreground?.reduced(to: depth)
        style.background = background?.reduced(to: depth)
        return style
    }
}
