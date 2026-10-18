/// Converts between strings with escape sequences and styled runs.
enum ANSIText {
    /// Parses text that may contain ANSI escapes, such as subprocess output.
    ///
    /// SGR sequences (colors, bold, italic, underline, inverse, strikethrough,
    /// including `38;5`, `38;2` and the colon forms) and OSC 8 hyperlinks become
    /// run styles. Everything else is dropped: cursor movement, screen
    /// clearing, other CSI, OSC, DCS, PM, APC and SOS sequences, C1 controls,
    /// and C0 controls except tab and newline. A malformed sequence drops
    /// the rest of the string, as Ink's `sanitize-ansi` does. Combining marks
    /// that follow a style change stay with the character before it.
    static func parse(_ string: String) -> [StyledRun] {
        var builder = RunBuilder()
        for token in ANSITokenizer.tokenize(string) {
            switch token {
            case .text(let text):
                builder.append(sanitized(text))
            case .csi(_, let parameters, let intermediates, let final):
                if final == "m", intermediates.isEmpty, parameters.allSatisfy(isSGRCharacter) {
                    builder.style.applySGR(Substring(parameters))
                }
            case .controlString(.osc, let raw):
                if let link = hyperlink(inOSC: raw) { builder.style.link = link.isEmpty ? nil : link }
            default:
                break
            }
        }
        return builder.runs
    }

    /// Encodes runs as a string with the shortest SGR sequences that
    /// reproduce the styles, closing everything at the end.
    static func encode(_ runs: [StyledRun]) -> String {
        var output = ""
        var current = Style.plain
        for run in runs where !run.text.isEmpty {
            output += SGR.transition(from: current, to: run.style)
            output += run.text
            current = run.style
        }
        return output + SGR.transition(from: current, to: .plain)
    }

    private static func isSGRCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isNumber || character == ";" || character == ":")
    }

    /// Text without C0 controls (other than tab and newline), DEL and stray C1 controls.
    private static func sanitized(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: isStrippable) else { return text }
        var result = String.UnicodeScalarView()
        result.append(contentsOf: text.unicodeScalars.filter { !isStrippable($0) })
        return String(result)
    }

    private static func isStrippable(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if value == 0x09 || value == 0x0A { return false }
        return value < 0x20 || (0x7F...0x9F).contains(value)
    }

    /// The URI of an OSC 8 sequence (empty when it closes a link), or `nil` for any other OSC.
    private static func hyperlink(inOSC raw: String) -> String? {
        var body = Array(raw.unicodeScalars)
        body.removeFirst(body.first?.value == 0x1B ? 2 : 1)
        if let last = body.last, last.value == 0x07 || last.value == 0x9C {
            body.removeLast()
        } else if body.count >= 2, body[body.count - 2].value == 0x1B {
            body.removeLast(2)
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: body)
        let parts = String(view).split(separator: ";", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "8" else { return nil }
        return String(parts[2])
    }

    /// Accumulates runs, merging neighbours of equal style.
    private struct RunBuilder {
        var runs: [StyledRun] = []
        var style = Style.plain

        mutating func append(_ text: String) {
            var text = Substring(text)
            // A combining mark belongs to the character before it, whatever style change came between.
            if !runs.isEmpty, !(runs[runs.count - 1].text.last?.isNewline ?? true) {
                let marks = text.unicodeScalars.prefix { isMark($0) }
                if !marks.isEmpty {
                    runs[runs.count - 1].text.unicodeScalars.append(contentsOf: marks)
                    text = Substring(text.unicodeScalars.dropFirst(marks.count))
                }
            }
            guard !text.isEmpty else { return }
            if let last = runs.indices.last, runs[last].style == style {
                runs[last].text += text
            } else {
                runs.append(StyledRun(text: String(text), style: style))
            }
        }

        private func isMark(_ scalar: Unicode.Scalar) -> Bool {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark: true
            default: false
            }
        }
    }
}
