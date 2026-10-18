// A REPL-style chat: history in scrollback with `Static`, a live input line
// with `TextField`, Enter to send, Ctrl-C to quit. Run with `swift run chat`.
import Stipple

struct Message: Identifiable {
    let id: Int
    let text: String
}

struct Chat: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @FocusState private var isInputFocused = true

    var body: some View {
        VStack(alignment: .leading) {
            Static(messages) { message in
                (Text("you ").foregroundStyle(.cyan).bold() + Text(message.text))
                    .padding(.bottom, 1)
            }
            HStack {
                Text("› ").foregroundStyle(.magenta)
                TextField("Send a message", text: $input).focused($isInputFocused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 1)
            .border(.rounded, color: .gray)
            Text("Enter to send · Ctrl-C to quit").dim()
        }
        .onSubmit {
            guard !input.isEmpty else { return }
            messages.append(Message(id: messages.count, text: input))
            input = ""
        }
    }
}

try await Stipple.run(Chat())
