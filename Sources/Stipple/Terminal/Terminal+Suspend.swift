#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension Terminal {
    /// Hands the terminal to a child process for the duration of `body`.
    ///
    /// Every mode is switched off, raw mode is left and input reading pauses,
    /// so the child gets a normal cooked terminal. When `body` returns or
    /// throws, the same modes and raw mode are set again, input reading
    /// resumes, and a `.resize` event asks the consumer to redraw.
    ///
    /// - Throws: ``TerminalError/alreadySuspended``, or whatever `body` throws.
    public func suspend<T>(_ body: () async throws -> T) async throws -> T {
        guard !isReleased else { throw TerminalError.alreadySuspended }
        stopReader()
        releaseTerminal()
        defer { reclaimTerminal() }
        return try await body()
    }

    /// Stops the process like Ctrl-Z does in a shell: gives the terminal back,
    /// raises `SIGTSTP`, and takes the terminal again once `SIGCONT` arrives.
    ///
    /// In raw mode Ctrl-Z arrives as byte `0x1A` instead of a signal; call this
    /// when the application decides to honour it.
    public func suspendProcess() {
        releaseTerminal()
        signal(SIGTSTP, SIG_DFL)
        raise(SIGTSTP)
        if eventState.continuation != nil { signal(SIGTSTP, SIG_IGN) }
    }

    /// Switches modes and raw mode off without forgetting them.
    func releaseTerminal() {
        guard !isReleased else { return }
        write(modes.restoreSequence)
        if let original = originalAttributes { TTY.apply(original, to: inputDescriptor) }
        isReleased = true
        refreshCrashRecord()
    }

    /// Sets raw mode and the modes again after `releaseTerminal()`, or after
    /// the process was stopped by a signal that could not be intercepted.
    func reclaimTerminal() {
        guard originalAttributes != nil || !modes.isEmpty else { return }
        if let original = originalAttributes { TTY.apply(TTY.raw(from: original), to: inputDescriptor) }
        write(modes.enterSequence)
        isReleased = false
        refreshCrashRecord()
        if eventState.continuation != nil {
            startReader()
            emitResize()
        }
    }
}
