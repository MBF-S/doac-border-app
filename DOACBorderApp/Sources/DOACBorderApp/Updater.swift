import AppKit
import Foundation

enum UpdateChecker {
    struct ReleaseInfo {
        let version: String
        let htmlURL: URL
    }

    enum CheckError: LocalizedError {
        case badResponse
        case noReleases

        var errorDescription: String? {
            switch self {
            case .badResponse: return "Got an unexpected response from GitHub."
            case .noReleases: return "No releases have been published yet."
            }
        }
    }

    static let repo = "MBF-S/doac-border-app"

    /// GitHub's releases API is public and unauthenticated for public repos.
    static func fetchLatestRelease() async throws -> ReleaseInfo {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            throw CheckError.badResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CheckError.noReleases
        }
        struct Payload: Decodable { let tag_name: String; let html_url: String }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let releaseURL = URL(string: payload.html_url) else { throw CheckError.badResponse }
        let version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        return ReleaseInfo(version: version, htmlURL: releaseURL)
    }

    /// Dotted-integer version compare (e.g. "1.10" > "1.9"). Missing components count as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let c = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(c.count, b.count) {
            let cv = i < c.count ? c[i] : 0
            let bv = i < b.count ? b[i] : 0
            if cv != bv { return cv > bv }
        }
        return false
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    func checkForUpdates() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        Task {
            do {
                let release = try await UpdateChecker.fetchLatestRelease()
                if UpdateChecker.isNewer(release.version, than: current) {
                    showAlert(
                        title: "Update Available",
                        message: "Version \(release.version) is available. You have \(current).",
                        actionTitle: "Open Release Page", url: release.htmlURL
                    )
                } else {
                    showAlert(title: "You're Up to Date", message: "Version \(current) is the latest.")
                }
            } catch {
                showAlert(title: "Couldn't Check for Updates", message: error.localizedDescription)
            }
        }
    }

    private func showAlert(title: String, message: String, actionTitle: String? = nil, url: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        if let actionTitle {
            alert.addButton(withTitle: actionTitle)
            alert.addButton(withTitle: "Later")
        } else {
            alert.addButton(withTitle: "OK")
        }
        if alert.runModal() == .alertFirstButtonReturn, let url {
            NSWorkspace.shared.open(url)
        }
    }
}
