import AppKit
import Foundation

enum UpdateChecker {
    struct ReleaseInfo {
        let version: String
        let downloadURL: URL // the release's .zip asset, not the release's webpage
    }

    enum CheckError: LocalizedError {
        case badResponse
        case noReleases
        case noDownloadableAsset

        var errorDescription: String? {
            switch self {
            case .badResponse: return "Got an unexpected response from GitHub."
            case .noReleases: return "No releases have been published yet."
            case .noDownloadableAsset: return "The latest release doesn't have a downloadable build attached."
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
        struct Asset: Decodable { let name: String; let browser_download_url: String }
        struct Payload: Decodable { let tag_name: String; let assets: [Asset] }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let zipAsset = payload.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let downloadURL = URL(string: zipAsset.browser_download_url) else {
            throw CheckError.noDownloadableAsset
        }
        let version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        return ReleaseInfo(version: version, downloadURL: downloadURL)
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
    enum InstallError: LocalizedError {
        case noAppInZip

        var errorDescription: String? {
            "The downloaded update didn't contain an app."
        }
    }

    func checkForUpdates() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        Task {
            do {
                let release = try await UpdateChecker.fetchLatestRelease()
                if UpdateChecker.isNewer(release.version, than: current) {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(release.version) is available. You have \(current)."
                    alert.addButton(withTitle: "Update Now")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn {
                        await downloadAndReveal(from: release.downloadURL)
                    }
                } else {
                    showAlert(title: "You're Up to Date", message: "Version \(current) is the latest.")
                }
            } catch {
                showAlert(title: "Couldn't Check for Updates", message: error.localizedDescription)
            }
        }
    }

    /// Downloads the release zip and unzips it into Downloads, same place a
    /// browser download would land, then reveals it in Finder. Deliberately
    /// stops there rather than replacing the running app bundle itself: doing
    /// that would mean stripping the file's quarantine flag so the relaunch
    /// doesn't hit Gatekeeper, which permanently bypasses the OS check that
    /// warns before running new downloaded code -- not a tradeoff to make
    /// silently for an ad-hoc-signed (unnotarized) app. The user still does
    /// the same one-time "Open Anyway" approval per version as a fresh
    /// install, same as documented in the README.
    private func downloadAndReveal(from url: URL) async {
        do {
            let (tempZipURL, _) = try await URLSession.shared.download(from: url)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-o", "-q", tempZipURL.path, "-d", downloads.path]
            try unzip.run()
            unzip.waitUntilExit()

            guard let newAppURL = try FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "app" && $0.lastPathComponent.hasPrefix("DOAC Border") })
                .max(by: { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
                          < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }) else {
                throw InstallError.noAppInZip
            }

            NSWorkspace.shared.activateFileViewerSelecting([newAppURL])
            showAlert(title: "Update Downloaded",
                      message: "The new version is in Downloads. Drag it into Applications to replace the old one, then open it as usual.")
        } catch {
            showAlert(title: "Update Failed", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
