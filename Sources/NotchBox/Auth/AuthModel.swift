import AppKit
import NotchBoxCore
import Observation
import os

/// The sign-in codes: the stored accounts, the page the browser is on, and whether the notch is showing
/// a code for it. The views read it through `NotchViewModel.auth`.
@MainActor
@Observable
final class AuthModel {
    enum Storage: Equatable {
        /// Not read yet: nothing was ever saved, or the read is under way.
        case unread
        case ready
        /// The keychain refused. The accounts are still there, so nothing may be saved over them.
        case unreadable
    }

    typealias FrontBrowser = (bundleIdentifier: String, process: pid_t)

    private(set) var entries: [AuthEntry] = []
    private(set) var storage = Storage.unread
    /// Which account the user chose for a site (site → account id), when the guess was wrong or there
    /// are several.
    private(set) var pins: [String: String] = [:]
    /// The moment the codes on screen are for; moves on every second while codes are shown.
    private(set) var time: Date
    /// The site of the page in the front browser tab; nil when no browser is in front.
    private(set) var activeSite: String?
    /// The accounts that belong to that site, best first.
    private(set) var siteAccountIDs: [String] = []
    /// The accounts the notch is showing a code for (the first one; the others are a click away).
    /// Empty while it shows none.
    private(set) var promptAccountIDs: [String] = []
    /// The account whose code was just copied, for a moment, to show it worked.
    private(set) var copiedID: String?
    /// Show a code by itself on sign-in pages (Settings).
    private(set) var showsOnSignIn: Bool

    /// The notch has a code to show, or stopped having one.
    @ObservationIgnored var onPromptChange: (() -> Void)?
    /// Opens the window where accounts are imported and deleted.
    @ObservationIgnored var onOpenManager: (() -> Void)?

