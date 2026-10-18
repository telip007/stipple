import Testing

@testable import Stipple

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The handlers are process-wide, so these tests run one at a time.
@Suite(.serialized)
struct CrashRestoreTests {
    @Test func restoreAllWritesBytesAndResetsAttributes() throws {
        let pty = try PTY()
        let original = try #require(TTY.attributes(pty.device))
        TTY.apply(TTY.raw(from: original), to: pty.device)
        let owner = CrashRestore.makeOwner()
        CrashRestore.register(
            owner: owner, inputDescriptor: pty.device, outputDescriptor: pty.device,
            attributes: original, restoreBytes: Array("\u{1B}[?25h".utf8))
        #expect(CrashRestore.isInstalled)
        CrashRestore.restoreAll()
        #expect(pty.read(until: "?25h") == "\u{1B}[?25h")
        let restored = try #require(TTY.attributes(pty.device))
        let touched = tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        #expect(restored.c_lflag & touched == original.c_lflag & touched)
        CrashRestore.unregister(owner: owner)
    }

    @Test func recordsAreReplacedPerOwnerAndHandlersLeaveWithTheLastOne() throws {
        let pty = try PTY()
        let first = CrashRestore.makeOwner()
        let second = CrashRestore.makeOwner()
        let baseline = CrashRestore.registeredCount
        for bytes in ["a", "bc"] {
            CrashRestore.register(
                owner: first, inputDescriptor: pty.device, outputDescriptor: pty.device,
                attributes: nil, restoreBytes: Array(bytes.utf8))
        }
        CrashRestore.register(
            owner: second, inputDescriptor: pty.device, outputDescriptor: pty.device,
            attributes: nil, restoreBytes: [])
        #expect(CrashRestore.registeredCount == baseline + 2)
        CrashRestore.unregister(owner: first)
        CrashRestore.unregister(owner: first)
        CrashRestore.unregister(owner: second)
        #expect(CrashRestore.registeredCount == baseline)
        if baseline == 0 { #expect(!CrashRestore.isInstalled) }
    }

    @Test func handlersAreInstalledForFatalSignalsAndIgnoredOnesAreKept() throws {
        let pty = try PTY()
        let ignoredBefore = signal(SIGHUP, SIG_IGN)
        defer { signal(SIGHUP, ignoredBefore) }
        let owner = CrashRestore.makeOwner()
        CrashRestore.register(
            owner: owner, inputDescriptor: pty.device, outputDescriptor: pty.device,
            attributes: nil, restoreBytes: [])
        for number in CrashRestore.fatalSignals where number != SIGHUP {
            var action = sigaction()
            #expect(unsafe sigaction(number, nil, &action) == 0)
            #if canImport(Darwin)
            #expect(unsafe unsafeBitCast(action.__sigaction_u.__sa_handler, to: Int.self) > 1)
            #else
            #expect(unsafe unsafeBitCast(action.__sigaction_handler.sa_handler, to: Int.self) > 1)
            #endif
        }
        var hangup = sigaction()
        _ = unsafe sigaction(SIGHUP, nil, &hangup)
        CrashRestore.unregister(owner: owner)
    }
}
