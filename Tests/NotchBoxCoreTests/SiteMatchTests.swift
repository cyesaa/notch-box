import Foundation
import Testing
@testable import NotchBoxCore

struct SiteMatchDomainTests {
    @Test func takesTheRegistrableSiteFromAHost() {
        #expect(SiteMatch.registrableDomain(ofHost: "github.com") == "github.com")
        #expect(SiteMatch.registrableDomain(ofHost: "accounts.google.com") == "google.com")
        #expect(SiteMatch.registrableDomain(ofHost: "www.github.com") == "github.com")
        #expect(SiteMatch.registrableDomain(ofHost: "login.example.co.uk") == "example.co.uk")
        #expect(SiteMatch.registrableDomain(ofHost: "portal.firma.com.tr") == "firma.com.tr")
        #expect(SiteMatch.registrableDomain(ofHost: "192.168.1.10") == "192.168.1.10")
    }

    @Test func readsTheHostFromAURL() {
        #expect(SiteMatch.host(ofURL: "https://github.com/login?x=1") == "github.com")
        #expect(SiteMatch.host(ofURL: "not a url") == nil)
    }

    @Test func readsTheSiteFromAWebAddressOnly() {
        #expect(SiteMatch.site(ofURL: "https://accounts.google.com/signin") == "google.com")
        #expect(SiteMatch.site(ofURL: "http://localhost:3000/login") == "localhost")
        #expect(SiteMatch.site(ofURL: "chrome://settings/") == nil)
        #expect(SiteMatch.site(ofURL: "file:///Users/me/login.html") == nil)
        #expect(SiteMatch.site(ofURL: "") == nil)
    }
}

struct SiteMatchLoginPageTests {
    @Test func spotsSignInAndVerificationPages() {
        #expect(SiteMatch.isLoginPage("https://github.com/login"))
        #expect(SiteMatch.isLoginPage("https://github.com/sessions/two-factor/app"))
        #expect(SiteMatch.isLoginPage("https://accounts.google.com/v3/signin/challenge/totp"))
        #expect(SiteMatch.isLoginPage("https://example.com/account/security"))
        #expect(SiteMatch.isLoginPage("https://example.com/users/sign_in"))
        #expect(SiteMatch.isLoginPage("https://example.com/Log-In"))
    }

    @Test func aSignInHostCountsWhateverThePath() {
        #expect(SiteMatch.isLoginPage("https://login.microsoftonline.com/common/oauth2/authorize"))
        #expect(SiteMatch.isLoginPage("https://accounts.google.com/"))
        #expect(SiteMatch.isLoginPage("https://id.atlassian.com/"))
        // The site's own name is not a sign-in host.
        #expect(!SiteMatch.isLoginPage("https://login.com/"))
    }

    @Test func singlePageAppsPutTheStepInTheFragment() {
        #expect(SiteMatch.isLoginPage("https://app.example.com/#/login"))
    }

    @Test func leavesOrdinaryPagesAlone() {
        #expect(!SiteMatch.isLoginPage("https://github.com/owner/repo"))
        #expect(!SiteMatch.isLoginPage("https://news.example.com/article/123"))
        #expect(!SiteMatch.isLoginPage("https://github.com/"))
        #expect(!SiteMatch.isLoginPage("not a url"))
    }

    @Test func aWordInsideAnotherWordDoesNotCount() {
        #expect(!SiteMatch.isLoginPage("https://example.com/authors/jane"))
        #expect(!SiteMatch.isLoginPage("https://example.com/blog/logins-are-hard"))
    }

    @Test func whatTheUserTypedIntoASearchDoesNotCount() {
        #expect(!SiteMatch.isLoginPage("https://www.google.com/search?q=github+login+2fa"))
    }
}

struct SiteMatchAccountTests {
    let github = MatchAccount(id: "1", issuer: "GitHub", name: "alice@example.com")
    let google = MatchAccount(id: "2", issuer: "Google", name: "alice@gmail.com")
    let work = MatchAccount(id: "3", issuer: "", name: "bob@acme.com")

    var accounts: [MatchAccount] { [github, google, work] }

    func ids(_ url: String, _ accounts: [MatchAccount], pins: [String: String] = [:]) -> [String] {
        SiteMatch.matches(url: url, accounts: accounts, pins: pins)
    }

    @Test func matchesByIssuer() {
        #expect(ids("https://github.com/login", accounts) == ["1"])
        #expect(ids("https://accounts.google.com/signin", accounts) == ["2"])
    }

    @Test func theFirstWordOfALongerIssuerIsEnough() {
        let enterprise = MatchAccount(id: "e", issuer: "GitHub Enterprise", name: "alice")
        let aws = MatchAccount(id: "w", issuer: "Amazon Web Services", name: "root")
        #expect(ids("https://github.com/login", [enterprise]) == ["e"])
        #expect(ids("https://signin.aws.amazon.com/", [aws]) == ["w"])
    }

    @Test func aBrandOnAnotherEndingIsNotTrusted() {
        // Anyone can publish at <name>.github.io or register github.xyz: no code is offered there.
        #expect(ids("https://evil.github.io/login", accounts).isEmpty)
        #expect(ids("https://github.xyz/login", accounts).isEmpty)
        #expect(ids("https://github.com.evil.co/login", accounts).isEmpty)
        #expect(ids("https://github-login.com/login", accounts).isEmpty)
    }

    @Test func aOneLetterIssuerDoesNotMatchEverySiteWithThatLetter() {
        let x = MatchAccount(id: "x", issuer: "X", name: "@alice")
        #expect(ids("https://x.com/i/flow/login", [x]) == ["x"])
        #expect(ids("https://twitter.com/login", [x]) == ["x"])
        #expect(ids("https://www.dropbox.com/login", [x]).isEmpty)
    }

    @Test func knownServicesSignInOnAnotherDomain() {
        let aws = MatchAccount(id: "9", issuer: "AWS", name: "root")
        let microsoft = MatchAccount(id: "m", issuer: "Microsoft", name: "bob@contoso.com")
        #expect(ids("https://signin.aws.amazon.com/", [aws]) == ["9"])
        #expect(ids("https://login.microsoftonline.com/common/oauth2", [microsoft]) == ["m"])
        #expect(ids("https://login.live.com/", [microsoft]) == ["m"])
    }

    @Test func matchesByEmailDomainOnlyWhenTheIssuerIsBlank() {
        #expect(ids("https://acme.com/login", accounts) == ["3"])
        // The GitHub account's e-mail address says nothing about example.com.
        #expect(ids("https://example.com/login", accounts).isEmpty)
    }

    @Test func aPinWinsAndResolvesAmbiguity() {
        let gh1 = MatchAccount(id: "a", issuer: "GitHub", name: "one@x.com")
        let gh2 = MatchAccount(id: "b", issuer: "GitHub", name: "two@x.com")
        #expect(ids("https://github.com/login", [gh1, gh2]) == ["a", "b"])
        #expect(ids("https://github.com/login", [gh1, gh2], pins: ["github.com": "b"]) == ["b", "a"])
    }

    @Test func aPinTeachesASiteTheGuessMisses() {
        let bank = MatchAccount(id: "k", issuer: "Ornek", name: "12345")
        #expect(ids("https://bireysel.ornekbank.com.tr/login", [bank]).isEmpty)
        #expect(ids("https://bireysel.ornekbank.com.tr/login", [bank], pins: ["ornekbank.com.tr": "k"]) == ["k"])
    }

    @Test func noMatchIsEmpty() {
        #expect(ids("https://unknown-site.com/login", accounts).isEmpty)
        #expect(ids("not a url", accounts).isEmpty)
    }
}
