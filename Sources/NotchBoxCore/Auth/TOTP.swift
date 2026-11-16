import CryptoKit
import Foundation

public enum OTPAlgorithm: String, Equatable, Codable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

/// Time-based one-time passwords (RFC 6238): the code an authenticator app shows for an account.
public enum TOTP {
    /// The `digits`-long code for `secret` at `time`. Values no authenticator uses (a period of 0, 40
    /// digits) fall back to something safe instead of crashing: they can come from a scanned QR code.
    public static func code(secret: Data, at time: Date, digits: Int = 6, period: TimeInterval = 30, algorithm: OTPAlgorithm = .sha1) -> String {
        let counter = UInt64(max(0, time.timeIntervalSince1970) / safePeriod(period))
        return code(secret: secret, counter: counter, digits: digits, algorithm: algorithm)
    }

    /// The code for a counter value (RFC 4226 HOTP, which TOTP builds on); the seam the tests pin.
    static func code(secret: Data, counter: UInt64, digits: Int, algorithm: OTPAlgorithm) -> String {
        var bigEndianCounter = counter.bigEndian
        let message = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }
        let hash = hmac(key: secret, message: message, algorithm: algorithm)
        // Dynamic truncation: the low nibble of the last byte picks four bytes to read as a 31-bit number.
        let offset = Int(hash[hash.count - 1] & 0x0f)
        let binary = (UInt64(hash[offset] & 0x7f) << 24)
            | (UInt64(hash[offset + 1]) << 16)
            | (UInt64(hash[offset + 2]) << 8)
            | UInt64(hash[offset + 3])
        // The truncated number has 31 bits, so more than 10 digits would only add zeros.
        let length = min(max(digits, 1), 10)
        let modulo = UInt64(pow(10, Double(length)))
        return String(format: "%0\(length)llu", binary % modulo)
    }

    /// Whole seconds until the current code changes (1...period).
    public static func secondsRemaining(at time: Date, period: TimeInterval = 30) -> Int {
        let period = safePeriod(period)
        let into = max(0, time.timeIntervalSince1970).truncatingRemainder(dividingBy: period)
        return Int(ceil(period - into))
    }

    /// How far the current code is through its life, 0 (new) to 1 (about to change).
    public static func progress(at time: Date, period: TimeInterval = 30) -> Double {
        let period = safePeriod(period)
        return max(0, time.timeIntervalSince1970).truncatingRemainder(dividingBy: period) / period
    }

    /// A code as people read it: "123 456", "1234 5678".
    public static func spaced(_ code: String) -> String {
        guard code.count >= 6, code.count % 2 == 0 else { return code }
        let half = code.count / 2
        return code.prefix(half) + " " + code.suffix(half)
    }

    private static func safePeriod(_ period: TimeInterval) -> TimeInterval {
        period.isFinite && period >= 1 ? period : 30
    }

    private static func hmac(key: Data, message: Data, algorithm: OTPAlgorithm) -> Data {
        let symmetric = SymmetricKey(data: key)
        switch algorithm {
        case .sha1: return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetric))
        case .sha256: return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetric))
        case .sha512: return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetric))
        }
    }
}
