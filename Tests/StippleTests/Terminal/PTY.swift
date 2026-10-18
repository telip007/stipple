import Foundation

@testable import Stipple

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A pseudo-terminal pair: tests drive the controller side and give the device side to a `Terminal`.
final class PTY {
    let controller: Int32
    let device: Int32

    init(columns: UInt16 = 100, rows: UInt16 = 30) throws {
        let controller = unsafe open("/dev/ptmx", O_RDWR | O_NOCTTY)
        guard controller >= 0, let name = Self.deviceName(of: controller) else { throw PTYError.openFailed }
        let device = unsafe open(name, O_RDWR | O_NOCTTY)
        guard device >= 0 else { throw PTYError.openFailed }
        self.controller = controller
        self.device = device
        setSize(columns: columns, rows: rows)
    }

    /// Unlocks the pseudo-terminal behind `controller` and returns the path of its device side.
    private static func deviceName(of controller: Int32) -> String? {
        #if canImport(Darwin)
        guard grantpt(controller) == 0, unlockpt(controller) == 0, let name = unsafe ptsname(controller) else {
            return nil
        }
        return unsafe String(cString: name)
        #else
        var unlock: Int32 = 0
        var number: UInt32 = 0
        guard unsafe ioctl(controller, 0x4004_5431 as UInt, &unlock) == 0,
            unsafe ioctl(controller, 0x8004_5430 as UInt, &number) == 0
        else { return nil }
        return "/dev/pts/\(number)"
        #endif
    }

    deinit {
        close(controller)
        close(device)
    }

    func setSize(columns: UInt16, rows: UInt16) {
        var window = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        _ = unsafe ioctl(controller, UInt(TIOCSWINSZ), &window)
    }

    /// Sends bytes as if the user typed them.
    func type(_ text: String) {
        TTY.writeAll(controller, text)
    }

    /// Reads from the controller until `needle` shows up or the timeout passes; returns everything read.
    func read(until needle: String, timeout: Double = 3) -> String {
        var collected: [UInt8] = []
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            collected += drain(wait: 50)
            if (String(bytes: collected, encoding: .utf8) ?? "").contains(needle) { break }
        }
        return String(bytes: collected, encoding: .utf8) ?? ""
    }

    /// Reads whatever is available within `wait` milliseconds.
    func drain(wait: Int32 = 100) -> [UInt8] {
        var polled = pollfd(fd: controller, events: Int16(POLLIN), revents: 0)
        var out: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        while unsafe poll(&polled, 1, wait) > 0 {
            let count = unsafe systemRead(controller, &buffer, buffer.count)
            if count <= 0 { break }
            out += buffer[0..<count]
        }
        return out
    }

    @MainActor
    func terminal(environment: [String: String] = [:]) -> Terminal {
        Terminal(inputDescriptor: device, outputDescriptor: device, environment: environment)
    }
}

enum PTYError: Error {
    case openFailed
}

private func systemRead(_ descriptor: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
    unsafe read(descriptor, buffer, count)
}
