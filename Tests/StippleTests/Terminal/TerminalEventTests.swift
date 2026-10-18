import Foundation
import Testing

@testable import Stipple

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Process-wide signals (`SIGWINCH`, `SIGCONT`) are shared, so these tests run one at a time.
@Suite(.serialized) @MainActor
struct TerminalEventTests {
    // MARK: Events

    @Test func eventsDeliverInputOffTheMainThread() async throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.enableRawMode()
        var events = terminal.events().makeAsyncIterator()
        pty.type("abc")
        var received: [UInt8] = []
        while received.count < 3, case .input(let bytes)? = await events.next() { received += bytes }
        #expect(received == Array("abc".utf8))
        terminal.restore()
        terminal.stopEvents()
        #expect(await events.next() == nil)
    }

    @Test func eventsDeliverResizes() async throws {
        let pty = try PTY(columns: 80, rows: 24)
        let terminal = pty.terminal()
        var events = terminal.events().makeAsyncIterator()
        pty.setSize(columns: 55, rows: 17)
        kill(getpid(), SIGWINCH)
        #expect(await events.next() == .resize(Size(width: 55, height: 17)))
        terminal.stopEvents()
    }

    @Test func callingEventsAgainEndsThePreviousStream() async throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        var first = terminal.events().makeAsyncIterator()
        let second = terminal.events()
        #expect(await first.next() == nil)
        terminal.stopEvents()
        var iterator = second.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }

    @Test func streamEndsAtEndOfInput() async throws {
        let pipe = Pipe()
        let terminal = Terminal(
            inputDescriptor: pipe.fileHandleForReading.fileDescriptor, outputDescriptor: 1, environment: [:])
        var events = terminal.events().makeAsyncIterator()
        pipe.fileHandleForWriting.write(Data([0x68, 0x69]))
        try pipe.fileHandleForWriting.close()
        #expect(await events.next() == .input([0x68, 0x69]))
        #expect(await events.next() == nil)
        terminal.stopEvents()
    }

    @Test func cancellingTheConsumerStopsReading() async throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        let task = Task { @MainActor in
            for await _ in terminal.events() {}
        }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await task.value
        try await Task.sleep(for: .milliseconds(100))
        #expect(terminal.eventState.reader == nil)
    }

    // MARK: Suspend and continue

    @Test func suspendHandsOverTheTerminalAndTakesItBack() async throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.enableRawMode()
        terminal.setAlternateScreen(true)
        var events = terminal.events().makeAsyncIterator()
        _ = pty.read(until: "1049h")
        let result = try await terminal.suspend { () async throws -> Int in
            #expect(!terminal.isRawModeEnabled)
            let during = TTY.attributes(pty.device)
            #expect((during?.c_lflag ?? 0) & tcflag_t(ICANON) != 0)
            terminal.setCursorVisible(false)
            return 7
        }
        #expect(result == 7)
        #expect(terminal.isRawModeEnabled)
        let output = pty.read(until: "?25l")
        #expect(output.contains("\u{1B}[?1049l"))
        #expect(output.hasSuffix("\u{1B}[?1049h\u{1B}[?25l"))
        #expect(await events.next() == .resize(terminal.size))
        pty.type("x")
        #expect(await events.next() == .input([0x78]))
        terminal.restore()
        terminal.stopEvents()
    }

    @Test func suspendRejectsNestingAndRestoresWhenBodyThrows() async throws {
        struct Boom: Error {}
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.enableRawMode()
        await #expect(throws: Boom.self) {
            try await terminal.suspend {
                await #expect(throws: TerminalError.alreadySuspended) { try await terminal.suspend {} }
                throw Boom()
            }
        }
        #expect(terminal.isRawModeEnabled)
        terminal.restore()
    }

    @Test func continueReentersRawModeAndModes() async throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.enableRawMode()
        terminal.setBracketedPaste(true)
        var events = terminal.events().makeAsyncIterator()
        _ = pty.read(until: "2004h")
        terminal.releaseTerminal()
        #expect(pty.read(until: "2004l").contains("\u{1B}[?2004l"))
        kill(getpid(), SIGCONT)
        #expect(await events.next() == .resize(terminal.size))
        #expect(pty.read(until: "2004h").contains("\u{1B}[?2004h"))
        #expect(terminal.isRawModeEnabled)
        terminal.restore()
        terminal.stopEvents()
    }

    @Test func continueWithNothingActiveDoesNothing() throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.reclaimTerminal()
        terminal.releaseTerminal()
        terminal.setAlternateScreen(true)
        terminal.enableRawMode()
        #expect(terminal.modes.alternateScreen)
        #expect(pty.drain().isEmpty)
        terminal.reclaimTerminal()
        #expect(pty.read(until: "1049h") == "\u{1B}[?1049h")
        terminal.restore()
    }
}
