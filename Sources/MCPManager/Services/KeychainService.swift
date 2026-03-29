import Foundation
import Security

/// Stores MCP Manager environment tokens in the macOS Keychain and injects
/// them into the current launchd session via `launchctl setenv` so that
/// GUI-launched processes (Claude Desktop, Cursor, etc.) can read them as
/// ordinary environment variables — without any shell sourcing required.
final class KeychainService: Sendable {

    static let keychainService = "com.mcp-manager"

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
        // Delete any existing item first to avoid ACL conflicts from prior builds.
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: entry.key
        ]
        SecItemDelete(deleteQuery as CFDictionary)  // ignore result — may not exist

        // Build an access object that allows ANY application to read this item
        // without prompting. Passing nil for trustedList means "all apps trusted"
        // (per SecAccessCreate docs). This prevents rebuild-to-rebuild ACL prompts.
        var access: SecAccess?
        SecAccessCreate("MCP Manager Secrets" as CFString, nil, &access)

        var addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: entry.key,
            kSecValueData: Data(entry.value.utf8)
        ]
        if let access {
            addQuery[kSecAttrAccess] = access
        }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }

        injectIntoLaunchEnvironment(key: entry.key, value: entry.value)
    }

    func updateEntry(_ entry: ValsEntry) throws {
        try addEntry(entry)   // add handles delete-then-insert (with correct ACL)
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

    /// Idempotent: checks which vals.zsh keys are missing from the Keychain
    /// and imports them. Safe to call every launch — it's a no-op once all
    /// entries are present. Handles the case where a previous migration
    /// silently failed due to Keychain ACL issues.
    func migrateFromValsFileIfNeeded(_ valsService: ValsFileService) {
        guard let valsEntries = try? valsService.loadEntries(),
              !valsEntries.isEmpty else { return }

        let existingKeys = Set(loadEntries().map(\.key))
        for entry in valsEntries where !existingKeys.contains(entry.key) {
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
