import Foundation

/// A release version: up to three numbers ("0.4.0", "v1.2"); missing parts count as 0.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        while numbers.count < 3 { numbers.append(0) }
        (major, minor, patch) = (numbers[0], numbers[1], numbers[2])
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// The newest published release on GitHub.
public struct LatestRelease: Equatable, Sendable {
    public let version: AppVersion
    /// The release page, with its notes.
    public let pageURL: URL

    public init(version: AppVersion, pageURL: URL) {
        self.version = version
        self.pageURL = pageURL
    }

    /// Reads GitHub's "latest release" response; nil for drafts, pre-releases and anything unexpected.
    public static func parse(_ data: Data) -> LatestRelease? {
        struct Response: Decodable {
            let tag_name: String
            let html_url: String
            let draft: Bool?
            let prerelease: Bool?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.draft != true, response.prerelease != true,
              let version = AppVersion(response.tag_name),
              let url = URL(string: response.html_url)
        else { return nil }
        return LatestRelease(version: version, pageURL: url)
    }
}

/// When and where NotchBox looks for a newer release, and how it installs one.
public enum UpdateCheck {
    public static let repository = "cyesaa/notch-box"
    public static let launchDelay: TimeInterval = 15
    public static let interval: TimeInterval = 12 * 60 * 60

    public static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// The one-line installer; running it again updates NotchBox in place.
    public static var installCommand: String {
        "curl -fsSL https://raw.githubusercontent.com/\(repository)/main/install.sh | bash"
    }

    public static func availableUpdate(current: AppVersion, latest: LatestRelease?) -> LatestRelease? {
        guard let latest, current < latest.version else { return nil }
        return latest
    }
}
