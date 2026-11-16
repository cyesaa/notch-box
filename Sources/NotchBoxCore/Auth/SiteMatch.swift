import Foundation

/// An account as the matcher needs to see it: an id and who it is for.
public struct MatchAccount: Equatable, Sendable {
    public let id: String
    public let issuer: String
    public let name: String

    public init(id: String, issuer: String, name: String) {
        self.id = id
        self.issuer = issuer
        self.name = name
    }
}

/// Decides which stored account a browser page belongs to, and whether a page is a sign-in page worth
/// surfacing a code for. All of it is from the address alone — NotchBox never reads page contents.
///
/// The guess is deliberately narrow. A code that pops up by itself tells the user "this is the real site",
/// so it is offered only where the service's own name is the domain (`github.com` for "GitHub"), on the
/// domains in `knownSites`, and on sites the user pinned. `github.xyz` or `evil.github.io` get nothing.
public enum SiteMatch {
    /// Whole words of a path that mark a sign-in or verification step ("/users/sign_in", "/two-factor").
    private static let loginWords: Set<String> = [
        "login", "signin", "logon", "auth", "authenticate", "authentication", "authorize", "oauth", "oauth2",
        "mfa", "2fa", "tfa", "otp", "totp", "verify", "verification", "challenge", "sso", "sudo",
        "twofactor", "twostep", "accountsecurity",
    ]

    /// Sub-domains that only sign people in (`login.microsoftonline.com`, `accounts.google.com`).
    private static let loginHosts: Set<String> = [
        "login", "signin", "auth", "sso", "accounts", "id", "identity", "idp", "oauth",
    ]

    /// Public suffixes made of two labels, so `example.com.tr` is one site, not `com.tr`.
    private static let multiLabelSuffixes: Set<String> = [
        "co.uk", "org.uk", "gov.uk", "ac.uk", "com.tr", "net.tr", "org.tr", "gov.tr", "edu.tr", "bel.tr",
        "com.au", "net.au", "org.au", "co.jp", "com.br", "co.in", "com.mx", "co.kr", "co.nz", "co.za",
    ]

    /// Endings tried after a service's name. Kept short on purpose: every ending here is one more place
    /// where somebody else could own the name.
    private static let guessedEndings = ["com", "com.tr"]

    /// Services that sign in somewhere other than `<name>.com`, by issuer (or its first word) in lower
    /// case without spaces.
    private static let knownSites: [String: [String]] = [
        "google": ["google.com", "youtube.com"],
        "gmail": ["google.com"],
        "youtube": ["google.com", "youtube.com"],
        "microsoft": ["microsoftonline.com", "live.com", "microsoft.com", "office.com", "azure.com"],
        "azure": ["microsoftonline.com", "azure.com"],
        "office365": ["microsoftonline.com", "office.com"],
        "outlook": ["live.com", "microsoftonline.com"],
        "aws": ["amazon.com"],
        "amazonwebservices": ["amazon.com"],
        "x": ["x.com", "twitter.com"],
        "twitter": ["x.com", "twitter.com"],
        "meta": ["facebook.com", "meta.com"],
        "fb": ["facebook.com"],
        "apple": ["apple.com", "icloud.com"],
        "icloud": ["apple.com", "icloud.com"],
        "atlassian": ["atlassian.com", "atlassian.net", "bitbucket.org", "trello.com"],
        "jira": ["atlassian.com", "atlassian.net"],
        "confluence": ["atlassian.com", "atlassian.net"],
        "bitbucket": ["bitbucket.org", "atlassian.com"],
        "trello": ["trello.com", "atlassian.com"],
        "proton": ["proton.me"],
        "protonmail": ["proton.me"],
        "twitch": ["twitch.tv"],
        "notion": ["notion.so", "notion.com"],
        "zoom": ["zoom.us"],
        "npm": ["npmjs.com"],
        "pypi": ["pypi.org"],
        "wordpress": ["wordpress.com", "wordpress.org"],
        "telegram": ["telegram.org"],
        "mozilla": ["mozilla.org", "firefox.com"],
        "firefox": ["mozilla.org", "firefox.com"],
        "steam": ["steampowered.com", "steamcommunity.com"],
        "playstation": ["playstation.com", "sony.com"],
        "ovh": ["ovh.com", "ovhcloud.com"],
    ]

