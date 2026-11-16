import Foundation

/// One TOTP account: the secret and how to turn it into a code, plus who it is for.
public struct OTPAccount: Equatable, Codable, Sendable {
    public var secret: Data
    /// The service, e.g. "GitHub"; may be empty.
    public var issuer: String
    /// The account on that service, often an email; may be empty.
    public var name: String
    public var digits: Int
    public var period: TimeInterval
    public var algorithm: OTPAlgorithm

    public init(secret: Data, issuer: String, name: String, digits: Int = 6, period: TimeInterval = 30, algorithm: OTPAlgorithm = .sha1) {
        self.secret = secret
        self.issuer = issuer
        self.name = name
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
    }

    /// The code for this account right now.
    public func code(at time: Date) -> String {
        TOTP.code(secret: secret, at: time, digits: digits, period: period, algorithm: algorithm)
    }
}

/// What one scanned QR code holds.
public struct OTPScan: Equatable, Sendable {
    public var accounts: [OTPAccount]
    /// Accounts in the code NotchBox cannot make codes for (counter-based ones, MD5).
    public var unsupported: Int
    /// Google Authenticator splits a large export over several QR codes: this is part `batchIndex`
    /// (counted from 0) of `batchSize`.
    public var batchIndex: Int
    public var batchSize: Int

    public init(accounts: [OTPAccount], unsupported: Int = 0, batchIndex: Int = 0, batchSize: Int = 1) {
        self.accounts = accounts
        self.unsupported = unsupported
        self.batchIndex = batchIndex
        self.batchSize = batchSize
    }
}

/// Reads the two shapes an authenticator's accounts arrive in: a single `otpauth://totp/...` URI (one QR
/// per account), and the `otpauth-migration://offline?data=...` export Google Authenticator makes (all
/// accounts in one QR, protobuf-encoded). A QR code is untrusted input: nothing here may crash on it.
public enum OTPAuth {
    /// What a QR code's text holds, or nil when it is not an authenticator code at all.
    public static func scan(_ payload: String) -> OTPScan? {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let account = account(fromURI: text) { return OTPScan(accounts: [account]) }
        if let components = URLComponents(string: text), components.scheme?.lowercased() == "otpauth" {
            // A counter-based (HOTP) account, or a TOTP one without a usable secret.
            return components.host?.lowercased() == "hotp" ? OTPScan(accounts: [], unsupported: 1) : nil
        }
        return migration(from: text)
    }

    /// One account from an `otpauth://totp/<label>?secret=...` URI, or nil if it is not a TOTP URI.
    public static func account(fromURI uri: String) -> OTPAccount? {
        guard let components = URLComponents(string: uri), components.scheme?.lowercased() == "otpauth",
              components.host?.lowercased() == "totp" else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let secretBase32 = value("secret"), let secret = Base32.decode(secretBase32), !secret.isEmpty else { return nil }

        // The label is "/Issuer:account" or "/account"; the issuer query item wins when present.
        let label = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        let labelParts = label.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        let issuer = value("issuer") ?? (labelParts.count == 2 ? labelParts[0] : "")
        let name = labelParts.count == 2 ? labelParts[1] : label

        return OTPAccount(
            secret: secret,
            issuer: issuer,
            name: name,
            digits: sensibleDigits(Int(value("digits") ?? "") ?? 6),
            period: sensiblePeriod(TimeInterval(value("period") ?? "") ?? 30),
            algorithm: value("algorithm").flatMap { OTPAlgorithm(rawValue: $0.uppercased()) } ?? .sha1
        )
    }

    /// Every TOTP account in a Google Authenticator export (`otpauth-migration://offline?data=<base64>`).
    public static func accounts(fromMigration uri: String) -> [OTPAccount] {
        migration(from: uri)?.accounts ?? []
    }

    /// A Google Authenticator export QR code, or nil if `uri` is not one.
    public static func migration(from uri: String) -> OTPScan? {
        guard let components = URLComponents(string: uri), components.scheme?.lowercased() == "otpauth-migration",
              let encoded = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = base64(encoded) else { return nil }
        return parseMigration(data)
    }

    /// Codes are 6 to 8 digits; anything else in a QR code is a mistake (or an attack) and reads as 6.
    static func sensibleDigits(_ digits: Int) -> Int {
        (6...8).contains(digits) ? digits : 6
    }

    static func sensiblePeriod(_ period: TimeInterval) -> TimeInterval {
        period.isFinite && period >= 1 && period <= 3_600 ? period : 30
    }

