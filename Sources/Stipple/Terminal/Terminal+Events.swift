import Dispatch

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// What `events()` keeps alive: the stream, its reader and the signal sources.
struct EventState {
    var generation = 0
    var continuation: AsyncStream<TerminalEvent>.Continuation?
    var reader: InputReader?
    var sources: [any DispatchSourceSignal] = []
}

/// Signals watched through Dispatch while `events()` is active.
enum WatchedSignal: CaseIterable {
    case windowChange
    case stop
    case `continue`

    var number: Int32 {
        switch self {
        case .windowChange: SIGWINCH
        case .stop: SIGTSTP
        case .continue: SIGCONT
        }
    }
}

extension Terminal {
    /// The stream of terminal events: input bytes read off the main thread and
    /// resizes from `SIGWINCH`. It also reports a resize after the process
    /// continues from Ctrl-Z, so the consumer redraws.
    ///
    /// There is one stream at a time: calling this again ends the previous
    /// stream. The stream ends when its consumer stops, when input reaches
    /// end of file, or on ``stopEvents()``.
    public func events() -> AsyncStream<TerminalEvent> {
        stopEvents()
        let (stream, continuation) = AsyncStream<TerminalEvent>.makeStream()
        eventState.generation += 1
        let generation = eventState.generation
        eventState.continuation = continuation
        installSignalSources()
        if !isReleased { startReader() }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.endEvents(generation: generation) }
        }
        return stream
    }

    /// Ends the current event stream and stops reading input.
    public func stopEvents() {
        eventState.continuation?.finish()
        endEvents(generation: eventState.generation)
    }

    private func endEvents(generation: Int) {
        guard generation == eventState.generation else { return }
        eventState.generation += 1
        stopReader()
        eventState.continuation = nil
        for source in eventState.sources { source.cancel() }
        eventState.sources = []
        signal(SIGTSTP, SIG_DFL)
    }

    func startReader() {
        guard let continuation = eventState.continuation, eventState.reader == nil else { return }
        let reader = InputReader(descriptor: inputDescriptor)
        eventState.reader = reader
        reader.start(continuation)
    }

    func stopReader() {
        eventState.reader?.stop()
        eventState.reader = nil
    }

    /// Yields a `.resize` with the current size.
    func emitResize() {
        eventState.continuation?.yield(.resize(size))
    }

    private func installSignalSources() {
        signal(SIGTSTP, SIG_IGN)
        eventState.sources = WatchedSignal.allCases.map { kind in
            let source = DispatchSource.makeSignalSource(signal: kind.number, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.handle(kind) }
            }
            source.resume()
            return source
        }
    }

    func handle(_ signal: WatchedSignal) {
        switch signal {
        case .windowChange: emitResize()
        case .stop: suspendProcess()
        case .continue: reclaimTerminal()
        }
    }
}
