import Foundation

// MARK: - Simple GitHub-releases-based update checker
// No Sparkle, no EdDSA keys — just poll the releases API and compare versions.

enum UpdateCheckResult {
    case upToDate(current: String)
    case updateAvailable(current: String, latest: String)
    case failed(String)
}

enum UpdateChecker {

    static let releasesAPI = URL(string: "https://api.github.com/repos/vishmathpati/mcpbolt/releases")!

    /// Fetch the newest `mac-v*` tag and compare with the bundle version.
    static func check() async -> UpdateCheckResult {
        let current = await MainActor.run { AppActions.currentVersion }

        var req = URLRequest(url: releasesAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("mcpboltbar", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return .failed("GitHub responded with HTTP \(http.statusCode).")
            }

            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return .failed("Unexpected response shape.")
            }

            // Pull every mac-v* tag, strip the prefix
            let versions: [String] = arr.compactMap { obj in
                guard let tag = obj["tag_name"] as? String, tag.hasPrefix("mac-v") else { return nil }
                return String(tag.dropFirst("mac-v".count))
            }

            guard let latest = versions.max(by: { compareSemver($0, $1) < 0 }) else {
                return .failed("No Mac releases found.")
            }

            if compareSemver(current, latest) < 0 {
                return .updateAvailable(current: current, latest: latest)
            }
            return .upToDate(current: current)

        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Returns -1 if a<b, 0 if equal, 1 if a>b. Non-numeric parts are treated as 0.
    private static func compareSemver(_ a: String, _ b: String) -> Int {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(ap.count, bp.count) {
            let ax = i < ap.count ? ap[i] : 0
            let bx = i < bp.count ? bp[i] : 0
            if ax < bx { return -1 }
            if ax > bx { return 1  }
        }
        return 0
    }
}
