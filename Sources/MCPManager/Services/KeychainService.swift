import Foundation
import Security

/// Stores MCP Manager environment tokens in the macOS Keychain and injects
/// them into the current launchd session via `launchctl setenv` so that
/// GUI-launched processes (Claude Desktop, Cursor, etc.) can read them as
/// ordinary environment variables — without any shell sourcing required.
final class KeychainService: Sendable {

    static let keychainService = "com.mcp-manager"
    private static let migrationKey = "keychainMigratedFromVals"

    // MARK: - CRUD

    func loadEntries() -> [ValsEntry] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[CFString: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let account = item[kSecAttrAccount] as? String,
                  let data = item[kSecValueData] as? Data,
                  let value = String(data: data, encoding: .utf8) else { return nil }
            return ValsEntry(key: account, value: value)
        }.sorted { $0.key < $1.key }
    }

    func addEntry(_ entry: ValsEntry) throws {
        // Try to update first; if not found, add new.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: entry.key
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(entry.value.utf8)
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = Data(entry.value.utf8)
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.osStatus(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.osStatus(updateStatus)
        }

        injectIntoLaunchEnvironment(key: entry.key, value: entry.value)
    }

    func updateEntry(_ entry: ValsEntry) throws {
        try addEntry(entry)   // add already handles upsert
    }

    func deleteEntry(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osStatus(status)
        }
        removeFromLaunchEnvironment(key: key)
    }

    // MARK: - Environment injection

    /// Call once at app launch to push all stored tokens into the current
    /// launchd session. After this, every GUI-launched subprocess will
    /// inherit them as regular env vars.
    func injectAllIntoEnvironment() {
        for entry in loadEntries() {
            injectIntoLaunchEnvironment(key: entry.key, value: entry.value)
        }
    }

    private func injectIntoLaunchEnvironment(key: String, value: String) {
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["setenv", key, value]
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func removeFromLaunchEnvironment(key: String) {
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["unsetenv", key]
            try? task.run()
            task.waitUntilExit()
        }
    }

    // MARK: - Migration from vals.zsh

    /// Silently imports any existing ~/.config/vals.zsh entries into the
    /// Keychain the first time the app runs with this feature. Safe to call
    /// every launch — a UserDefaults flag prevents re-running.
    func migrateFromValsFileIfNeeded(_ valsService: ValsFileService) {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: Self.migrationKey) }

        guard let entries = try? valsService.loadEntries(), !entries.isEmpty else { return }
        for entry in entries {
            try? addEntry(entry)
        }
    }

    // MARK: - Error

    enum KeychainError: LocalizedError {
        case osStatus(OSStatus)

        var errorDescription: String? {
            if let message = SecCopyErrorMessageString(osStatus, nil) as? String {
                return message
            }
            return "Keychain error (OSStatus \(osStatus))"
        }

        private var osStatus: OSStatus {
            if case .osStatus(let s) = self { return s }
            return 0
        }
    }
}
