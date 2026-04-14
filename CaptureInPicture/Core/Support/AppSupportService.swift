import AppKit
import Foundation

struct AppVersionInfo: Equatable {
    let version: String
    let build: String

    var versionDisplayName: String {
        normalizedVersion
    }

    var buildDisplayName: String {
        build
    }

    var releaseComparisonValue: String {
        normalizedVersion
    }

    private var normalizedVersion: String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "1.0" : trimmed
    }
}

enum AppUpdateCheckResult: Equatable {
    case upToDate(latestVersion: String)
    case updateAvailable(latestVersion: String)
    case unavailable(reason: String)
}

enum SupportEmailKind {
    case feedback
    case bugReport

    var buttonTitle: String {
        switch self {
        case .feedback:
            return "Send Feedback"
        case .bugReport:
            return "Report a Bug"
        }
    }

    fileprivate var subject: String {
        switch self {
        case .feedback:
            return "[Capture in Picture] Feedback"
        case .bugReport:
            return "[Capture in Picture] Bug Report"
        }
    }

    fileprivate var introLine: String {
        switch self {
        case .feedback:
            return "Share any ideas, workflows, or friction points here:"
        case .bugReport:
            return "Describe what happened, what you expected, and how to reproduce it:"
        }
    }
}

final class AppSupportService {
    private struct GitHubReleaseResponse: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    private struct GitHubTagResponse: Decodable {
        let name: String
    }

    private enum VersionLookupError: Error {
        case notFound
        case invalidResponse
    }

    private let bundle: Bundle
    private let session: URLSession

    private let releaseLookupURL = URL(string: "https://api.github.com/repos/Cogi-Code-Studio/Capture-In-Picture/releases/latest")!
    private let tagLookupURL = URL(string: "https://api.github.com/repos/Cogi-Code-Studio/Capture-In-Picture/tags?per_page=1")!
    init(bundle: Bundle = .main, session: URLSession = .shared) {
        self.bundle = bundle
        self.session = session
    }

    var supportEmailAddress: String {
        "admin@cogicode.com"
    }

    func installedVersion() -> AppVersionInfo {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1"
        return AppVersionInfo(version: version, build: build)
    }

    func checkForUpdates() async -> AppUpdateCheckResult {
        let installedVersion = installedVersion()

        do {
            let publishedVersion = try await fetchLatestReleaseVersion()
            return compare(installedVersion: installedVersion, latestVersion: publishedVersion)
        } catch VersionLookupError.notFound {
            do {
                let publishedVersion = try await fetchLatestTagVersion()
                return compare(installedVersion: installedVersion, latestVersion: publishedVersion)
            } catch VersionLookupError.notFound {
                return .unavailable(reason: "No published release or tag is available yet.")
            } catch {
                return .unavailable(reason: "The app could not load the latest tag right now.")
            }
        } catch {
            return .unavailable(reason: "The app could not reach the update feed right now.")
        }
    }

    func openSupportEmail(_ kind: SupportEmailKind) -> Bool {
        guard let emailURL = makeSupportEmailURL(for: kind) else {
            return false
        }

        return NSWorkspace.shared.open(emailURL)
    }

    private func fetchLatestReleaseVersion() async throws -> String {
        let response: GitHubReleaseResponse = try await fetchJSON(from: releaseLookupURL)
        return normalizeVersionString(response.tagName)
    }

    private func fetchLatestTagVersion() async throws -> String {
        let response: [GitHubTagResponse] = try await fetchJSON(from: tagLookupURL)

        guard let latestTag = response.first?.name else {
            throw VersionLookupError.notFound
        }

        return normalizeVersionString(latestTag)
    }

    private func fetchJSON<Response: Decodable>(from url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CaptureInPicture", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VersionLookupError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(Response.self, from: data)
        case 404:
            throw VersionLookupError.notFound
        default:
            throw VersionLookupError.invalidResponse
        }
    }

    private func compare(installedVersion: AppVersionInfo, latestVersion: String) -> AppUpdateCheckResult {
        let comparison = installedVersion.releaseComparisonValue.compare(
            latestVersion,
            options: [.numeric, .caseInsensitive]
        )

        if comparison == .orderedAscending {
            return .updateAvailable(latestVersion: latestVersion)
        }

        return .upToDate(latestVersion: latestVersion)
    }

    private func normalizeVersionString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
        return withoutPrefix.isEmpty ? trimmed : withoutPrefix
    }

    private func makeSupportEmailURL(for kind: SupportEmailKind) -> URL? {
        let version = installedVersion()
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let body = """
        \(kind.introLine)

        

        App Version: \(version.versionDisplayName)
        Build: \(version.buildDisplayName)
        macOS: \(operatingSystemVersion)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: kind.subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
