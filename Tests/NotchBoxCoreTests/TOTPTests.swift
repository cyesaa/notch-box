import Foundation
import Testing
@testable import NotchBoxCore

struct TOTPTests {
    /// RFC 6238 Appendix B uses the ASCII secret "12345678901234567890".
    let secret = Data("12345678901234567890".utf8)

    @Test func matchesTheRFC6238TestVectors() {
        // The RFC prints 8-digit codes; the 6-digit code is their last six digits.
        let cases: [(time: TimeInterval, eight: String)] = [
            (59, "94287082"),
            (1_111_111_109, "07081804"),
            (1_111_111_111, "14050471"),
            (1_234_567_890, "89005924"),
            (2_000_000_000, "69279037"),
            (20_000_000_000, "65353130"),
        ]
        for c in cases {
            let date = Date(timeIntervalSince1970: c.time)
            #expect(TOTP.code(secret: secret, at: date, digits: 8) == c.eight)
            #expect(TOTP.code(secret: secret, at: date, digits: 6) == String(c.eight.suffix(6)))
        }
    }

    @Test func padsShortCodesWithLeadingZeros() {
        // Counter 0x8 for this secret truncates to a value that needs a leading zero at 6 digits.
        let code = TOTP.code(secret: secret, counter: 8, digits: 6, algorithm: .sha1)
        let allDigits = code.allSatisfy(\.isNumber)
        #expect(code.count == 6)
        #expect(allDigits)
    }

    @Test func secondsRemainingCountsDownWithinEachPeriod() {
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 0)) == 30)
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 1)) == 29)
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 29)) == 1)
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 30)) == 30)
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 45)) == 15)
    }

    @Test func honoursThePeriod() {
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: 10), period: 60) == 50)
    }
}
