import Testing

@testable import Stipple

@Suite struct ANSITokenizerTests {
    private func tokens(_ text: String) -> [ANSIToken] {
        ANSITokenizer.tokenize(text)
    }

    @Test func plainText() {
        #expect(tokens("hello") == [.text("hello")])
        #expect(tokens("") == [.text("")])
    }

    @Test func sgrSequence() {
        #expect(
            tokens("A\(esc)[31mB") == [
                .text("A"),
                .csi(raw: "\(esc)[31m", parameters: "31", intermediates: "", final: "m"),
                .text("B"),
            ])
    }

    @Test func c1CSIWithIntermediate() {
        #expect(
            tokens("A\u{9B}2 qB") == [
                .text("A"),
                .csi(raw: "\u{9B}2 q", parameters: "2", intermediates: " ", final: "q"),
                .text("B"),
            ])
    }

    @Test func oscTerminators() {
        let link = "8;;https://example.com"
        for (open, close) in [
            ("\(esc)]", "\(esc)\\"), ("\(esc)]", "\u{7}"), ("\(esc)]", "\u{9C}"),
            ("\u{9D}", "\u{9C}"), ("\u{9D}", "\(esc)\\"), ("\u{9D}", "\u{7}"),
        ] {
            let raw = open + link + close
            #expect(tokens("A\(raw)B") == [.text("A"), .controlString(.osc, raw: raw), .text("B")])
        }
    }

    @Test func bellDoesNotTerminateOtherControlStrings() {
        #expect(tokens("A\(esc)Xpayload\u{7}B") == [.text("A"), .invalid("\(esc)Xpayload\u{7}B")])
        #expect(tokens("A\u{98}payload\u{7}B") == [.text("A"), .invalid("\u{98}payload\u{7}B")])
        #expect(
            tokens("A\(esc)Ppay\u{7}load\(esc)\\B") == [
                .text("A"), .controlString(.dcs, raw: "\(esc)Ppay\u{7}load\(esc)\\"), .text("B"),
            ])
    }

    @Test func controlStringKinds() {
        #expect(tokens("\(esc)^x\u{9C}") == [.controlString(.privacyMessage, raw: "\(esc)^x\u{9C}")])
        #expect(tokens("\(esc)_x\u{9C}") == [.controlString(.apc, raw: "\(esc)_x\u{9C}")])
        #expect(tokens("\u{90}x\u{9C}") == [.controlString(.dcs, raw: "\u{90}x\u{9C}")])
        #expect(tokens("\u{9E}x\u{9C}") == [.controlString(.privacyMessage, raw: "\u{9E}x\u{9C}")])
        #expect(tokens("\u{9F}x\u{9C}") == [.controlString(.apc, raw: "\u{9F}x\u{9C}")])
        #expect(tokens("\u{98}x\u{9C}") == [.controlString(.sos, raw: "\u{98}x\u{9C}")])
    }

    @Test func tmuxPassthroughIsOneToken() {
        let wrapped = "\(esc)Ptmux;\(esc)\(esc)]8;;https://example.com\(esc)\(esc)\\\(esc)\\"
        #expect(tokens("A\(wrapped)B") == [.text("A"), .controlString(.dcs, raw: wrapped), .text("B")])
    }

    @Test func malformedSequencesStopTokenizing() {
        #expect(tokens("A\(esc)[") == [.text("A"), .invalid("\(esc)[")])
        #expect(tokens("A\(esc)") == [.text("A"), .invalid(esc)])
        #expect(tokens("A\(esc)#") == [.text("A"), .invalid("\(esc)#")])
        #expect(tokens("A\u{9B}31") == [.text("A"), .invalid("\u{9B}31")])
        #expect(tokens("A\u{9D}8;;x") == [.text("A"), .invalid("\u{9D}8;;x")])
        #expect(tokens("\(esc)]8;;x\(esc)") == [.invalid("\(esc)]8;;x\(esc)")])
    }

    @Test func loneEscapeIsIgnored() {
        #expect(tokens("A\(esc)\u{7}B") == [.text("A"), .text("\u{7}B")])
    }

    @Test func escapeSequences() {
        #expect(
            tokens("A\(esc)\\B") == [.text("A"), .esc(raw: "\(esc)\\", intermediates: "", final: "\\"), .text("B")])
        #expect(tokens("\(esc)(0") == [.esc(raw: "\(esc)(0", intermediates: "(", final: "0")])
    }

    @Test func c1Controls() {
        #expect(tokens("A\u{9C}B") == [.text("A"), .stringTerminator, .text("B")])
        #expect(tokens("A\u{85}B") == [.text("A"), .c1Control("\u{85}"), .text("B")])
    }
}
