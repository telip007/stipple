import Testing

@testable import Stipple

// The Swift snippets in README.md, verbatim. Keep both in sync: if the README
// changes, change the copy here, and the build tells you when the API drifted.

// MARK: Quick start

private struct Counter: View {
    @State private var count = 0
    @Environment(\.exit) private var exit

    var body: some View {
        VStack(alignment: .leading) {
            Text("Count: \(count)").foregroundStyle(.green).bold()
            Text("↑/↓ change, q quit").dim()
        }
        .padding(.horizontal, 1)
        .border(.rounded, color: .cyan)
        .onKeyPress(.upArrow) {
            count += 1
            return .handled
        }
        .onKeyPress(.downArrow) {
            count -= 1
            return .handled
        }
        .onKeyPress("q") {
            exit()
            return .handled
        }
    }
}

/// The last line of the quick start. It must compile but is never called: it
/// would take over the terminal.
private func runCounter() async throws {
    try await Stipple.run(Counter())
}

@MainActor
struct ReadmeExampleTests {
    private func plain(_ view: some View, width: Int = 40) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func quickStartCounterRenders() {
        let output = plain(Counter())
        #expect(output.contains("Count: 0"))
        #expect(output.contains("↑/↓ change, q quit"))
        #expect(output.contains("╭"))
        #expect(output.contains("╯"))
    }

    @Test func quickStartCounterIsStyled() {
        let output = Stipple.renderToString(Counter(), width: 40)
        #expect(output.contains("\u{1B}["))
    }

    @Test func runEntryPointIsReferenced() {
        let entryPoint = runCounter
        _ = entryPoint
    }
}

private struct Login: View {
    @State private var user = ""
    @State private var password = ""
    @FocusState private var field: Field?
    enum Field { case user, password }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("User:     ")
                TextField("name", text: $user).focused($field, equals: .user)
            }
            HStack {
                Text("Password: ")
                SecureField("secret", text: $password).focused($field, equals: .password)
            }
        }
        .onSubmit { field = field == .user ? .password : nil }
        .onAppear { field = .user }
    }
}

@MainActor
@Test func readmeLoginRenders() {
    let output = Stipple.renderToString(Login(), width: 40)
    #expect(output.contains("User:"))
    #expect(output.contains("Password:"))
}
