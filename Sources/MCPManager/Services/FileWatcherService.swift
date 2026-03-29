import Foundation

/// Monitors config files for external changes using DispatchSource.
///
/// Public methods are MainActor-isolated (callers are always on MainActor).
/// Handler setup is nonisolated so closures don't inherit MainActor — they
/// fire on a GCD utility queue.
final class FileWatcherService: @unchecked Sendable {

    private var sources: [URL: (source: DispatchSourceFileSystemObject, fd: Int32)] = [:]

    @MainActor
    func watch(url: URL, onChange: @escaping @Sendable () -> Void) {
        stopWatching(url: url)

        let path = url.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        // Install handlers in a nonisolated context so the closures
        // are NOT MainActor-isolated — they run on the utility queue.
        Self.installHandlers(on: source, fd: fd, onChange: onChange)

        source.resume()
        sources[url] = (source, fd)
    }

    /// Nonisolated so the closures passed to setEventHandler / setCancelHandler
    /// do NOT inherit MainActor isolation. This prevents the Swift 6 runtime
    /// dispatch_assert_queue crash when GCD invokes them on the utility queue.
    private nonisolated static func installHandlers(
        on source: DispatchSourceFileSystemObject,
        fd: Int32,
        onChange: @escaping @Sendable () -> Void
    ) {
        var debounceWorkItem: DispatchWorkItem?

        source.setEventHandler {
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                onChange()
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }

        source.setCancelHandler {
            close(fd)
        }
    }

    @MainActor
    func stopWatching(url: URL) {
        guard let entry = sources.removeValue(forKey: url) else { return }
        entry.source.cancel()
    }

    @MainActor
    func stopAll() {
        for (_, entry) in sources {
            entry.source.cancel()
        }
        sources.removeAll()
    }

    deinit {
        for (_, entry) in sources {
            entry.source.cancel()
        }
    }
}