    /// Authenticators often write the service into the account name ("GitHub:alice"). It becomes the
    /// issuer when that is blank, and is dropped from the name when it only repeats the issuer.
    static func tidy(issuer: String, name: String) -> (issuer: String, name: String) {
        let issuer = issuer.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        let parts = name.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return (issuer, name) }
        if issuer.isEmpty { return (parts[0], parts[1]) }
        if parts[0].caseInsensitiveCompare(issuer) == .orderedSame { return (issuer, parts[1]) }
        return (issuer, name)
    }

    /// Standard or URL-safe base64, with or without padding (a "+" may have arrived as a space).
    private static func base64(_ text: String) -> Data? {
        var normal = text.replacingOccurrences(of: " ", with: "+")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normal.count % 4 != 0 { normal.append("=") }
        return Data(base64Encoded: normal)
    }

    /// MigrationPayload: 1 repeated OtpParameters, 3 batch size, 4 batch index; the rest is skipped.
    static func parseMigration(_ data: Data) -> OTPScan {
        var reader = ProtobufReader(data)
        var scan = OTPScan(accounts: [])
        while let tag = reader.varint() {
            let field = tag >> 3, wire = Int(tag & 0x7)
            switch (field, wire) {
            case (1, 2):
                guard let bytes = reader.lengthDelimited() else { return scan }
                switch parseOTPParameters(bytes) {
                case .account(let account): scan.accounts.append(account)
                case .unsupported: scan.unsupported += 1
                case .empty: break
                }
            case (3, 0): scan.batchSize = max(1, Int(clamping: reader.varint() ?? 1))
            case (4, 0): scan.batchIndex = max(0, Int(clamping: reader.varint() ?? 0))
            default: reader.skip(wireType: wire)
            }
        }
        return scan
    }

    private enum Parameters {
        case account(OTPAccount)
        case unsupported
        case empty
    }

    /// OtpParameters: 1 secret, 2 name, 3 issuer, 4 algorithm, 5 digits, 6 type (2 = TOTP, which is all we keep).
    private static func parseOTPParameters(_ bytes: [UInt8]) -> Parameters {
        var reader = ProtobufReader(Data(bytes))
        var secret = Data(), name = "", issuer = "", algorithm: OTPAlgorithm? = .sha1, digits = 6, isTOTP = true
        while let tag = reader.varint() {
            let field = tag >> 3, wire = Int(tag & 0x7)
            switch (field, wire) {
            case (1, 2): secret = Data(reader.lengthDelimited() ?? [])
            case (2, 2): name = String(decoding: reader.lengthDelimited() ?? [], as: UTF8.self)
            case (3, 2): issuer = String(decoding: reader.lengthDelimited() ?? [], as: UTF8.self)
            case (4, 0):
                // 0 unspecified, 1 SHA1, 2 SHA256, 3 SHA512, 4 MD5 (which no code is made for).
                switch reader.varint() ?? 1 {
                case 0, 1: algorithm = .sha1
                case 2: algorithm = .sha256
                case 3: algorithm = .sha512
                default: algorithm = nil
                }
            case (5, 0): digits = (reader.varint() ?? 1) == 2 ? 8 : 6
            case (6, 0): isTOTP = (reader.varint() ?? 2) != 1 // 1 = HOTP; anything else is treated as TOTP
            default: reader.skip(wireType: wire)
            }
        }
        guard !secret.isEmpty else { return .empty }
        guard isTOTP, let algorithm else { return .unsupported }
        let label = tidy(issuer: issuer, name: name)
        return .account(OTPAccount(secret: secret, issuer: label.issuer, name: label.name, digits: digits, algorithm: algorithm))
    }
}

/// Just enough of the protobuf wire format to read a Google Authenticator export: varints and byte strings.
struct ProtobufReader {
    private let bytes: [UInt8]
    private var index = 0

    init(_ data: Data) { bytes = Array(data) }

    mutating func varint() -> UInt64? {
        var result: UInt64 = 0, shift: UInt64 = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    mutating func lengthDelimited() -> [UInt8]? {
        // Compared as unsigned: a length a hostile code claims may not fit in an Int.
        guard let length = varint(), length <= UInt64(bytes.count - index) else {
            index = bytes.count
            return nil
        }
        defer { index += Int(length) }
        return Array(bytes[index ..< index + Int(length)])
    }

    mutating func skip(wireType: Int) {
        switch wireType {
        case 0: _ = varint()
        case 1: index = min(index + 8, bytes.count)
        case 2: _ = lengthDelimited()
        case 5: index = min(index + 4, bytes.count)
        default: index = bytes.count
        }
    }
}

/// RFC 4648 base32, which `otpauth://` secrets use (upper-case, padding optional).
public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    public static func decode(_ string: String) -> Data? {
        let trimmed = string.uppercased().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: " ", with: "")
        guard !trimmed.isEmpty else { return nil }
        var lookup: [Character: UInt8] = [:]
        for (i, c) in alphabet.enumerated() { lookup[c] = UInt8(i) }

        var bits: UInt = 0, count = 0
        var output = Data()
        for character in trimmed {
            guard let value = lookup[character] else { return nil }
            bits = (bits << 5) | UInt(value)
            count += 5
            if count >= 8 {
                count -= 8
                output.append(UInt8((bits >> UInt(count)) & 0xff))
            }
        }
        return output
    }
}
