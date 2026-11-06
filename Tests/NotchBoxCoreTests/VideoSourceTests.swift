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
}

struct BrowserTabsTests {
    @Test func scriptsExistForSafariAndChromeFamilyBrowsers() {
        #expect(BrowserTabs.script(forBundleIdentifier: "com.apple.Safari")?.contains("\"Safari\"") == true)
        #expect(BrowserTabs.script(forBundleIdentifier: "com.google.Chrome")?.contains("\"Google Chrome\"") == true)
        #expect(BrowserTabs.script(forBundleIdentifier: "com.brave.Browser")?.contains("\"Brave Browser\"") == true)
        #expect(BrowserTabs.script(forBundleIdentifier: "com.microsoft.edgemac")?.contains("\"Microsoft Edge\"") == true)
        #expect(BrowserTabs.script(forBundleIdentifier: "com.apple.Music") == nil)
    }

    @Test func isBrowserMatchesTheScripts() {
        #expect(BrowserTabs.isSupportedBrowser("com.google.Chrome"))
        #expect(!BrowserTabs.isSupportedBrowser("com.spotify.client"))
    }

    @Test func parsesTabLines() {
        let output = "https://a.com\tA page\nhttps://www.youtube.com/watch?v=dQw4w9WgXcQ\tSong - YouTube\n\n"
        #expect(BrowserTabs.parse(output) == [
            BrowserTab(url: "https://a.com", title: "A page"),
            BrowserTab(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", title: "Song - YouTube"),
        ])
    }

    @Test func parseKeepsTabsWithoutATitle() {
        #expect(BrowserTabs.parse("https://a.com\n") == [BrowserTab(url: "https://a.com", title: "")])
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

    @Test func videoPanelFitsBarAndPlayerBelowTheNotch() {
        #expect(NotchLayout.size(for: .video, notch: notch) == CGSize(width: 464, height: 32 + 8 + 30 + 8 + 243 + 16))
        let tall = CGSize(width: 200, height: 50)
        let expected: CGFloat = 50 + 8 + 30 + 8 + 243 + 16
        #expect(NotchLayout.size(for: .video, notch: tall).height == expected)
    }

    @Test func windowCoversTheVideoPanel() {
        #expect(NotchLayout.maxSize(notch: notch) == CGSize(width: 464, height: 337))
    }
}