    @ObservationIgnored private let store: AuthStoring?
    @ObservationIgnored private let tabReader: BrowserTabReading?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let frontBrowser: @MainActor () -> FrontBrowser?
    @ObservationIgnored private let copy: @MainActor (String) -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var prompt = AuthPrompt()
    /// The address in the front browser tab. Kept in memory only, never saved or logged.
    @ObservationIgnored private var pageURL: String?
    @ObservationIgnored private var isColumnVisible = false
    @ObservationIgnored private var isReadingPage = false
    /// Browsers that refused to be read (no Automation permission): left alone for a while.
    @ObservationIgnored private var refusedUntil: [String: Date] = [:]
    @ObservationIgnored private var watchTimer: Timer?
    @ObservationIgnored private var codeTimer: Timer?
    @ObservationIgnored private var copiedWork: DispatchWorkItem?
    /// Says that something happened, never where: no address, site or account is written to the log.
    @ObservationIgnored private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "auth")

    private static let pinsKey = "AuthPins"
    private static let showsOnSignInKey = "AuthShowsOnSignIn"
    /// How often the front browser tab's address is read while there are accounts to show codes for.
    static let watchInterval: TimeInterval = 1.5
    static let refusalPause: TimeInterval = 30
    static let copiedFeedbackDuration: TimeInterval = 1.2

    init(
        store: AuthStoring? = nil,
        tabReader: BrowserTabReading? = nil,
        defaults: UserDefaults? = nil,
        frontBrowser: @escaping @MainActor () -> FrontBrowser? = AuthModel.frontBrowser,
        copy: @escaping @MainActor (String) -> Void = AuthModel.copyToPasteboard,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.tabReader = tabReader
        self.defaults = defaults
        self.frontBrowser = frontBrowser
        self.copy = copy
        self.now = now
        time = now()
        pins = defaults?.dictionary(forKey: Self.pinsKey) as? [String: String] ?? [:]
        showsOnSignIn = defaults?.object(forKey: Self.showsOnSignInKey) as? Bool ?? true
    }

    func start() {
        // Someone who never imported an account is never asked about their keychain.
        guard let store, store.mayHaveAccounts else { return }
        reload()
    }

    func stop() {
        watchTimer?.invalidate()
        watchTimer = nil
        codeTimer?.invalidate()
        codeTimer = nil
        copiedWork?.cancel()
    }

    // MARK: Accounts

    /// The account whose code the notch shows under itself.
    var promptEntry: AuthEntry? {
        promptAccountIDs.first.flatMap { id in entries.first { $0.id == id } }
    }

    /// The accounts for the column: the ones for the page in view first.
    var listedEntries: [AuthEntry] {
        AuthVault.ordered(entries, matching: siteAccountIDs)
    }

    /// Reads the accounts from the keychain (again).
    func reload(completion: (@MainActor (Bool) -> Void)? = nil) {
        guard let store else {
            storage = .ready
            completion?(true)
            return
        }
        store.load { [weak self] loaded in
            guard let self else { return }
            if let loaded {
                self.entries = loaded
                self.storage = .ready
                self.setPins(AuthVault.pins(self.pins, keeping: loaded))
            } else {
                self.storage = .unreadable
            }
            self.accountsChanged()
            completion?(loaded != nil)
        }
    }

    /// Adds imported accounts. Completes with how many were new, or nil when they could not be saved.
    /// What is stored is read first, so an import never replaces accounts it has not seen.
    func add(_ accounts: [OTPAccount], completion: @escaping @MainActor (Int?) -> Void) {
        whenReady { [weak self] ready in
            guard let self, ready else {
                completion(nil)
                return
            }
            var updated = self.entries
            let added = AuthVault.add(accounts, to: &updated)
            guard added > 0 else {
                completion(0)
                return
            }
            self.save(updated) { saved in completion(saved ? added : nil) }
        }
    }

    func delete(_ entry: AuthEntry, completion: @escaping @MainActor (Bool) -> Void) {
        guard storage == .ready else {
            completion(false)
            return
        }
        save(entries.filter { $0.id != entry.id }, completion: completion)
    }

    func openManager() {
        onOpenManager?()
    }

    private func whenReady(_ completion: @escaping @MainActor (Bool) -> Void) {
        if storage == .ready {
            completion(true)
        } else {
            reload(completion: completion)
        }
    }

    private func save(_ updated: [AuthEntry], completion: @escaping @MainActor (Bool) -> Void) {
        let apply: @MainActor (Bool) -> Void = { [weak self] saved in
            if saved, let self {
                self.entries = updated
                self.setPins(AuthVault.pins(self.pins, keeping: updated))
                self.accountsChanged()
            }
            completion(saved)
        }
        if let store {
            store.save(updated, completion: apply)
        } else {
            apply(true)
        }
    }

    private func accountsChanged() {
        updateWatching()
        evaluatePage()
    }

    // MARK: Codes

    func copyCode(of entry: AuthEntry) {
        copy(entry.account.code(at: now()))
        copiedID = entry.id
        copiedWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.copiedID = nil }
        }
        copiedWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedFeedbackDuration, execute: work)
    }

    /// With several accounts for the site: shows the next one, and remembers it for the site.
    func showNextPromptAccount() {
        guard let site = prompt.site, let current = promptAccountIDs.first, let url = pageURL else { return }
        // The order without pins is the fixed circle to walk around.
        let circle = SiteMatch.matches(url: url, accounts: entries.map(\.matchAccount), pins: [:])
        guard circle.count > 1, let index = circle.firstIndex(of: current) else { return }
        var updated = pins
        updated[site] = circle[(index + 1) % circle.count]
        setPins(updated)
        evaluatePage()
    }

    /// The user closed the code under the notch: the site stays quiet for a while.
    func dismissPrompt() {
        prompt.dismiss(at: now())
        syncPrompt()
    }

    func isPinned(_ entry: AuthEntry) -> Bool {
        guard let activeSite else { return false }
        return pins[activeSite] == entry.id
    }

    /// Makes `entry` the account for the site in view (or stops it being that).
    func togglePin(_ entry: AuthEntry) {
        guard let site = activeSite else { return }
        var updated = pins
        updated[site] = updated[site] == entry.id ? nil : entry.id
        setPins(updated)
        evaluatePage()
    }

    func setShowsOnSignIn(_ value: Bool) {
        guard value != showsOnSignIn else { return }
        showsOnSignIn = value
        defaults?.set(value, forKey: Self.showsOnSignInKey)
        updateWatching()
        evaluatePage()
    }

    /// The codes column of the open player came into view or left it.
    func setColumnVisible(_ visible: Bool) {
        guard visible != isColumnVisible else { return }
        isColumnVisible = visible
        updateWatching()
        updateCodeClock()
    }

    private func setPins(_ updated: [String: String]) {
        guard updated != pins else { return }
        pins = updated
        defaults?.set(updated, forKey: Self.pinsKey)
    }

    // MARK: The page in the browser

    /// Sets the page as if the browser had been read. For `SnapshotRenderer`.
    func setPage(url: String?) {
        pageURL = url
        evaluatePage()
    }

    /// The address of the front tab is read only while there is a use for it: accounts exist, and either
    /// codes show by themselves or the column is in view.
    private var wantsPage: Bool {
        tabReader != nil && !entries.isEmpty && (showsOnSignIn || isColumnVisible)
    }

    private func updateWatching() {
        guard wantsPage else {
            guard let watchTimer else { return }
            watchTimer.invalidate()
            self.watchTimer = nil
            pageURL = nil
            evaluatePage()
            return
        }
        guard watchTimer == nil else { return }
        let timer = Timer(timeInterval: Self.watchInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readPage() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        watchTimer = timer
        // Not from inside the caller (the view model's `apply`), which a change here calls back into.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.readPage() }
        }
    }

    private func readPage() {
        guard let tabReader, watchTimer != nil, !isReadingPage else { return }
        guard let browser = frontBrowser(), (refusedUntil[browser.bundleIdentifier] ?? .distantPast) <= now() else {
            pageURL = nil
            evaluatePage()
            return
        }
        isReadingPage = true
        tabReader.readActiveTab(of: browser.bundleIdentifier, process: browser.process) { [weak self] result in
            guard let self else { return }
            self.isReadingPage = false
            guard self.watchTimer != nil else { return }
            switch result {
            case .success(let url):
                self.pageURL = url
            case .failure:
                self.logger.notice("\(browser.bundleIdentifier, privacy: .public) could not be read (Automation permission?); trying again later")
                self.refusedUntil[browser.bundleIdentifier] = self.now().addingTimeInterval(Self.refusalPause)
                self.pageURL = nil
            }
            self.evaluatePage()
        }
    }

    private func evaluatePage() {
        let time = now()
        let accounts = entries.map(\.matchAccount)
        let site = pageURL.flatMap(SiteMatch.site(ofURL:))
        if site != activeSite { activeSite = site }
        let siteIDs = pageURL.map { SiteMatch.matches(url: $0, accounts: accounts, pins: pins) } ?? []
        if siteIDs != siteAccountIDs { siteAccountIDs = siteIDs }
        prompt.tick(at: time)
        prompt.pageChanged(url: showsOnSignIn ? pageURL : nil, accounts: accounts, pins: pins, at: time)
        syncPrompt()
    }

    private func syncPrompt() {
        guard prompt.accountIDs != promptAccountIDs else { return }
        let wasVisible = !promptAccountIDs.isEmpty
        promptAccountIDs = prompt.accountIDs
        updateCodeClock()
        if wasVisible != prompt.isVisible {
            logger.notice("Sign-in code \(self.prompt.isVisible ? "shown" : "hidden", privacy: .public)")
            onPromptChange?()
        }
    }

    /// `time` ticks on the second while a code is on screen.
    private func updateCodeClock() {
        guard !promptAccountIDs.isEmpty || isColumnVisible else {
            codeTimer?.invalidate()
            codeTimer = nil
            return
        }
        time = now()
        guard codeTimer == nil else { return }
        let nextSecond = Date(timeIntervalSince1970: floor(time.timeIntervalSince1970) + 1)
        let timer = Timer(fire: nextSecond, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.time = self.now()
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        codeTimer = timer
    }

    // MARK: The system

    /// The browser in front, when it is one whose tabs NotchBox can read.
    static func frontBrowser() -> FrontBrowser? {
        guard let app = NSWorkspace.shared.frontmostApplication, let bundleIdentifier = app.bundleIdentifier,
              BrowserTabs.isSupportedBrowser(bundleIdentifier) else { return nil }
        return (bundleIdentifier, app.processIdentifier)
    }

    static func copyToPasteboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        // The marker password managers use for "do not keep this": clipboard histories, NotchBox's own
        // included, skip it.
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }
}
