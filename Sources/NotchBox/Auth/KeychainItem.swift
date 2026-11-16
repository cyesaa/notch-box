import Foundation
import Security

/// One generic-password item in the user's login keychain.
///
/// NotchBox is signed ad hoc, so macOS knows it by the hash of its code: after every update the first
/// read makes macOS ask for the keychain password once ("NotchBox wants to use your confidential
/// information…"). Everything is kept in a single item so that it asks once, not once per account.
struct KeychainItem {
    let service: String
    let account: String
    /// The item's name in Keychain Access and in macOS's question.
    let label: String

    enum ReadResult: Equatable {
        case data(Data)
        case missing
        /// Refused by the user, or the keychain is locked or unavailable.
        case failed(OSStatus)
    }

    func read() -> ReadResult {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return (result as? Data).map(ReadResult.data) ?? .failed(errSecDecode)
        case errSecItemNotFound: return .missing
        default: return .failed(status)
        }
    }

    /// Replaces the item's contents, creating it when it does not exist.
    func write(_ data: Data) -> OSStatus {
        let status = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return status }
        var item = identity
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = label
        return SecItemAdd(item as CFDictionary, nil)
    }

    /// Removes the item; an item that is already gone counts as removed.
    func delete() -> OSStatus {
        let status = SecItemDelete(identity as CFDictionary)
        return status == errSecItemNotFound ? errSecSuccess : status
    }

    private var identity: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
