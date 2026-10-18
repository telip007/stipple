// A REPL-style chat: history in scrollback, a live input line with a
// cursor, Enter to send, Ctrl-C to quit. Run with `swift run chat`.
import Stipple

struct Message: Identifiable {
    let id: Int
    let text: String
}

struct Chat: View {
    @State private var messages: [Message] = []
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading) {
            Static(messages) { message in
                (Text("you ").foregroundStyle(.cyan).bold() + Text(message.text))
                    .padding(.bottom, 1)
            }
            HStack {
                Text("› ").foregroundStyle(.magenta)
                Text(input)
                    .cursorPosition(Point(x: TextMetrics.width(of: input), y: 0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 1)
            .border(.rounded, color: .gray)
            Text("Enter to send · Ctrl-C to quit").dim()
        }
        .onKeyPress { press in
            switch press.key {
            case .return:
                guard !input.isEmpty else { return .handled }
                messages.append(Message(id: messages.count, text: input))
                input = ""
            case .backspace:
                if !input.isEmpty { input.removeLast() }
            case .character where !press.modifiers.contains(.control):
                input += press.characters
            default:
                return .ignored
            }
            return .handled
        }
        .onPaste { input += $0 }
    }
}

try await Stipple.run(Chat())
