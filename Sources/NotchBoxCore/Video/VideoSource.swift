import Foundation

/// Video IDs in YouTube links.
public enum YouTubeLink {
    /// The 11-character video ID of a youtube.com / youtu.be video page, or nil for anything else.
    public static func videoID(from string: String) -> String? {
        guard let components = URLComponents(string: string), let host = components.host?.lowercased() else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        var candidate: String?
        if host == "youtu.be" {
            candidate = parts.first
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            if components.path == "/watch" {
                candidate = components.queryItems?.first { $0.name == "v" }?.value
            } else if parts.count >= 2, ["shorts", "live", "embed"].contains(parts[0]) {
                candidate = parts[1]
            }
        }
        guard let candidate, isValidID(candidate) else { return nil }
        return candidate
    }

    static func isValidID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}

public struct BrowserTab: Equatable, Sendable {
    public var url: String
    public var title: String

    public init(url: String, title: String) {
        self.url = url
        self.title = title
    }
}

/// Reading a browser's open tabs with AppleScript (`osascript`), and picking the video to watch.
public enum BrowserTabs {
    /// Browsers whose AppleScript dictionary has windows → tabs with `URL` and a title property.
    private static let browsers: [String: (application: String, titleProperty: String)] = [
        "com.apple.Safari": ("Safari", "name"),
        "com.google.Chrome": ("Google Chrome", "title"),
        "com.brave.Browser": ("Brave Browser", "title"),
        "com.microsoft.edgemac": ("Microsoft Edge", "title"),
        "com.vivaldi.Vivaldi": ("Vivaldi", "title"),
        "company.thebrowser.Browser": ("Arc", "title"),
    ]

    public static func isSupportedBrowser(_ bundleIdentifier: String) -> Bool {
        browsers[bundleIdentifier] != nil
    }

    /// An AppleScript that returns one "URL<tab>title" line per open tab, or nil for other apps.
    public static func script(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let browser = browsers[bundleIdentifier] else { return nil }
        // `character id 9` instead of `tab`: in Safari's dictionary `tab` is a class.
        return """
        tell application "\(browser.application)"
            set output to ""
            repeat with w in windows
                repeat with t in tabs of w
                    set output to output & (URL of t) & (character id 9) & (\(browser.titleProperty) of t) & (character id 10)
                end repeat
            end repeat
            return output
        end tell
        """
    }

    public static func parse(_ output: String) -> [BrowserTab] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard let url = fields.first, !url.isEmpty else { return nil }
            return BrowserTab(url: String(url), title: fields.count > 1 ? String(fields[1]) : "")
        }
    }

    /// The video ID of the YouTube tab whose title contains what is playing; otherwise the first YouTube video tab.
    public static func pickYouTubeVideo(from tabs: [BrowserTab], nowPlayingTitle: String) -> String? {
        let videos = tabs.compactMap { tab in YouTubeLink.videoID(from: tab.url).map { (id: $0, title: tab.title) } }
        let wanted = nowPlayingTitle.lowercased()
        if !wanted.isEmpty, let match = videos.first(where: { $0.title.lowercased().contains(wanted) }) {
            return match.id
        }
        return videos.first?.id
    }
}
