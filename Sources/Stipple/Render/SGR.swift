/// Encodes colors, attributes and style changes as SGR and OSC 8 sequences.
enum SGR {
    private static let escape = "\u{1B}"

    /// The SGR parameters that select `color` as foreground (`38;5;n`, `31`, ...).
    static func foreground(_ color: Color) -> String {
        parameters(for: color, base: 30, bright: 90, extended: 38)
    }

    /// The SGR parameters that select `color` as background.
    static func background(_ color: Color) -> String {
        parameters(for: color, base: 40, bright: 100, extended: 48)
    }

    private static func parameters(for color: Color, base: Int, bright: Int, extended: Int) -> String {
        switch color.representation {
        case .ansi(let index):
            let value = Int(index)
            return value < 8 ? String(base + value) : String(bright + value - 8)
        case .palette(let index):
            return "\(extended);5;\(index)"
        case .rgb(let red, let green, let blue):
            return "\(extended);2;\(red);\(green);\(blue)"
        }
    }

    /// Attribute flags in the order they are switched on, with their on and off codes.
    private static let attributeCodes: [AttributeCode] = [
        AttributeCode(attribute: .bold, enable: "1", disable: "22"),
        AttributeCode(attribute: .dim, enable: "2", disable: "22"),
        AttributeCode(attribute: .italic, enable: "3", disable: "23"),
        AttributeCode(attribute: .underline, enable: "4", disable: "24"),
        AttributeCode(attribute: .inverse, enable: "7", disable: "27"),
        AttributeCode(attribute: .strikethrough, enable: "9", disable: "29"),
    ]

    private struct AttributeCode {
        let attribute: TextAttributes
        let enable: String
        let disable: String
    }

    /// The escape sequences that turn a terminal showing `from` into one
    /// showing `to`, with as few parameters as possible. Empty if the
    /// styles are equal.
    static func transition(from old: Style, to new: Style) -> String {
        guard old != new else { return "" }
        var output = ""
        if old.link != new.link, old.link != nil { output += linkClose }
        let parameters = parameterList(from: old, to: new)
        if !parameters.isEmpty { output += "\(escape)[\(parameters)m" }
        if old.link != new.link, let link = new.link { output += linkOpen(link) }
        return output
    }

    private static func parameterList(from old: Style, to new: Style) -> String {
        var codes: [String] = []
        let removed = old.attributes.subtracting(new.attributes)
        var active = old.attributes
        // 22 clears bold and dim together, so the survivor is switched on again below.
        let clearsIntensity = !removed.isDisjoint(with: [.bold, .dim])
        if clearsIntensity { active.subtract([.bold, .dim]) }
        for entry in attributeCodes where removed.contains(entry.attribute) {
            if !codes.contains(entry.disable) { codes.append(entry.disable) }
        }
        for entry in attributeCodes
        where new.attributes.contains(entry.attribute) && !active.contains(entry.attribute) {
            codes.append(entry.enable)
        }
        if old.foreground != new.foreground { codes.append(new.foreground.map(foreground) ?? "39") }
        if old.background != new.background { codes.append(new.background.map(background) ?? "49") }
        return codes.joined(separator: ";")
    }

    /// OSC 8 sequence that starts a hyperlink.
    static func linkOpen(_ url: String) -> String { "\(escape)]8;;\(url)\(escape)\\" }

    /// OSC 8 sequence that ends a hyperlink.
    static let linkClose = "\u{1B}]8;;\u{1B}\\"
}

extension Style {
    /// Applies the parameters of one SGR sequence (`1;31`, `38;5;196`,
    /// `38:2::255:0:0`) to the style. Unknown parameters are ignored. The
    /// link is not part of SGR and stays as it is.
    mutating func applySGR(_ parameterString: Substring) {
        let groups = parameterString.split(separator: ";", omittingEmptySubsequences: false).map { group in
            group.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        }
        var index = 0
        while index < groups.count {
            let group = groups[index]
            let code = group.first.flatMap { $0 } ?? 0
            index += 1
            switch code {
            case 38, 48, 58:
                let (color, consumed) = Self.extendedColor(group, following: groups[index...])
                index += consumed
                if code == 38 { foreground = color ?? foreground }
                if code == 48 { background = color ?? background }
            default:
                applySimple(code, group)
            }
        }
    }

    private mutating func applySimple(_ code: Int, _ group: [Int?]) {
        switch code {
        case 0:
            self = Self(link: link)
        case 4:
            // `4:0` switches underline off; other sub-parameters pick a style we draw as plain underline.
            let off = group.count > 1 && (group[1] ?? 0) == 0
            if off { attributes.remove(.underline) } else { attributes.insert(.underline) }
        case 22:
            attributes.subtract([.bold, .dim])
        case 30...37:
            foreground = Color(.ansi(UInt8(code - 30)))
        case 90...97:
            foreground = Color(.ansi(UInt8(code - 90 + 8)))
        case 40...47:
            background = Color(.ansi(UInt8(code - 40)))
        case 100...107:
            background = Color(.ansi(UInt8(code - 100 + 8)))
        case 39:
            foreground = nil
        case 49:
            background = nil
        default:
            applyAttribute(code)
        }
    }

    private mutating func applyAttribute(_ code: Int) {
        switch code {
        case 1: attributes.insert(.bold)
        case 2: attributes.insert(.dim)
        case 3: attributes.insert(.italic)
        case 7: attributes.insert(.inverse)
        case 9: attributes.insert(.strikethrough)
        case 23: attributes.remove(.italic)
        case 24: attributes.remove(.underline)
        case 27: attributes.remove(.inverse)
        case 29: attributes.remove(.strikethrough)
        default: break
        }
    }

    /// Reads a `38`/`48`/`58` color. `group` holds colon sub-parameters when
    /// the colon form is used; otherwise the color follows in the next
    /// semicolon-separated groups. Returns the color (`nil` if malformed or
    /// unsupported) and how many following groups it used.
    private static func extendedColor(_ group: [Int?], following: ArraySlice<[Int?]>) -> (Color?, Int) {
        if group.count > 1 { return (colonColor(group), 0) }
        let values = following.map { $0.first.flatMap { $0 } }
        switch values.first.flatMap({ $0 }) {
        case 5:
            guard values.count >= 2 else { return (nil, values.count) }
            return (values[1].map { Color.palette(UInt8(clamping: $0)) }, 2)
        case 2:
            guard values.count >= 4 else { return (nil, values.count) }
            return (rgb(values[1], values[2], values[3]), 4)
        default:
            return (nil, 0)
        }
    }

    private static func colonColor(_ group: [Int?]) -> Color? {
        switch (group[1], group.count) {
        case (5, 3):
            return group[2].map { Color.palette(UInt8(clamping: $0)) }
        case (2, 5):
            return rgb(group[2], group[3], group[4])
        case (2, 6) where (group[2] ?? 0) == 0:
            // A colon form may carry a color space id, which only 0 or empty may use.
            return rgb(group[3], group[4], group[5])
        default:
            return nil
        }
    }

    private static func rgb(_ red: Int?, _ green: Int?, _ blue: Int?) -> Color? {
        guard let red, let green, let blue else { return nil }
        return Color(red: UInt8(clamping: red), green: UInt8(clamping: green), blue: UInt8(clamping: blue))
    }
}
