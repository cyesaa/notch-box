import Foundation
@preconcurrency import LocalAuthentication
import NotchBoxCore
import os

@MainActor
protocol AuthStoring: AnyObject {
    /// Something was saved before, so reading at launch is worth it (and may make macOS ask for the
    /// keychain password). False for everyone who never imported an account: their keychain is left alone.
    var mayHaveAccounts: Bool { get }
    /// Reads the stored accounts; completes on the main thread with nil when they could not be read.
    func load(completion: @escaping @MainActor ([AuthEntry]?) -> Void)
    /// Saves the accounts; completes on the main thread with whether that worked.
    func save(_ entries: [AuthEntry], completion: @escaping @MainActor (Bool) -> Void)
}

/// Keeps the accounts' secrets in the login keychain, as one item. Runs off the main thread: a read can
/// wait on macOS asking the user for the keychain password.
@MainActor
final class KeychainAuthStore: AuthStoring {
    private static let usedKey = "AuthHasAccounts"

    private let item: KeychainItem
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.notchbox.NotchBox.auth-store", qos: .userInitiated)
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "auth")

    init(
        item: KeychainItem = KeychainItem(service: "com.notchbox.NotchBox.auth", account: "accounts", label: "NotchBox sign-in codes"),
        defaults: UserDefaults = .standard
    ) {
        self.item = item
        self.defaults = defaults
    }

    var mayHaveAccounts: Bool { defaults.bool(forKey: Self.usedKey) }

    func load(completion: @escaping @MainActor ([AuthEntry]?) -> Void) {
        let item = self.item, logger = self.logger
        queue.async {
            let entries: [AuthEntry]?
            switch item.read() {
            case .missing:
                entries = []
            case .data(let data):
                entries = AuthVault.decode(data)
                if entries == nil { logger.error("The stored sign-in accounts could not be decoded") }
            case .failed(let status):
                entries = nil
                logger.error("Reading the sign-in accounts failed: \(status, privacy: .public)")
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(entries) } }
        }
    }

    func save(_ entries: [AuthEntry], completion: @escaping @MainActor (Bool) -> Void) {
        let item = self.item, logger = self.logger
        queue.async { [weak self] in
            let status: OSStatus
            if entries.isEmpty {
                status = item.delete()
            } else if let data = AuthVault.encode(entries) {
                status = item.write(data)
            } else {
                status = errSecParam
            }
            if status != errSecSuccess { logger.error("Saving the sign-in accounts failed: \(status, privacy: .public)") }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if status == errSecSuccess { self?.defaults.set(!entries.isEmpty, forKey: Self.usedKey) }
                    completion(status == errSecSuccess)
                }
            }
        }
    }
}

/// Asks for Touch ID (or the Mac's password) before the accounts can be added to or deleted.
@MainActor
enum DeviceOwnerCheck {
    static func confirm(reason: String, completion: @escaping @MainActor (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // A Mac without a password has nothing to ask for; anything else is a refusal.
            completion((error as? LAError)?.code == .passcodeNotSet)
            return
        }
        // The closure holds the context: letting go of it would cancel the question.
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [context] success, _ in
            _ = context
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(success) } }
        }
    }
}
