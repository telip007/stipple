// A REPL-style chat with a pretend assistant: history in scrollback with
// `Static`, a spinner while it "thinks", a reply that streams in word by word,
// a live input line with `TextField`, Enter to send, Ctrl-C to quit.
// Run with `swift run chat`.
import Stipple

struct Message: Identifiable {
    enum Role { case user, assistant }

    let id: Int
    let role: Role
    let text: String
}

struct Chat: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var prompt: String?
    @State private var isThinking = false
    @State private var reply = ""
    @FocusState private var isInputFocused = true

    private static let answers = [
        "Hi! I am a pretend assistant. Each word you see is appended to one growing Text, and Stipple only wraps the new tail, so long replies stream without redrawing the screen.",
        "Sent messages move into the terminal's scrollback with Static. The live region stays a few lines tall, and your shell keeps the whole conversation after you quit.",
        "That arrived as one bracketed paste, so newlines in pasted text never send a message early. The caret is the terminal's real cursor, which keeps input methods working.",
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Static(messages) { message in
                bubble(message.role, Text(message.text)).padding(.bottom, 1)
            }
            if isThinking {
                ProgressView("Thinking").progressViewStyle(.dots).foregroundStyle(.yellow).padding(.bottom, 1)
            } else if prompt != nil {
                bubble(.assistant, Text(reply) + Text("▍").foregroundStyle(.gray)).padding(.bottom, 1)
            }
            HStack {
                Text("› ").foregroundStyle(.magenta)
                TextField("Send a message", text: $input).focused($isInputFocused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 1)
            .border(.rounded, color: prompt == nil ? .cyan : .gray)
            Text(prompt == nil ? "Enter to send · Ctrl-C to quit" : "Replying… · Ctrl-C to quit").dim()
        }
        .onSubmit {
            guard prompt == nil, !input.isEmpty else { return }
            messages.append(Message(id: messages.count, role: .user, text: input))
            prompt = input
            input = ""
        }
        .task(id: prompt) {
            guard prompt != nil else { return }
            isThinking = true
            try? await Task.sleep(for: .milliseconds(700))
            isThinking = false
            let answer = Self.answers[messages.count / 2 % Self.answers.count]
            for word in answer.split(separator: " ") {
                reply += reply.isEmpty ? String(word) : " \(word)"
                try? await Task.sleep(for: .milliseconds(45))
            }
            messages.append(Message(id: messages.count, role: .assistant, text: reply))
            reply = ""
            prompt = nil
        }
    }

    private func bubble(_ role: Message.Role, _ text: Text) -> some View {
        HStack {
            switch role {
            case .user: Text("you  ").foregroundStyle(.cyan).bold()
            case .assistant: Text("bot  ").foregroundStyle(.green).bold()
            }
            text
        }
    }
}

try await Stipple.run(Chat())
