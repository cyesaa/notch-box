import Foundation

/// A stored account: the secret with an id that stays the same, for pins and lists.
public struct AuthEntry: Equatable, Codable, Sendable, Identifiable {
    public let id: String
    public var account: OTPAccount

    public init(id: String, account: OTPAccount) {
        self.id = id
        self.account = account
    }

    public var matchAccount: MatchAccount {
        MatchAccount(id: id, issuer: account.issuer, name: account.name)
    }

    /// What to call the account in a list: the service, or the account name when there is no service.
    public var title: String {
        account.issuer.isEmpty ? account.name : account.issuer
    }

    /// The line under the title; empty when the title already is the account name.
    public var subtitle: String {
        account.issuer.isEmpty ? "" : account.name
    }
}

/// The stored accounts as a list: how they are saved, added to and ordered.
public enum AuthVault {
    public static func encode(_ entries: [AuthEntry]) -> Data? {
        try? JSONEncoder().encode(entries)
    }

    public static func decode(_ data: Data) -> [AuthEntry]? {
        try? JSONDecoder().decode([AuthEntry].self, from: data)
    }

    /// Adds the accounts that are not stored yet and returns how many that was. An account is its secret:
    /// importing the same export twice adds nothing.
    @discardableResult
    public static func add(_ accounts: [OTPAccount], to entries: inout [AuthEntry], makeID: () -> String = { UUID().uuidString }) -> Int {
        var known = Set(entries.map(\.account.secret))
        var added = 0
        for account in accounts where !account.secret.isEmpty && !known.contains(account.secret) {
            known.insert(account.secret)
            entries.append(AuthEntry(id: makeID(), account: account))
            added += 1
        }
        return added
    }

    /// The pins that still point at a stored account.
    public static func pins(_ pins: [String: String], keeping entries: [AuthEntry]) -> [String: String] {
        let ids = Set(entries.map(\.id))
        return pins.filter { ids.contains($0.value) }
    }

    /// The accounts for a list: the ones for the page in view first (in `matching` order), then the rest
    /// as stored.
    public static func ordered(_ entries: [AuthEntry], matching ids: [String]) -> [AuthEntry] {
        let first = ids.compactMap { id in entries.first { $0.id == id } }
        let firstIDs = Set(first.map(\.id))
        return first + entries.filter { !firstIDs.contains($0.id) }
    }
}

/// One sitting at the scanner: the accounts read so far from however many QR codes it takes.
public struct AuthImport: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        /// New accounts were read; the number is how many.
        case added(Int)
        /// This QR code was read before, or holds nothing new.
        case nothingNew
        /// A QR code, but not an authenticator's.
        case notACode
    }

    public private(set) var accounts: [OTPAccount] = []
    public private(set) var unsupported = 0
    /// How many QR codes the export is split over (1 for a single code).
    public private(set) var batchSize = 1
    private var batches: Set<Int> = []
    private var payloads: Set<String> = []

    public init() {}

    /// Parts of a split export read so far.
    public var scannedBatches: Int { batches.count }

    /// More QR codes of a split export are still to come.
    public var isWaitingForMore: Bool { batchSize > 1 && batches.count < batchSize }

    /// Takes the text of a QR code the camera saw. The camera sees the same code many times a second, so
    /// a text already taken changes nothing.
    public mutating func add(payload: String) -> Outcome {
        guard !payloads.contains(payload) else { return .nothingNew }
        guard let scan = OTPAuth.scan(payload) else { return .notACode }
        payloads.insert(payload)
        unsupported += scan.unsupported
        if scan.batchSize > 1 {
            batchSize = max(batchSize, scan.batchSize)
            batches.insert(scan.batchIndex)
        }
        var known = Set(accounts.map(\.secret))
        var added = 0
        for account in scan.accounts where !known.contains(account.secret) {
            known.insert(account.secret)
            accounts.append(account)
            added += 1
        }
        return added > 0 ? .added(added) : .nothingNew
    }
}