    public static func host(ofURL url: String) -> String? {
        guard let components = URLComponents(string: url), let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    /// The site of a web page (`https://accounts.google.com/signin` → `google.com`); nil for anything
    /// that is not a web address (a browser's own pages, files).
    public static func site(ofURL url: String) -> String? {
        guard let components = URLComponents(string: url), ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        return registrableDomain(ofHost: host)
    }

    /// The registrable site of a host: `accounts.google.com` → `google.com`, `a.b.co.uk` → `b.co.uk`.
    /// An IP address is its own site.
    public static func registrableDomain(ofHost host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2, !labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return host }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let take = multiLabelSuffixes.contains(lastTwo) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }

    /// Whether a page looks like a step of signing in: a sign-in sub-domain, or a sign-in word in the path
    /// (or the fragment, where single-page apps keep it). The query is left out: it holds what people
    /// search for.
    public static func isLoginPage(_ url: String) -> Bool {
        guard let components = URLComponents(string: url), ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host?.lowercased(), !host.isEmpty else { return false }
        let site = registrableDomain(ofHost: host)
        if host.count > site.count {
            let subdomains = host.dropLast(site.count + 1).split(separator: ".").map(String.init)
            if subdomains.contains(where: loginHosts.contains) { return true }
        }
        return hasLoginWord(components.path) || hasLoginWord(components.fragment ?? "")
    }

    /// The stored accounts a page belongs to, best first. A pin for the site wins; then accounts whose
    /// issuer points at the site; then accounts without an issuer whose e-mail address is at the site.
    /// Empty when nothing matches. Several can match (two accounts on one service), so the caller shows
    /// the first and lets the user pick.
    public static func matches(url: String, accounts: [MatchAccount], pins: [String: String]) -> [String] {
        guard let site = site(ofURL: url) else { return [] }
        var scored: [(id: String, rank: Int, order: Int)] = []
        for (index, account) in accounts.enumerated() {
            if pins[site] == account.id {
                scored.append((account.id, 0, index))
            } else if let rank = rank(of: account, site: site) {
                scored.append((account.id, rank, index))
            }
        }
        return scored.sorted { ($0.rank, $0.order) < ($1.rank, $1.order) }.map(\.id)
    }

    /// The sites an issuer is expected to sign in on: its name, and the first word of a longer name,
    /// under `guessedEndings`, plus what `knownSites` lists for either.
    static func guessedSites(forIssuer issuer: String) -> Set<String> {
        let words = words(in: issuer)
        guard !words.isEmpty else { return [] }
        var names = [words.joined()]
        if words.count > 1, words[0].count >= 3 { names.append(words[0]) }
        var sites: Set<String> = []
        for name in names {
            for ending in guessedEndings { sites.insert(name + "." + ending) }
            sites.formUnion(knownSites[name] ?? [])
        }
        return sites
    }

    private static func rank(of account: MatchAccount, site: String) -> Int? {
        if guessedSites(forIssuer: account.issuer).contains(site) { return 1 }
        // "bob@acme.com" with no issuer: a work account at acme.com.
        if words(in: account.issuer).isEmpty, let at = account.name.lastIndex(of: "@") {
            let emailHost = account.name[account.name.index(after: at)...].lowercased()
            if !emailHost.isEmpty, registrableDomain(ofHost: emailHost) == site { return 2 }
        }
        return nil
    }

    private static func hasLoginWord(_ text: String) -> Bool {
        let words = words(in: text)
        for (index, word) in words.enumerated() {
            if loginWords.contains(word) { return true }
            // "sign-in", "two_factor", "account/security".
            if index + 1 < words.count, loginWords.contains(word + words[index + 1]) { return true }
        }
        return false
    }

    /// Lower-case runs of letters and digits, with accents folded away ("İş Bankası" → "is", "bankasi").
    private static func words(in text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }
}
