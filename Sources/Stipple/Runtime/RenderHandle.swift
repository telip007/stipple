/// A running Stipple app (Ink's `Instance`).
@MainActor
public final class RenderHandle {
    let runtime: Runtime

    init(runtime: Runtime) {
        self.runtime = runtime
    }

    /// Waits until the app exits. Throws the error passed to `exit(throwing:)`.
    public func waitUntilExit() async throws {
        try await runtime.waitUntilExit()
    }

    /// Exits the app now, as if `exit()` was called.
    public func unmount() {
        runtime.exit(with: nil)
    }

    /// Erases the current frame.
    public func clear() {
        runtime.writer.clear()
    }

    /// Replaces the root view. State is kept when the type is unchanged.
    public func rerender(_ view: some View) {
        runtime.replaceRoot(view)
    }
}

extension Stipple {
    /// Starts rendering `view` and returns immediately.
    @MainActor
    @discardableResult
    public static func render(_ view: some View, options: RenderOptions = RenderOptions()) -> RenderHandle {
        RenderHandle(runtime: Runtime(view: view, options: options, terminal: Terminal()))
    }

    /// Renders `view` until it exits, then restores the terminal.
    /// Throws the error passed to `exit(throwing:)`.
    @MainActor
    public static func run(_ view: some View, options: RenderOptions = RenderOptions()) async throws {
        try await render(view, options: options).waitUntilExit()
    }
}
