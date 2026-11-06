import Foundation
import Testing
@testable import NotchBoxCore

struct AppVersionTests {
    @Test func parsesTagsAndBundleVersions() {
        #expect(AppVersion("0.4.0")?.description == "0.4.0")
        #expect(AppVersion("v1.2.3")?.description == "1.2.3")
        #expect(AppVersion("V2.0")?.description == "2.0.0")
        #expect(AppVersion(" 3 ")?.description == "3.0.0")
    }

    @Test func rejectsWhatIsNotAVersion() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1.x") == nil)
        #expect(AppVersion("1.2.3.4") == nil)
        #expect(AppVersion("1.2.3-beta") == nil)
    }

    @Test func comparesNumericallyPartByPart() throws {
        let v = { (s: String) throws -> AppVersion in try #require(AppVersion(s)) }
        #expect(try v("0.4.0") < v("0.4.1"))
        #expect(try v("0.4.9") < v("0.10.0"))
        #expect(try v("0.9.9") < v("1.0.0"))
        #expect(try v("1.0") == v("1.0.0"))
        #expect(try !(v("0.4.0") < v("0.4.0")))
    }
}

struct LatestReleaseTests {
    func json(_ fields: String) -> Data { Data("{\(fields)}".utf8) }

    @Test func readsTheTagAndPage() {
        let release = LatestRelease.parse(json(#""tag_name": "v0.5.0", "html_url": "https://github.com/cyesaa/notch-box/releases/tag/v0.5.0", "draft": false, "prerelease": false"#))
        #expect(release?.version.description == "0.5.0")
        #expect(release?.pageURL.absoluteString == "https://github.com/cyesaa/notch-box/releases/tag/v0.5.0")
    }

    @Test func skipsDraftsPrereleasesAndJunk() {
        #expect(LatestRelease.parse(json(#""tag_name": "v0.5.0", "html_url": "https://x.y", "draft": true"#)) == nil)
        #expect(LatestRelease.parse(json(#""tag_name": "v0.5.0", "html_url": "https://x.y", "prerelease": true"#)) == nil)
        #expect(LatestRelease.parse(json(#""tag_name": "nightly", "html_url": "https://x.y""#)) == nil)
        #expect(LatestRelease.parse(json(#""message": "Not Found""#)) == nil)
        #expect(LatestRelease.parse(Data("not json".utf8)) == nil)
    }
}

struct UpdateCheckTests {
    let current = AppVersion("0.4.0")!

    func release(_ version: String) -> LatestRelease {
        LatestRelease(version: AppVersion(version)!, pageURL: URL(string: "https://example.com")!)
    }

    @Test func onlyANewerReleaseIsAnUpdate() {
        #expect(UpdateCheck.availableUpdate(current: current, latest: release("0.5.0")) == release("0.5.0"))
        #expect(UpdateCheck.availableUpdate(current: current, latest: release("0.4.0")) == nil)
        #expect(UpdateCheck.availableUpdate(current: current, latest: release("0.3.9")) == nil)
        #expect(UpdateCheck.availableUpdate(current: current, latest: nil) == nil)
    }

    @Test func checksSoonAfterLaunchThenTwiceADay() {
        #expect(UpdateCheck.launchDelay == 15)
        #expect(UpdateCheck.interval == 12 * 60 * 60)
    }

    @Test func pointsAtThisRepository() {
        #expect(UpdateCheck.latestReleaseURL.absoluteString == "https://api.github.com/repos/cyesaa/notch-box/releases/latest")
        #expect(UpdateCheck.installCommand == "curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash")
    }
}
