import CoreGraphics
import Foundation
import Testing
@testable import NotchBoxCore

struct AuthPromptTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    let accounts = [
        MatchAccount(id: "gh", issuer: "GitHub", name: "alice"),
        MatchAccount(id: "gh2", issuer: "GitHub", name: "work"),
        MatchAccount(id: "g", issuer: "Google", name: "alice@gmail.com"),
    ]

    func prompt(on url: String?, at time: Date? = nil, pins: [String: String] = [:]) -> AuthPrompt {
        var prompt = AuthPrompt()
        prompt.pageChanged(url: url, accounts: accounts, pins: pins, at: time ?? t0)
        return prompt
    }

    @Test func aSignInPageOfAStoredAccountShowsItsCode() {
        let prompt = prompt(on: "https://github.com/login")
        #expect(prompt.isVisible)
        #expect(prompt.site == "github.com")
        #expect(prompt.accountIDs == ["gh", "gh2"])
        #expect(prompt.nextDeadline == at(AuthPrompt.displayDuration))
    }

    @Test func otherPagesShowNothing() {
        #expect(!prompt(on: "https://github.com/owner/repo").isVisible)
        #expect(!prompt(on: "https://unknown.example/login").isVisible)
        #expect(!prompt(on: nil).isVisible)
        #expect(prompt(on: nil).nextDeadline == nil)
    }

    @Test func itGoesWhenThePageIsLeftAndComesBackWithIt() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: "https://github.com/", accounts: accounts, pins: [:], at: at(20))
        #expect(!prompt.isVisible)
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: [:], at: at(40))
        #expect(prompt.isVisible)
        #expect(prompt.nextDeadline == at(40 + AuthPrompt.displayDuration))
    }

    @Test func itGoesWhenNoBrowserIsInFront() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: nil, accounts: accounts, pins: [:], at: at(5))
        #expect(!prompt.isVisible)
    }

    @Test func readingTheSamePageAgainDoesNotRestartTheClock() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: [:], at: at(30))
        #expect(prompt.nextDeadline == at(AuthPrompt.displayDuration))
    }

    @Test func itStaysThroughTheStepsOfOneSignInAndEachStepRestartsTheClock() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: "https://github.com/sessions/two-factor/app", accounts: accounts, pins: [:], at: at(50))
        #expect(prompt.isVisible)
        #expect(prompt.nextDeadline == at(50 + AuthPrompt.displayDuration))
    }

    @Test func aPageLeftOpenTimesOutAndStaysQuietUntilTheAddressChanges() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.tick(at: at(AuthPrompt.displayDuration - 1))
        #expect(prompt.isVisible)
        prompt.tick(at: at(AuthPrompt.displayDuration))
        #expect(!prompt.isVisible)
        #expect(prompt.nextDeadline == nil)
        // Still the same page: nothing.
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: [:], at: at(500))
        #expect(!prompt.isVisible)
        // The next step of the sign-in brings it back.
        prompt.pageChanged(url: "https://github.com/sessions/two-factor/app", accounts: accounts, pins: [:], at: at(510))
        #expect(prompt.isVisible)
    }

    @Test func leavingATimedOutPageAndComingBackShowsItAgain() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.tick(at: at(AuthPrompt.displayDuration))
        prompt.pageChanged(url: nil, accounts: accounts, pins: [:], at: at(200))
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: [:], at: at(210))
        #expect(prompt.isVisible)
    }

    @Test func closingItKeepsTheSiteQuietForAWhile() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.dismiss(at: at(10))
        #expect(!prompt.isVisible)
        // Not on the next step of the same sign-in either.
        prompt.pageChanged(url: "https://github.com/sessions/two-factor/app", accounts: accounts, pins: [:], at: at(20))
        #expect(!prompt.isVisible)
        // Another site is not affected.
        prompt.pageChanged(url: "https://accounts.google.com/v3/signin/identifier", accounts: accounts, pins: [:], at: at(30))
        #expect(prompt.accountIDs == ["g"])
        // Later the site may speak again.
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: [:], at: at(10 + AuthPrompt.quietDuration))
        #expect(prompt.site == "github.com")
    }

    @Test func aPinMadeWhileItShowsReordersTheAccounts() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: "https://github.com/login", accounts: accounts, pins: ["github.com": "gh2"], at: at(3))
        #expect(prompt.accountIDs == ["gh2", "gh"])
        #expect(prompt.nextDeadline == at(AuthPrompt.displayDuration))
    }

    @Test func itGoesWhenTheAccountIsDeleted() {
        var prompt = prompt(on: "https://accounts.google.com/signin")
        prompt.pageChanged(url: "https://accounts.google.com/signin", accounts: Array(accounts.prefix(2)), pins: [:], at: at(3))
        #expect(!prompt.isVisible)
    }

    @Test func switchingToAnotherSitesSignInShowsThatSite() {
        var prompt = prompt(on: "https://github.com/login")
        prompt.pageChanged(url: "https://accounts.google.com/signin", accounts: accounts, pins: [:], at: at(15))
        #expect(prompt.site == "google.com")
        #expect(prompt.accountIDs == ["g"])
        #expect(prompt.nextDeadline == at(15 + AuthPrompt.displayDuration))
    }
}

struct AuthLayoutTests {
    let notch = CGSize(width: 200, height: 32)

    @Test func theCodeRowHangsUnderTheNotch() {
        #expect(NotchLayout.size(for: .auth, notch: notch) == CGSize(width: 300, height: 32 + NotchLayout.authRowHeight))
        // A very wide notch keeps its wings.
        let wide = CGSize(width: 260, height: 32)
        #expect(NotchLayout.size(for: .auth, notch: wide).width == 260 + 2 * NotchLayout.miniSideWidth(notch: wide))
    }

    @Test func onlyTheCodeRowTakesClicks() {
        #expect(NotchLayout.authActionFrame(notch: notch) == CGRect(x: 0, y: 32, width: 300, height: NotchLayout.authRowHeight))
        #expect(NotchInteraction.acceptsClicks(in: .auth, cursorOverButton: true, entry: nil))
        #expect(!NotchInteraction.acceptsClicks(in: .auth, cursorOverButton: false, entry: .fromTop))
    }

    @Test func pointingAtTheCodeRowDoesNotOpenThePanel() {
        #expect(NotchInteraction.buttonSuppressesHover(in: .auth))
        #expect(NotchInteraction.buttonSuppressesHover(in: .mini))
        #expect(!NotchInteraction.buttonSuppressesHover(in: .video))
    }

    @Test func theCodeRowIsAClosedStateThatFitsInTheWindow() {
        #expect(!NotchDisplayState.auth.isOpen)
        #expect(NotchDisplayState.allCases.contains(.auth))
        let window = NotchLayout.windowSize(notch: notch)
        let size = NotchLayout.size(for: .auth, notch: notch)
        #expect(size.width <= window.width && size.height <= window.height)
        #expect(NotchLayout.bottomCornerRadius(for: .auth) == 14)
        #expect(NotchLayout.topCornerRadius(for: .auth) == 6)
    }

    @Test func eachBrowserNamesItsTabInViewItsOwnWay() {
        #expect(BrowserTabs.activeTabKey(forBundleIdentifier: "com.apple.Safari") == "currentTab")
        #expect(BrowserTabs.activeTabKey(forBundleIdentifier: "com.google.Chrome") == "activeTab")
        #expect(BrowserTabs.activeTabKey(forBundleIdentifier: "company.thebrowser.Browser") == "activeTab")
        #expect(BrowserTabs.activeTabKey(forBundleIdentifier: "com.apple.Music") == nil)
    }
}
