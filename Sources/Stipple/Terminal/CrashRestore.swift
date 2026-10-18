import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// What a signal handler needs to put one terminal back: the descriptors, the
/// attributes from before raw mode, and the bytes that undo the active modes.
/// Allocated with `UnsafeMutablePointer` and never mutated after it is published.
@unsafe
struct RestoreRecord {
    var inputDescriptor: Int32
    var outputDescriptor: Int32
    var attributes: termios?
    var bytes: UnsafeMutablePointer<UInt8>
    var count: Int
}

/// Crash-safe terminal restore.
///
/// Signal handlers may only call async-signal-safe functions, so they cannot
/// touch Swift collections, locks or the allocator. Each live `Terminal` keeps
/// a precomputed `RestoreRecord` here. The records are listed in an immutable
/// snapshot (`[count, address, address, …]`) published through an atomic, which
/// the handler reads with plain loads. Replaced records and snapshots are
/// retired, not freed, until no terminal needs restoring any more.
enum CrashRestore {
    /// Signals that kill the process without running `atexit`.
    static let fatalSignals: [Int32] = [
        SIGTERM, SIGHUP, SIGQUIT, SIGINT, SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE,
    ]

    private struct Registry {
        var records: [UInt64: UInt] = [:]
        var retiredRecords: [UInt] = []
        var retiredSnapshots: [UInt] = []
        var installed = false
        var previous: [Int32: sigaction] = [:]
        var alternateStack: UInt = 0
    }

    private static let snapshot = Atomic<UInt>(0)
    private static let registry = Mutex(Registry())
    private static let nextOwner = Atomic<UInt64>(1)
    private static let atExitRegistered: Void = {
        atexit { Self.restoreAll() }
    }()

    /// A fresh identifier for one terminal.
    static func makeOwner() -> UInt64 {
        nextOwner.wrappingAdd(1, ordering: .relaxed).oldValue
    }

    /// Number of terminals currently registered.
    static var registeredCount: Int { registry.withLock { $0.records.count } }

    /// Whether the crash handlers are installed.
    static var isInstalled: Bool { registry.withLock { $0.installed } }

