#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Thin wrappers over the termios and ioctl calls on a file descriptor.
/// Everything that signal handlers use is async-signal-safe.
enum TTY {
    /// The window size in cells, or `nil` if `descriptor` is not a terminal or reports 0×0.
    static func windowSize(_ descriptor: Int32) -> Size? {
        var window = winsize()
        guard unsafe ioctl(descriptor, UInt(TIOCGWINSZ), &window) == 0 else { return nil }
        guard window.ws_col > 0, window.ws_row > 0 else { return nil }
        return Size(width: Int(window.ws_col), height: Int(window.ws_row))
    }

    /// The current terminal attributes, or `nil` if `descriptor` is not a terminal.
    static func attributes(_ descriptor: Int32) -> termios? {
        var attributes = termios()
        return unsafe tcgetattr(descriptor, &attributes) == 0 ? attributes : nil
    }

    /// Sets the terminal attributes at once. `TCSADRAIN` would block until the
    /// terminal emulator has read all pending output, and a stuck emulator must not hang a restore.
    @discardableResult
    static func apply(_ attributes: termios, to descriptor: Int32) -> Bool {
        var attributes = attributes
        return unsafe tcsetattr(descriptor, TCSANOW, &attributes) == 0
    }

    /// Raw mode as libuv (and so Node and Ink) sets it: no line buffering,
    /// echo, signal keys or flow control, one byte minimum per read. Output
    /// processing stays on so `\n` still returns the carriage.
    static func raw(from original: termios) -> termios {
        var raw = original
        unsafe cfmakeraw(&raw)
        raw.c_oflag = original.c_oflag | tcflag_t(ONLCR)
        return raw
    }

    /// Writes all bytes, retrying on interrupts and full buffers. Async-signal-safe.
    static func writeAll(_ descriptor: Int32, _ bytes: UnsafeRawBufferPointer) {
        var offset = 0
        while offset < bytes.count {
            let written = unsafe write(descriptor, bytes.baseAddress.map { unsafe $0 + offset }, bytes.count - offset)
            if written > 0 {
                offset += written
            } else if written < 0 && (errno == EINTR || errno == EAGAIN) {
                var pending = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                _ = unsafe poll(&pending, 1, 10)
            } else {
                return
            }
        }
    }

    /// Writes a string.
    static func writeAll(_ descriptor: Int32, _ text: String) {
        var text = text
        text.withUTF8 { buffer in
            unsafe writeAll(descriptor, UnsafeRawBufferPointer(buffer))
        }
    }
}
