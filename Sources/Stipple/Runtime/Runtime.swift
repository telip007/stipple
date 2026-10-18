/// Drives one app: owns the view graph, the terminal and the frame writer,
/// turns input into key events, and renders at most `maxFps` frames a second
/// (Ink's `Ink` class and `App` component).
@MainActor
final class Runtime {
    let terminal: any TerminalHost
    let writer: FrameWriter
    let graph = ViewGraph()
    let options: RenderOptions
    private var rootView: any View
    private var parser = InputParser()
    private var eventTask: Task<Void, Never>?
    private var escapeTask: Task<Void, Never>?
    private(set) var renderTask: Task<Void, Never>?
    private var lastRender: ContinuousClock.Instant?
    private var exitWaiters: [CheckedContinuation<Void, any Error>] = []
    private var exitResult: Result<Void, any Error>?
    private let clock = ContinuousClock()

    init(view: some View, options: RenderOptions, terminal: any TerminalHost) {
        self.terminal = terminal
        self.options = options
        rootView = view
        let interactive = options.interactive ?? terminal.isInteractive
        writer = FrameWriter(
            output: terminal,
            options: FrameWriterOptions(
                alternateScreen: options.alternateScreen,
                incremental: options.incrementalRendering,
                debug: options.debug,
                interactive: interactive,
            ),
        )
        graph.onNeedsRender = { [weak self] in self?.scheduleRender() }
        start(interactive: interactive)
    }

    var isInteractive: Bool { writer.interactive }

    private func start(interactive: Bool) {
        if interactive {
            terminal.noteModes(alternateScreen: writer.alternateScreen, cursorHidden: !writer.options.showCursor)
        }
        if interactive, terminal.isInputTerminal, terminal.enableRawMode() {
            terminal.setBracketedPaste(true)
            configureKeyboard()
        }
        graph.mount(AnyView(rootView), environment: makeEnvironment())
        render()
        if interactive {
            listen()
        }
    }

    private func configureKeyboard() {
        switch options.keyboardProtocol {
        case .legacy: break
        case .automatic: terminal.queryKittyKeyboard()
        case .kitty(let flags): terminal.pushKittyKeyboard(flags)
        }
    }

    func makeEnvironment() -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.exit = ExitAction { [weak self] error in self?.exit(with: error) }
        environment.focusManager = FocusManager(controller: graph.focus)
        environment.terminal = TerminalWriter(
            writeOutput: { [weak self] in self?.writer.writeAbove($0) },
            writeError: { [weak self] text in self?.writeErrorAbove(text) },
        )
        environment.terminalSize = terminal.size
        environment.isScreenReaderEnabled = options.isScreenReaderEnabled ?? false
        return environment
    }

    private func writeErrorAbove(_ text: String) {
        writer.clear()
        terminal.writeError(text)
        render()
    }

    /// Replaces the root view, keeping state when its type is unchanged.
    func replaceRoot(_ view: some View) {
        rootView = view
        graph.update(AnyView(view), environment: makeEnvironment())
        render()
    }

    // MARK: Events

    private func listen() {
        let events = terminal.events()
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    func handle(_ event: TerminalEvent) {
        switch event {
        case .input(let bytes):
            for input in parser.parse(bytes) {
                handle(input)
            }
            scheduleEscapeFlush()
        case .resize:
            writer.resized()
            graph.update(AnyView(rootView), environment: makeEnvironment())
            render()
        }
    }

    private func scheduleEscapeFlush() {
        escapeTask?.cancel()
        guard parser.hasPendingInput else { return }
        escapeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            for input in self.parser.flushPendingEscape() {
                self.handle(input)
            }
        }
    }

    // MARK: Rendering

    /// Renders now if the last frame is older than the frame interval,
    /// otherwise once the interval has passed (leading and trailing edge, as
    /// Ink's throttle). Changes in the same main-actor turn are batched.
    func scheduleRender() {
        guard renderTask == nil, exitResult == nil else { return }
        let interval = Duration.seconds(1) / max(1, options.maxFps)
        let delay = lastRender.map { max(.zero, interval - (clock.now - $0)) } ?? .zero
        renderTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            } else {
                await Task.yield()
            }
            guard let self else { return }
            self.renderTask = nil
            self.render()
        }
    }

    /// Rebuilds invalidated views, lays out, and writes the frame.
    func render() {
        guard exitResult == nil else { return }
        lastRender = clock.now
        let frame = produceFrame()
        writer.setCursorPosition(frame.cursor)
        writer.write(frame: frame.text, height: frame.height, staticOutput: frame.staticOutput)
    }

    struct ProducedFrame {
        var text: String
        var height: Int
        var staticOutput: String
        var cursor: CursorPosition?
    }

    func produceFrame() -> ProducedFrame {
        let size = terminal.size
        let height = writer.alternateScreen ? size.height : nil
        var staticOutput = ""
        var result = FrameRenderer.Result(frame: "", height: 0)
        // Geometry readers and geometry callbacks may change state during
        // layout; lay out again until the graph settles.
        for _ in 0..<4 {
            graph.flush()
            staticOutput += graph.takeStaticOutput(width: size.width)
            result = FrameRenderer(graph: graph).render(width: size.width, height: height)
            graph.runGeometryCallbacks()
            if !graph.hasPendingWork { break }
        }
        return ProducedFrame(
            text: result.frame, height: result.height, staticOutput: staticOutput, cursor: graph.cursorPosition)
    }

    // MARK: Exit

    func exit(with error: (any Error)?) {
        guard exitResult == nil else { return }
        let frame = produceFrame()
        exitResult = error.map { .failure($0) } ?? .success(())
        renderTask?.cancel()
        escapeTask?.cancel()
        eventTask?.cancel()
        writer.setCursorPosition(frame.cursor)
        writer.finish(
            finalFrame: FrameWriter.Frame(text: frame.text, height: frame.height, staticOutput: frame.staticOutput))
        graph.unmountAll()
        terminal.restore()
        let waiters = exitWaiters
        exitWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(with: exitResult ?? .success(()))
        }
    }

    func waitUntilExit() async throws {
        if let exitResult {
            try exitResult.get()
            return
        }
        try await withCheckedThrowingContinuation { exitWaiters.append($0) }
    }
}

extension Runtime {
    /// Waits until queued invalidations and the pending frame are done. For tests.
    func settle() async {
        for _ in 0..<20 {
            await Task.yield()
            if let renderTask {
                await renderTask.value
            }
        }
    }
}
