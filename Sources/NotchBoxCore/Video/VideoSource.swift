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

    /// The video's own page on youtube.com, starting `start` seconds in.
    public static func watchPageURL(videoID: String, start: TimeInterval) -> URL {
        var components = URLComponents(string: "https://www.youtube.com/watch")!
        components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        let seconds = Int(start)
        if seconds > 0 { components.queryItems?.append(URLQueryItem(name: "t", value: "\(seconds)s")) }
        return components.url!
    }

    /// Embedded-player errors that only refuse the embed: 101 and 150 (the owner turned embedding off) and
    /// 152/153 (refused without a referrer). The video's own YouTube page still plays it.
    public static func isEmbeddingRefused(errorCode: Int) -> Bool {
        [101, 150, 152, 153].contains(errorCode)
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

/// Reading a browser's open tabs through its scripting dictionary, and picking the video to watch.
public enum BrowserTabs {
    /// Browsers whose scripting dictionary has windows → tabs with `URL` and a title property.
    private static let titleKeys: [String: String] = [
        "com.apple.Safari": "name",
        "com.google.Chrome": "title",
        "com.brave.Browser": "title",
        "com.microsoft.edgemac": "title",
        "com.vivaldi.Vivaldi": "title",
        "company.thebrowser.Browser": "title",
    ]

    public static func isSupportedBrowser(_ bundleIdentifier: String) -> Bool {
        titleKeys[bundleIdentifier] != nil
    }

    /// The tab property that holds the page title, or nil for apps that are not supported browsers.
    public static func titleKey(forBundleIdentifier bundleIdentifier: String) -> String? {
        titleKeys[bundleIdentifier]
    }

    /// Pairs a window's tab URLs with its tab titles (fetched as two lists); tabs without a URL are dropped.
    public static func tabs(urls: [String], titles: [String]) -> [BrowserTab] {
        urls.enumerated().compactMap { index, url in
            guard !url.isEmpty else { return nil }
            return BrowserTab(url: url, title: index < titles.count ? titles[index] : "")
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