    /// Registers or replaces the restore record of `owner` and makes sure the handlers are installed.
    static func register(
        owner: UInt64,
        inputDescriptor: Int32,
        outputDescriptor: Int32,
        attributes: termios?,
        restoreBytes: [UInt8],
    ) {
        _ = atExitRegistered
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: max(restoreBytes.count, 1))
        unsafe bytes.initialize(from: restoreBytes, count: restoreBytes.count)
        let record = UnsafeMutablePointer<RestoreRecord>.allocate(capacity: 1)
        unsafe record.initialize(
            to: RestoreRecord(
                inputDescriptor: inputDescriptor,
                outputDescriptor: outputDescriptor,
                attributes: attributes,
                bytes: bytes,
                count: restoreBytes.count,
            ))
        registry.withLock { state in
            if let old = state.records.updateValue(UInt(bitPattern: record), forKey: owner) {
                state.retiredRecords.append(old)
            }
            publish(&state)
            if !state.installed { installHandlers(&state) }
        }
    }

    /// Drops the record of `owner`; the handlers are removed when no terminal is left.
    static func unregister(owner: UInt64) {
        registry.withLock { state in
            guard let old = state.records.removeValue(forKey: owner) else { return }
            state.retiredRecords.append(old)
            publish(&state)
            if state.records.isEmpty {
                uninstallHandlers(&state)
                snapshot.store(0, ordering: .releasing)
                freeRetired(&state)
            }
        }
    }

    /// Restores every registered terminal. Async-signal-safe: it only loads an
    /// atomic and calls `write` and `tcsetattr`.
    static func restoreAll() {
        let address = snapshot.load(ordering: .acquiring)
        guard address != 0, let list = unsafe UnsafeMutablePointer<UInt>(bitPattern: address) else { return }
        for index in 0..<Int(unsafe list[0]) {
            guard let record = unsafe UnsafeMutablePointer<RestoreRecord>(bitPattern: unsafe list[index + 1]) else {
                continue
            }
            unsafe TTY.writeAll(
                record.pointee.outputDescriptor,
                UnsafeRawBufferPointer(start: record.pointee.bytes, count: record.pointee.count))
            if let attributes = unsafe record.pointee.attributes {
                var restored = attributes
                _ = unsafe tcsetattr(record.pointee.inputDescriptor, TCSANOW, &restored)
            }
        }
    }

    /// The default handler's job: restore, then die of the same signal.
    fileprivate static func handle(_ number: Int32) {
        restoreAll()
        signal(number, SIG_DFL)
        raise(number)
    }

    // MARK: Registry internals (called with the lock held)

    private static func publish(_ state: inout Registry) {
        let owners = Array(state.records.values)
        let list = UnsafeMutablePointer<UInt>.allocate(capacity: owners.count + 1)
        unsafe list[0] = UInt(owners.count)
        for (index, address) in owners.enumerated() { unsafe list[index + 1] = address }
        let previous = snapshot.exchange(UInt(bitPattern: list), ordering: .acquiringAndReleasing)
        if previous != 0 { state.retiredSnapshots.append(previous) }
    }

    private static func freeRetired(_ state: inout Registry) {
        for address in state.retiredSnapshots {
            unsafe UnsafeMutablePointer<UInt>(bitPattern: address)?.deallocate()
        }
        for address in state.retiredRecords {
            guard let record = unsafe UnsafeMutablePointer<RestoreRecord>(bitPattern: address) else { continue }
            unsafe record.pointee.bytes.deallocate()
            unsafe record.deallocate()
        }
        state.retiredSnapshots.removeAll()
        state.retiredRecords.removeAll()
    }

    private static func installHandlers(_ state: inout Registry) {
        installAlternateStack(&state)
        for number in fatalSignals {
            var old = sigaction()
            guard unsafe sigaction(number, nil, &old) == 0, !Self.isIgnored(old) else { continue }
            var action = sigaction()
            Self.setHandler(&action)
            unsafe sigemptyset(&action.sa_mask)
            action.sa_flags =
                Int32(truncatingIfNeeded: SA_ONSTACK) | Int32(truncatingIfNeeded: SA_RESETHAND)
                | Int32(truncatingIfNeeded: SA_NODEFER)
            if unsafe sigaction(number, &action, nil) == 0 { state.previous[number] = old }
        }
        state.installed = true
    }

    private static func uninstallHandlers(_ state: inout Registry) {
        for (number, old) in state.previous {
            var old = old
            _ = unsafe sigaction(number, &old, nil)
        }
        state.previous.removeAll()
        state.installed = false
    }

    private static func installAlternateStack(_ state: inout Registry) {
        guard state.alternateStack == 0 else { return }
        let size = 64 * 1024
        let memory = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        var stack = unsafe stack_t()
        unsafe stack.ss_sp = memory
        unsafe stack.ss_size = size
        unsafe stack.ss_flags = 0
        if unsafe sigaltstack(&stack, nil) == 0 {
            state.alternateStack = UInt(bitPattern: memory)
        } else {
            unsafe memory.deallocate()
        }
    }

    private static func setHandler(_ action: inout sigaction) {
        #if canImport(Darwin)
        unsafe action.__sigaction_u.__sa_handler = crashSignalHandler
        #else
        unsafe action.__sigaction_handler.sa_handler = crashSignalHandler
        #endif
    }

    private static func isIgnored(_ action: sigaction) -> Bool {
        #if canImport(Darwin)
        let handler = unsafe action.__sigaction_u.__sa_handler
        #else
        let handler = unsafe action.__sigaction_handler.sa_handler
        #endif
        return unsafe unsafeBitCast(handler, to: Int.self) == 1
    }
}

private func crashSignalHandler(_ number: Int32) {
    CrashRestore.handle(number)
}
