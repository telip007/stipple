/// One piece of a string that may contain terminal escape sequences.
enum ANSIToken: Equatable {
    /// The kind of an escape-introduced control string.
    enum ControlString: Equatable {
        case osc, dcs, privacyMessage, apc, sos
    }

    /// Printable text and C0 controls without special meaning.
    case text(String)
    /// `ESC [` or C1 CSI: parameters, intermediates and final character.
    case csi(raw: String, parameters: String, intermediates: String, final: Unicode.Scalar)
    /// A short escape sequence such as `ESC \`.
    case esc(raw: String, intermediates: String, final: Unicode.Scalar)
    /// OSC, DCS, PM, APC or SOS up to and including its terminator.
    case controlString(ControlString, raw: String)
    /// A bare C1 string terminator.
    case stringTerminator
    /// Any other C1 control.
    case c1Control(Unicode.Scalar)
    /// A malformed sequence and everything after it.
    case invalid(String)
}

/// Splits text into ANSI tokens (a port of Ink's `ansi-tokenizer.ts`).
enum ANSITokenizer {
    private static let escape: UInt32 = 0x1B
    private static let bell: UInt32 = 0x07
    private static let stringTerminator: UInt32 = 0x9C
    private static let csiC1: UInt32 = 0x9B

    /// Tokenizes `text`. Text without escapes or C1 controls is one `.text` token.
    static func tokenize(_ text: String) -> [ANSIToken] {
        let scalars = Array(text.unicodeScalars)
        guard scalars.contains(where: { $0.value == escape || (0x80...0x9F).contains($0.value) }) else {
            return [.text(text)]
        }
        var reader = Reader(scalars: scalars)
        return reader.readAll()
    }

    private struct Reader {
        enum Step {
            case plain
            case loneEscape
            case malformed
            case token(ANSIToken, end: Int)
        }

        let scalars: [Unicode.Scalar]
        var tokens: [ANSIToken] = []
        var textStart = 0

        init(scalars: [Unicode.Scalar]) {
            self.scalars = scalars
        }

        mutating func readAll() -> [ANSIToken] {
            var index = 0
            while index < scalars.count {
                switch step(at: index) {
                case .plain:
                    index += 1
                case .loneEscape:
                    flushText(upTo: index)
                    index += 1
                    textStart = index
                case .malformed:
                    flushText(upTo: index)
                    tokens.append(.invalid(string(index, scalars.count)))
                    return tokens
                case .token(let token, let end):
                    flushText(upTo: index)
                    tokens.append(token)
                    index = end
                    textStart = end
                }
            }
            flushText(upTo: scalars.count)
            return tokens
        }

        private mutating func flushText(upTo index: Int) {
            if index > textStart { tokens.append(.text(string(textStart, index))) }
        }

        private func string(_ from: Int, _ to: Int) -> String {
            var result = String.UnicodeScalarView()
            result.append(contentsOf: scalars[from..<to])
            return String(result)
        }

        private func step(at index: Int) -> Step {
            let value = scalars[index].value
            if value == ANSITokenizer.escape { return escapeStep(at: index) }
            if value == ANSITokenizer.csiC1 { return csiStep(at: index, bodyStart: index + 1) }
            if let kind = controlString(forC1: value) {
                return controlStringStep(kind, at: index, bodyStart: index + 1)
            }
            if value == ANSITokenizer.stringTerminator { return .token(.stringTerminator, end: index + 1) }
            if (0x80...0x9F).contains(value) { return .token(.c1Control(scalars[index]), end: index + 1) }
            return .plain
        }

        private func escapeStep(at index: Int) -> Step {
            guard index + 1 < scalars.count else { return .malformed }
            let next = scalars[index + 1]
            if next == "[" { return csiStep(at: index, bodyStart: index + 2) }
            if let kind = controlString(forEscape: next) {
                return controlStringStep(kind, at: index, bodyStart: index + 2)
            }
            var cursor = index + 1
            while cursor < scalars.count, isIntermediate(scalars[cursor]) { cursor += 1 }
            if cursor < scalars.count, (0x30...0x7E).contains(scalars[cursor].value) {
                let token = ANSIToken.esc(
                    raw: string(index, cursor + 1),
                    intermediates: string(index + 1, cursor),
                    final: scalars[cursor],
                )
                return .token(token, end: cursor + 1)
            }
            return isIntermediate(next) ? .malformed : .loneEscape
        }

        private func csiStep(at index: Int, bodyStart: Int) -> Step {
            var cursor = bodyStart
            while cursor < scalars.count, (0x30...0x3F).contains(scalars[cursor].value) { cursor += 1 }
            let intermediateStart = cursor
            while cursor < scalars.count, isIntermediate(scalars[cursor]) { cursor += 1 }
            guard cursor < scalars.count, (0x40...0x7E).contains(scalars[cursor].value) else { return .malformed }
            let token = ANSIToken.csi(
                raw: string(index, cursor + 1),
                parameters: string(bodyStart, intermediateStart),
                intermediates: string(intermediateStart, cursor),
                final: scalars[cursor],
            )
            return .token(token, end: cursor + 1)
        }

        private func controlStringStep(_ kind: ANSIToken.ControlString, at index: Int, bodyStart: Int) -> Step {
            guard let end = terminatorEnd(from: bodyStart, allowsBell: kind == .osc) else { return .malformed }
            return .token(.controlString(kind, raw: string(index, end)), end: end)
        }

        /// The index after the terminator of a control string, if there is one.
        private func terminatorEnd(from start: Int, allowsBell: Bool) -> Int? {
            var index = start
            while index < scalars.count {
                let value = scalars[index].value
                if (allowsBell && value == ANSITokenizer.bell) || value == ANSITokenizer.stringTerminator {
                    return index + 1
                }
                if value == ANSITokenizer.escape, index + 1 < scalars.count {
                    // tmux doubles ESC bytes inside the payload.
                    if scalars[index + 1].value == ANSITokenizer.escape {
                        index += 1
                    } else if scalars[index + 1] == "\\" {
                        return index + 2
                    }
                }
                index += 1
            }
            return nil
        }

        private func isIntermediate(_ scalar: Unicode.Scalar) -> Bool {
            (0x20...0x2F).contains(scalar.value)
        }

        private func controlString(forEscape scalar: Unicode.Scalar) -> ANSIToken.ControlString? {
            switch scalar {
            case "]": .osc
            case "P": .dcs
            case "^": .privacyMessage
            case "_": .apc
            case "X": .sos
            default: nil
            }
        }

        private func controlString(forC1 value: UInt32) -> ANSIToken.ControlString? {
            switch value {
            case 0x9D: .osc
            case 0x90: .dcs
            case 0x9E: .privacyMessage
            case 0x9F: .apc
            case 0x98: .sos
            default: nil
            }
        }
    }
}
