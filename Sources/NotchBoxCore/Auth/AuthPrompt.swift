import Foundation

/// When the notch drops a sign-in code under itself: while the browser tab in front is a sign-in page of
/// a site one of the stored accounts belongs to. It stays through the steps of signing in (the code is
/// asked for last) and goes when the page is left.
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct AuthPrompt: Sendable {
    /// How long a code stays up on one page: a sign-in tab left open should not show codes all day.
    public static let displayDuration: TimeInterval = 120
    /// After the user hid it, the same site stays quiet this long.
    public static let quietDuration: TimeInterval = 300

    /// The site the code is shown for; nil while nothing is shown.
    public private(set) var site: String?
    /// The accounts for that site, best first.
    public private(set) var accountIDs: [String] = []
    public private(set) var nextDeadline: Date?

    private var url: String?
    /// The page the code timed out on: quiet until the address changes.
    private var timedOutURL: String?
    private var quietSite: String?
    private var quietUntil = Date.distantPast

    public init() {}

    public var isVisible: Bool { site != nil }

    /// Reports the page in the front browser tab (nil: no browser is in front). Called again and again
    /// with the same address while the page stays; only a new address restarts the clock.
    public mutating func pageChanged(url newURL: String?, accounts: [MatchAccount], pins: [String: String], at now: Date) {
        if newURL != timedOutURL { timedOutURL = nil }
        guard let newURL, let newSite = SiteMatch.site(ofURL: newURL), SiteMatch.isLoginPage(newURL) else {
            hide()
            return
        }
        let ids = SiteMatch.matches(url: newURL, accounts: accounts, pins: pins)
        guard !ids.isEmpty, timedOutURL == nil, !(quietSite == newSite && now < quietUntil) else {
            hide()
            return
        }
        accountIDs = ids
        guard newSite != site || newURL != url else { return }
        // Another site, or the next step of the same sign-in.
        site = newSite
        url = newURL
        nextDeadline = now.addingTimeInterval(Self.displayDuration)
    }

    public mutating func tick(at now: Date) {
        guard let nextDeadline, now >= nextDeadline else { return }
        timedOutURL = url
        hide()
    }

    /// The user closed it: nothing more for this site for a while.
    public mutating func dismiss(at now: Date) {
        guard let site else { return }
        quietSite = site
        quietUntil = now.addingTimeInterval(Self.quietDuration)
        hide()
    }

    private mutating func hide() {
        site = nil
        url = nil
        accountIDs = []
        nextDeadline = nil
    }
}
