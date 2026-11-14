import Foundation
import Testing
@testable import NotchBoxCore

struct YouTubeLinkTests {
    func id(_ string: String) -> String? { YouTubeLink.videoID(from: string) }

    @Test func readsWatchLinks() {
        #expect(id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/watch?app=desktop&v=dQw4w9WgXcQ&t=42s") == "dQw4w9WgXcQ")
        #expect(id("https://m.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RD") == "dQw4w9WgXcQ")
    }

    @Test func readsShortAndShortsLinks() {
        #expect(id("https://youtu.be/dQw4w9WgXcQ?t=10") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/live/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    }

    @Test func ignoresPagesWithoutAVideo() {
        #expect(id("https://www.youtube.com/") == nil)
        #expect(id("https://www.youtube.com/results?search_query=x") == nil)
        #expect(id("https://www.youtube.com/watch") == nil)
    }

    @Test func ignoresOtherSitesAndLookalikes() {
        #expect(id("https://vimeo.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(id("https://notyoutube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(id("not a url") == nil)
    }

    @Test func rejectsMalformedIDs() {
        #expect(id("https://www.youtube.com/watch?v=short") == nil)
        #expect(id("https://www.youtube.com/watch?v=dQw4w9WgXc%22") == nil)
    }

    @Test func watchPageStartsWhereTheBrowserWas() {
        #expect(YouTubeLink.watchPageURL(videoID: "dQw4w9WgXcQ", start: 42.7).absoluteString
            == "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s")
    }

    @Test func watchPageFromTheBeginningHasNoStartTime() {
        #expect(YouTubeLink.watchPageURL(videoID: "dQw4w9WgXcQ", start: 0).absoluteString
            == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(YouTubeLink.watchPageURL(videoID: "dQw4w9WgXcQ", start: -3).absoluteString
            == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test func embeddingRefusalsAreTheErrorsTheWatchPageGetsAround() {
        for code in [101, 150, 152, 153] {
            #expect(YouTubeLink.isEmbeddingRefused(errorCode: code))
        }
        // Bad request, HTML5 player failure, removed or private: the watch page cannot help.
        for code in [2, 5, 100] {
            #expect(!YouTubeLink.isEmbeddingRefused(errorCode: code))
        }
    }
}

struct BrowserTabsTests {
    @Test func tabTitleKeyDependsOnTheBrowsersScriptingDictionary() {
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.apple.Safari") == "name")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.google.Chrome") == "title")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.brave.Browser") == "title")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.microsoft.edgemac") == "title")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.vivaldi.Vivaldi") == "title")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "company.thebrowser.Browser") == "title")
        #expect(BrowserTabs.titleKey(forBundleIdentifier: "com.apple.Music") == nil)
    }

    @Test func isBrowserMatchesTheTitleKeys() {
        #expect(BrowserTabs.isSupportedBrowser("com.google.Chrome"))
        #expect(!BrowserTabs.isSupportedBrowser("com.spotify.client"))
    }

    @Test func zipsURLAndTitleListsIntoTabs() {
        let tabs = BrowserTabs.tabs(urls: ["https://a.com", "https://b.com"], titles: ["A", "B"])
        #expect(tabs == [BrowserTab(url: "https://a.com", title: "A"), BrowserTab(url: "https://b.com", title: "B")])
    }

    @Test func zipKeepsTabsWithoutATitleAndDropsEmptyURLs() {
        #expect(BrowserTabs.tabs(urls: ["https://a.com", "", "https://c.com"], titles: ["A"]) == [
            BrowserTab(url: "https://a.com", title: "A"),
            BrowserTab(url: "https://c.com", title: ""),
        ])
    }

    let tabs = [
        BrowserTab(url: "https://mail.example.com", title: "Inbox"),
        BrowserTab(url: "https://www.youtube.com/watch?v=AAAAAAAAAAA", title: "(3) Other video - YouTube"),
        BrowserTab(url: "https://www.youtube.com/watch?v=BBBBBBBBBBB", title: "Sena Şener - Alışılır Mı Aşka - YouTube"),
    ]

    @Test func prefersTheYouTubeTabWhoseTitleMatchesWhatIsPlaying() {
        #expect(BrowserTabs.pickYouTubeVideo(from: tabs, nowPlayingTitle: "Sena Şener - Alışılır Mı Aşka") == "BBBBBBBBBBB")
    }

    @Test func titleMatchIgnoresCase() {
        #expect(BrowserTabs.pickYouTubeVideo(from: tabs, nowPlayingTitle: "sena şener - alışılır mı aşka") == "BBBBBBBBBBB")
    }

    @Test func fallsBackToTheFirstYouTubeVideoTab() {
        #expect(BrowserTabs.pickYouTubeVideo(from: tabs, nowPlayingTitle: "Something else") == "AAAAAAAAAAA")
    }

    @Test func noYouTubeVideoTabGivesNil() {
        let other = [BrowserTab(url: "https://www.youtube.com/", title: "YouTube"), BrowserTab(url: "https://a.com", title: "A")]
        #expect(BrowserTabs.pickYouTubeVideo(from: other, nowPlayingTitle: "YouTube") == nil)
    }
}

struct VideoLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func videoIsOpenAndFlared() {
        #expect(NotchDisplayState.video.isOpen)
        #expect(NotchLayout.topCornerRadius(for: .video) == 12)
        #expect(NotchLayout.bottomCornerRadius(for: .video) == 20)
    }

    @Test func videoPlayerIsSixteenByNineInsideThePadding() {
        let player = NotchLayout.videoPlayerSize(notch: notch)
        #expect(player == CGSize(width: 432, height: 243))
    }

    @Test func videoPanelFitsThePlayerJustBelowTheNotch() {
        let tall = CGSize(width: 200, height: 50)
        let expected: CGFloat = 50 + 8 + 243 + 16
        #expect(NotchLayout.size(for: .video, notch: tall).height == expected)
    }
}
