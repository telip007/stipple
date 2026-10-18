import Dispatch
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Reads a file descriptor on a background queue and yields the bytes as
/// `.input` events. `stop()` wakes the reader through a pipe and waits until
/// it has stopped, so a child process can take over the descriptor safely.
final class InputReader: Sendable {
    private struct Running {
        var wakeReader: Int32
        var wakeWriter: Int32
        var finished: DispatchSemaphore
    }

    private let descriptor: Int32
    private let running = Mutex<Running?>(nil)

    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    /// Starts reading. Does nothing if already started.
    func start(_ continuation: AsyncStream<TerminalEvent>.Continuation) {
        running.withLock { state in
            guard state == nil else { return }
            var pipeEnds: [Int32] = [-1, -1]
            guard unsafe pipe(&pipeEnds) == 0 else {
                continuation.finish()
                return
            }
            let finished = DispatchSemaphore(value: 0)
            state = Running(wakeReader: pipeEnds[0], wakeWriter: pipeEnds[1], finished: finished)
            let descriptor = descriptor
            let wakeReader = pipeEnds[0]
            DispatchQueue(label: "stipple.terminal.input").async {
                Self.loop(descriptor, wakeReader, continuation)
                finished.signal()
            }
        }
    }

    /// Stops reading and waits for the reader to leave. Safe to call twice.
    func stop() {
        let taken = running.withLock { state -> Running? in
            defer { state = nil }
            return state
        }
        guard let taken else { return }
        var byte: UInt8 = 0
        _ = unsafe write(taken.wakeWriter, &byte, 1)
        taken.finished.wait()
        close(taken.wakeWriter)
        close(taken.wakeReader)
    }

    private static func loop(
        _ descriptor: Int32,
        _ wakeReader: Int32,
        _ continuation: AsyncStream<TerminalEvent>.Continuation,
    ) {
        var polled = [
            pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0),
            pollfd(fd: wakeReader, events: Int16(POLLIN), revents: 0),
        ]
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let ready = unsafe poll(&polled, 2, -1)
            if ready < 0 && errno == EINTR { continue }
            if ready < 0 || polled[1].revents != 0 { return }
            guard polled[0].revents != 0 else { continue }
            let count = unsafe read(descriptor, &buffer, buffer.count)
            if count > 0 {
                continuation.yield(.input(Array(buffer[0..<count])))
            } else if count == 0 || (errno != EINTR && errno != EAGAIN) {
                continuation.finish()
                return
            }
        }
    }
}
