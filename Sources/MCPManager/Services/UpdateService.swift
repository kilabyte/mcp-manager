import Foundation

/// Checks for new releases on GitHub and compares against the running app version.
struct UpdateService: Sendable {

    static let releasesURL = URL(string: "https://github.com/kilabyte/mcp-manager/releases")!

    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/kilabyte/mcp-manager/releases/latest"
    )!

    /// The version baked into the running app bundle's Info.plist.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Fetches the latest release tag from GitHub and returns the version
    /// string (without the leading "v") if it is newer than the current version.
    /// Returns `nil` when the app is already up to date or the check fails.
    func checkForUpdate() async -> String? {
        do {
            var request = URLRequest(url: Self.latestReleaseAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return nil
            }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            if isNewer(latestVersion, than: currentVersion) {
                return latestVersion
            }
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Semantic Version Comparison

    /// Returns `true` when `a` is strictly newer than `b` using semver ordering.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
