import Foundation

/// Monitors config files for external changes using DispatchSource.
@MainActor
final class FileWatcherService {

    private var sources: [URL: (source: DispatchSourceFileSystemObject, fd: Int32)] = [:]

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

        // Debounce: wait 300ms after event to coalesce rapid writes
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

        source.resume()
        sources[url] = (source, fd)
    }

    func stopWatching(url: URL) {
        guard let entry = sources.removeValue(forKey: url) else { return }
        entry.source.cancel()
    }

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
