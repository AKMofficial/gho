import Foundation
import CoreServices

final class FSEventsWatcher: FileWatcherProtocol {

    private struct WatchEntry {
        let stream: FSEventStreamRef
        let unmanagedWrapper: Unmanaged<CallbackWrapper>
    }

    /// Active watches keyed by directory path string.
    private var watches: [String: WatchEntry] = [:]

    /// Dispatch queue for receiving FSEvent callbacks.
    private let queue = DispatchQueue(label: "com.gho.fswatcher", qos: .utility)

    func watch(directory: URL, callback: @escaping @MainActor () -> Void) {
        let path = directory.path

        stopWatching(directory: directory)

        // Watch .git subdirectory to detect git state changes (index, HEAD, refs)
        let gitDir = directory.appendingPathComponent(".git").path
        let pathsToWatch = [gitDir] as CFArray

        let wrapper = CallbackWrapper(callback: callback)
        let unmanagedWrapper = Unmanaged.passRetained(wrapper)

        var context = FSEventStreamContext(
            version: 0,
            info: unmanagedWrapper.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventsGetCurrentEventId(),
            0.3,  // 300ms latency for debouncing rapid changes
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        ) else {
            unmanagedWrapper.release()
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)

        watches[path] = WatchEntry(stream: stream, unmanagedWrapper: unmanagedWrapper)
    }

    func stopWatching(directory: URL) {
        let path = directory.path
        guard let entry = watches.removeValue(forKey: path) else { return }
        FSEventStreamStop(entry.stream)
        FSEventStreamInvalidate(entry.stream)
        FSEventStreamRelease(entry.stream)
        entry.unmanagedWrapper.release()
    }

    func stopAll() {
        let keys = Array(watches.keys)
        for path in keys {
            stopWatching(directory: URL(fileURLWithPath: path))
        }
    }

    deinit {
        stopAll()
    }
}

// MARK: - Callback Helpers

/// Wrapper class to pass a Swift closure through the C-style FSEvents callback.
private final class CallbackWrapper {
    let callback: @MainActor () -> Void

    init(callback: @escaping @MainActor () -> Void) {
        self.callback = callback
    }
}

/// C function pointer for FSEventStreamCreate.
private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(info).takeUnretainedValue()

    Task { @MainActor in
        wrapper.callback()
    }
}
