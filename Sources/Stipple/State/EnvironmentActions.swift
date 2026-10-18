/// Ends the app: `exit()` finishes `Stipple.run` normally, `exit(throwing:)`
/// makes it throw (Ink's `useApp().exit`).
public struct ExitAction: Sendable {
    let handler: @MainActor @Sendable ((any Error)?) -> Void

    /// Exits normally.
    @MainActor
    public func callAsFunction() {
        handler(nil)
    }

    /// Exits, making `Stipple.run` throw `error`.
    @MainActor
    public func callAsFunction(throwing error: any Error) {
        handler(error)
    }
}

/// Moves focus programmatically (Ink's `useFocusManager`).
@MainActor
public struct FocusManager {
    weak var controller: FocusController?

    /// Focuses the next focusable view.
    public func focusNext() {
        controller?.focusNext()
    }

    /// Focuses the previous focusable view.
    public func focusPrevious() {
        controller?.focusPrevious()
    }

    /// Clears focus.
    public func blur() {
        controller?.blur()
    }

    /// Turns Tab navigation and focus on or off.
    public func setEnabled(_ isEnabled: Bool) {
        controller?.isEnabled = isEnabled
        if !isEnabled { controller?.blur() }
    }
}

/// Writes to the terminal outside the live area: text appears above the
/// current frame and stays in scrollback (Ink's `useStdout().write` and
/// `useStderr().write`).
@MainActor
public struct TerminalWriter {
    let writeOutput: @MainActor @Sendable (String) -> Void
    let writeError: @MainActor @Sendable (String) -> Void

    /// Writes `text` to standard output above the live area.
    public func write(_ text: String) {
        writeOutput(text)
    }

    /// Writes `text` to standard error above the live area.
    public func writeError(_ text: String) {
        self.writeError(text)
    }
}

/// Gives the terminal to other code for a while, e.g. to run an editor or a
/// shell, and redraws afterwards (Ink's `suspendTerminal`). Raw mode, the
/// alternate screen and other modes are switched off during `body`.
///
/// ```swift
/// @Environment(\.suspendTerminal) private var suspendTerminal
/// try await suspendTerminal { try runEditor(file) }
/// ```
@MainActor
public struct SuspendTerminalAction {
    let handler: @MainActor (_ body: () async throws -> Void) async throws -> Void

    /// Runs `body` with the terminal handed back to the user, and returns its result.
    public func callAsFunction<T>(_ body: () async throws -> T) async throws -> T {
        var result: Result<T, any Error>?
        try await handler { result = .success(try await body()) }
        guard let result else { return try await body() }
        return try result.get()
    }
}

struct SuspendTerminalKey: EnvironmentKey {
    static var defaultValue: SuspendTerminalAction? { nil }
}

struct ExitActionKey: EnvironmentKey {
    static let defaultValue = ExitAction { _ in }
}

struct FocusManagerKey: EnvironmentKey {
    static let defaultValue: FocusManager? = nil
}

struct TerminalWriterKey: EnvironmentKey {
    static let defaultValue: TerminalWriter? = nil
}

struct TerminalSizeKey: EnvironmentKey {
    static let defaultValue = Size(width: 80, height: 24)
}

struct ScreenReaderKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Ends the app. Read it with `@Environment(\.exit)`.
    public var exit: ExitAction {
        get { self[ExitActionKey.self] }
        set { self[ExitActionKey.self] = newValue }
    }

    /// Hands the terminal to other code, e.g. a subprocess. Without a running
    /// app it just runs the body.
    @MainActor public var suspendTerminal: SuspendTerminalAction {
        get { self[SuspendTerminalKey.self] ?? SuspendTerminalAction { try await $0() } }
        set { self[SuspendTerminalKey.self] = newValue }
    }

    /// Moves focus programmatically.
    @MainActor public var focusManager: FocusManager {
        get { self[FocusManagerKey.self] ?? FocusManager(controller: nil) }
        set { self[FocusManagerKey.self] = newValue }
    }

    /// Writes above the live area.
    @MainActor public var terminal: TerminalWriter {
        get { self[TerminalWriterKey.self] ?? TerminalWriter(writeOutput: { _ in }, writeError: { _ in }) }
        set { self[TerminalWriterKey.self] = newValue }
    }

    /// The terminal's size in cells; views reading it update on resize (Ink's `useWindowSize`).
    public var terminalSize: Size {
        get { self[TerminalSizeKey.self] }
        set { self[TerminalSizeKey.self] = newValue }
    }

    /// Whether screen reader output is on (`STIPPLE_SCREEN_READER=true` or `RenderOptions`).
    public var isScreenReaderEnabled: Bool {
        get { self[ScreenReaderKey.self] }
        set { self[ScreenReaderKey.self] = newValue }
    }
}
