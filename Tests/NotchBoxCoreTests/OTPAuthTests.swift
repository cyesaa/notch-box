import Foundation
import Testing
@testable import NotchBoxCore

struct Base32Tests {
    @Test func decodesTheRFCSecret() {
        // "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" is base32 for the ASCII "12345678901234567890".
        #expect(Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") == Data("12345678901234567890".utf8))
    }

    @Test func ignoresPaddingCaseAndSpaces() {
        // "JBSWY3DP" is base32 for "Hello".
        #expect(Base32.decode("JBSWY3DP") == Data("Hello".utf8))
        #expect(Base32.decode("jbsw y3dp") == Data("Hello".utf8))
        #expect(Base32.decode("JBSWY3DP====") == Data("Hello".utf8))
    }

    @Test func rejectsCharactersOutsideTheAlphabet() {
        #expect(Base32.decode("0189") == nil)
        #expect(Base32.decode("") == nil)
    }
}

struct OTPAuthURITests {
    @Test func readsASecretIssuerAndName() {
        let account = OTPAuth.account(fromURI: "otpauth://totp/GitHub:alice@example.com?secret=GEZDGNBVGY3TQOJQ&issuer=GitHub&digits=6&period=30")
        #expect(account?.issuer == "GitHub")
        #expect(account?.name == "alice@example.com")
        #expect(account?.digits == 6)
        #expect(account?.secret == Base32.decode("GEZDGNBVGY3TQOJQ"))
    }

    @Test func takesTheIssuerFromTheLabelWhenThereIsNoIssuerItem() {
        let account = OTPAuth.account(fromURI: "otpauth://totp/Google:bob@gmail.com?secret=GEZDGNBVGY3TQOJQ")
        #expect(account?.issuer == "Google")
        #expect(account?.name == "bob@gmail.com")
        #expect(account?.algorithm == .sha1)
    }

    @Test func rejectsNonTOTPURIs() {
        #expect(OTPAuth.account(fromURI: "otpauth://hotp/x?secret=GEZDGNBVGY3TQOJQ&counter=0") == nil)
        #expect(OTPAuth.account(fromURI: "https://example.com") == nil)
        #expect(OTPAuth.account(fromURI: "otpauth://totp/x") == nil)
    }
}

struct OTPMigrationTests {
    /// Builds a Google Authenticator export the way the app does, to read it back.
    private func migrationURI(_ accounts: [(secret: Data, name: String, issuer: String, digits: Int, totp: Bool)]) -> String {
        func varint(_ v: Int) -> [UInt8] {
            var value = UInt(v), out: [UInt8] = []
            repeat { var b = UInt8(value & 0x7f); value >>= 7; if value != 0 { b |= 0x80 }; out.append(b) } while value != 0
            return out
        }
        func lengthDelimited(field: Int, _ bytes: [UInt8]) -> [UInt8] {
            [UInt8(field << 3 | 2)] + varint(bytes.count) + bytes
        }
        func varintField(_ field: Int, _ v: Int) -> [UInt8] { [UInt8(field << 3 | 0)] + varint(v) }

        var payload: [UInt8] = []
        for a in accounts {
            var params: [UInt8] = []
            params += lengthDelimited(field: 1, Array(a.secret))
            params += lengthDelimited(field: 2, Array(a.name.utf8))
            params += lengthDelimited(field: 3, Array(a.issuer.utf8))
            params += varintField(4, 1)                       // algorithm = SHA1
            params += varintField(5, a.digits == 8 ? 2 : 1)   // digit count
            params += varintField(6, a.totp ? 2 : 1)          // type
            payload += lengthDelimited(field: 1, params)
        }
        let base64 = Data(payload).base64EncodedString()
        let escaped = base64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64
        return "otpauth-migration://offline?data=\(escaped)"
    }

    @Test func readsEveryTOTPAccountFromAnExport() {
        let secretA = Data("12345678901234567890".utf8)
        let secretB = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let uri = migrationURI([
            (secretA, "alice@example.com", "GitHub", 6, true),
            (secretB, "bob@work.com", "Okta", 8, true),
        ])
        let accounts = OTPAuth.accounts(fromMigration: uri)
        #expect(accounts.count == 2)
        #expect(accounts[0] == OTPAccount(secret: secretA, issuer: "GitHub", name: "alice@example.com", digits: 6))
        #expect(accounts[1].issuer == "Okta")
        #expect(accounts[1].digits == 8)
        #expect(accounts[1].secret == secretB)
    }

    @Test func skipsHOTPAccounts() {
        let uri = migrationURI([
            (Data("12345678901234567890".utf8), "a", "A", 6, true),
            (Data([0xAA, 0xBB]), "counter-based", "Legacy", 6, false),
        ])
        let issuers = OTPAuth.accounts(fromMigration: uri).map(\.issuer)
        #expect(issuers == ["A"])
    }

    @Test func aGeneratedCodeFromAnImportedAccountMatchesRFC() {
        let uri = migrationURI([(Data("12345678901234567890".utf8), "a", "A", 8, true)])
        let account = OTPAuth.accounts(fromMigration: uri)[0]
        #expect(account.code(at: Date(timeIntervalSince1970: 59)) == "94287082")
    }

    @Test func junkDataReadsAsNoAccounts() {
        #expect(OTPAuth.accounts(fromMigration: "otpauth-migration://offline?data=%%%").isEmpty)
        #expect(OTPAuth.accounts(fromMigration: "https://example.com").isEmpty)
    }
}
