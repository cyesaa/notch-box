import Foundation
import Testing
@testable import NotchBoxCore

/// Builds Google Authenticator export QR texts the way the app does, to read them back.
enum MigrationFixture {
    struct Account {
        var secret: Data
        var name: String
        var issuer: String
        var digits = 6
        var totp = true
        var algorithm = 1
    }

    static func varint(_ v: Int) -> [UInt8] {
        var value = UInt(v), out: [UInt8] = []
        repeat { var b = UInt8(value & 0x7f); value >>= 7; if value != 0 { b |= 0x80 }; out.append(b) } while value != 0
        return out
    }

    static func lengthDelimited(field: Int, _ bytes: [UInt8]) -> [UInt8] {
        [UInt8(field << 3 | 2)] + varint(bytes.count) + bytes
    }

    static func varintField(_ field: Int, _ v: Int) -> [UInt8] { [UInt8(field << 3 | 0)] + varint(v) }

    static func uri(bytes: [UInt8]) -> String {
        let base64 = Data(bytes).base64EncodedString()
        let escaped = base64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64
        return "otpauth-migration://offline?data=\(escaped)"
    }

    static func uri(_ accounts: [Account], batchSize: Int? = nil, batchIndex: Int? = nil) -> String {
        var payload: [UInt8] = []
        for a in accounts {
            var params: [UInt8] = []
            params += lengthDelimited(field: 1, Array(a.secret))
            params += lengthDelimited(field: 2, Array(a.name.utf8))
            params += lengthDelimited(field: 3, Array(a.issuer.utf8))
            params += varintField(4, a.algorithm)
            params += varintField(5, a.digits == 8 ? 2 : 1)
            params += varintField(6, a.totp ? 2 : 1)
            payload += lengthDelimited(field: 1, params)
        }
        payload += varintField(2, 1) // version
        if let batchSize { payload += varintField(3, batchSize) }
        if let batchIndex { payload += varintField(4, batchIndex) }
        payload += varintField(5, 123_456) // batch id
        return uri(bytes: payload)
    }
}

struct OTPScanTests {
    let secret = Data("12345678901234567890".utf8)

    @Test func aSingleAccountCodeIsOneAccount() {
        let scan = OTPAuth.scan("otpauth://totp/GitHub:alice?secret=GEZDGNBVGY3TQOJQ&issuer=GitHub\n")
        #expect(scan?.accounts.count == 1)
        #expect(scan?.accounts.first?.issuer == "GitHub")
        #expect(scan?.batchSize == 1)
    }

    @Test func anExportCarriesItsPlaceInTheBatch() {
        let uri = MigrationFixture.uri([.init(secret: secret, name: "a", issuer: "A")], batchSize: 3, batchIndex: 1)
        let scan = OTPAuth.scan(uri)
        #expect(scan?.accounts.count == 1)
        #expect(scan?.batchSize == 3)
        #expect(scan?.batchIndex == 1)
    }

    @Test func countsWhatItCannotMakeCodesFor() {
        let uri = MigrationFixture.uri([
            .init(secret: secret, name: "a", issuer: "A"),
            .init(secret: Data([1, 2]), name: "counter", issuer: "Legacy", totp: false),
            .init(secret: Data([3, 4]), name: "md5", issuer: "Old", algorithm: 4),
        ])
        let scan = OTPAuth.scan(uri)
        #expect(scan?.accounts.count == 1)
        #expect(scan?.unsupported == 2)
        #expect(OTPAuth.scan("otpauth://hotp/x?secret=GEZDGNBVGY3TQOJQ&counter=0") == OTPScan(accounts: [], unsupported: 1))
    }

    @Test func otherQRCodesAreNotAuthenticatorCodes() {
        #expect(OTPAuth.scan("https://example.com") == nil)
        #expect(OTPAuth.scan("WIFI:S:home;T:WPA;P:secret;;") == nil)
        #expect(OTPAuth.scan("") == nil)
        #expect(OTPAuth.scan("otpauth://totp/x") == nil)
    }

    @Test func theServiceWrittenIntoTheNameBecomesTheIssuer() {
        let uri = MigrationFixture.uri([
            .init(secret: secret, name: "GitHub:alice@example.com", issuer: ""),
            .init(secret: Data([9, 9]), name: "Google:bob@gmail.com", issuer: "Google"),
            .init(secret: Data([8, 8]), name: "carol@work.com", issuer: "Okta"),
        ])
        let accounts = OTPAuth.accounts(fromMigration: uri)
        let labels = accounts.map { "\($0.issuer)|\($0.name)" }
        #expect(labels == ["GitHub|alice@example.com", "Google|bob@gmail.com", "Okta|carol@work.com"])
    }

    @Test func readsURLSafeAndUnpaddedBase64() {
        let standard = MigrationFixture.uri([.init(secret: Data([0xfb, 0xff, 0xfe, 0x01]), name: "a", issuer: "A")])
        let data = String(standard.dropFirst("otpauth-migration://offline?data=".count)).removingPercentEncoding ?? ""
        let urlSafe = data.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let accounts = OTPAuth.accounts(fromMigration: "otpauth-migration://offline?data=\(urlSafe)")
        #expect(accounts.first?.secret == Data([0xfb, 0xff, 0xfe, 0x01]))
    }
}

/// A QR code is whatever somebody printed: none of these may crash.
struct HostileCodeTests {
    @Test func aLengthThatDoesNotFitIsRefused() {
        // Field 1, length-delimited, claiming 2^64-1 bytes.
        let huge: [UInt8] = [0x0a, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01, 0x01]
        #expect(OTPAuth.accounts(fromMigration: MigrationFixture.uri(bytes: huge)).isEmpty)
        // A length a little past the end.
        #expect(OTPAuth.accounts(fromMigration: MigrationFixture.uri(bytes: [0x0a, 0x05, 0x01])).isEmpty)
    }

    @Test func truncatedFixedFieldsAreSkipped() {
        // Field 7 as 64-bit and field 8 as 32-bit, both cut short, then a length-delimited field.
        #expect(OTPAuth.accounts(fromMigration: MigrationFixture.uri(bytes: [0x39, 0x01, 0x02])).isEmpty)
        #expect(OTPAuth.accounts(fromMigration: MigrationFixture.uri(bytes: [0x45, 0x01, 0x0a, 0x01])).isEmpty)
    }

    @Test func aVarintThatNeverEndsIsRefused() {
        let endless = [UInt8](repeating: 0xff, count: 40)
        #expect(OTPAuth.accounts(fromMigration: MigrationFixture.uri(bytes: endless)).isEmpty)
    }

    @Test func absurdDigitsAndPeriodsFallBackToTheUsual() {
        let account = OTPAuth.account(fromURI: "otpauth://totp/x?secret=GEZDGNBVGY3TQOJQ&digits=99&period=0")
        #expect(account?.digits == 6)
        #expect(account?.period == 30)
        let negative = OTPAuth.account(fromURI: "otpauth://totp/x?secret=GEZDGNBVGY3TQOJQ&digits=-3&period=-30")
        #expect(negative?.digits == 6)
        #expect(negative?.period == 30)
    }

    @Test func makingACodeNeverCrashesOnBadNumbers() {
        let secret = Data("12345678901234567890".utf8)
        let date = Date(timeIntervalSince1970: 59)
        #expect(TOTP.code(secret: secret, at: date, digits: 99, period: 0).count == 10)
        #expect(TOTP.code(secret: secret, at: date, digits: 0, period: -.infinity).count == 1)
        #expect(TOTP.code(secret: secret, at: date, digits: 6, period: .nan) == "287082")
        #expect(TOTP.secondsRemaining(at: date, period: 0) == 1)
        #expect(TOTP.secondsRemaining(at: Date(timeIntervalSince1970: -5), period: 30) == 30)
        #expect(TOTP.code(secret: Data(), at: date).count == 6)
    }
}

struct TOTPProgressTests {
    @Test func progressRunsFromZeroToOneOverThePeriod() {
        #expect(TOTP.progress(at: Date(timeIntervalSince1970: 0)) == 0)
        #expect(TOTP.progress(at: Date(timeIntervalSince1970: 15)) == 0.5)
        #expect(TOTP.progress(at: Date(timeIntervalSince1970: 45)) == 0.5)
        #expect(TOTP.progress(at: Date(timeIntervalSince1970: 30), period: 60) == 0.5)
    }

    @Test func codesAreShownInTwoHalves() {
        #expect(TOTP.spaced("123456") == "123 456")
        #expect(TOTP.spaced("12345678") == "1234 5678")
        #expect(TOTP.spaced("1234567") == "1234567")
        #expect(TOTP.spaced("") == "")
    }
}

struct AuthVaultTests {
    let github = OTPAccount(secret: Data([1, 2, 3]), issuer: "GitHub", name: "alice")
    let google = OTPAccount(secret: Data([4, 5, 6]), issuer: "Google", name: "alice@gmail.com", digits: 8, period: 60, algorithm: .sha256)

    func entries() -> [AuthEntry] {
        [AuthEntry(id: "1", account: github), AuthEntry(id: "2", account: google)]
    }

    @Test func savedAccountsReadBackTheSame() throws {
        let data = try #require(AuthVault.encode(entries()))
        #expect(AuthVault.decode(data) == entries())
    }

    @Test func junkDoesNotDecode() {
        #expect(AuthVault.decode(Data("not json".utf8)) == nil)
        #expect(AuthVault.decode(Data()) == nil)
    }

    @Test func addingSkipsAccountsAlreadyStored() {
        var stored = [AuthEntry(id: "1", account: github)]
        var next = 1
        let renamed = OTPAccount(secret: github.secret, issuer: "GitHub", name: "renamed")
        let added = AuthVault.add([renamed, google, google], to: &stored) { next += 1; return "\(next)" }
        #expect(added == 1)
        #expect(stored == entries())
    }

    @Test func pinsOfDeletedAccountsAreDropped() {
        let pins = ["github.com": "1", "example.com": "gone"]
        #expect(AuthVault.pins(pins, keeping: entries()) == ["github.com": "1"])
    }

    @Test func theAccountsForThePageComeFirst() {
        let ids = AuthVault.ordered(entries(), matching: ["2"]).map(\.id)
        #expect(ids == ["2", "1"])
        let unknown = AuthVault.ordered(entries(), matching: ["gone"]).map(\.id)
        #expect(unknown == ["1", "2"])
    }

    @Test func anAccountWithoutAnIssuerIsCalledByItsName() {
        let bare = AuthEntry(id: "3", account: OTPAccount(secret: Data([7]), issuer: "", name: "bob@acme.com"))
        #expect(bare.title == "bob@acme.com")
        #expect(bare.subtitle == "")
        #expect(entries()[0].title == "GitHub")
        #expect(entries()[0].subtitle == "alice")
    }
}

struct AuthImportTests {
    let secretA = Data("12345678901234567890".utf8)
    let secretB = Data([1, 2, 3, 4, 5])

    @Test func theSameCodeSeenAgainAddsNothing() {
        var session = AuthImport()
        let uri = MigrationFixture.uri([.init(secret: secretA, name: "a", issuer: "A"), .init(secret: secretB, name: "b", issuer: "B")])
        #expect(session.add(payload: uri) == .added(2))
        #expect(session.add(payload: uri) == .nothingNew)
        #expect(session.accounts.count == 2)
        #expect(!session.isWaitingForMore)
    }

    @Test func aSplitExportWaitsForItsOtherParts() {
        var session = AuthImport()
        let first = MigrationFixture.uri([.init(secret: secretA, name: "a", issuer: "A")], batchSize: 2, batchIndex: 0)
        let second = MigrationFixture.uri([.init(secret: secretB, name: "b", issuer: "B")], batchSize: 2, batchIndex: 1)
        #expect(session.add(payload: first) == .added(1))
        #expect(session.isWaitingForMore)
        #expect(session.scannedBatches == 1)
        #expect(session.batchSize == 2)
        #expect(session.add(payload: second) == .added(1))
        #expect(!session.isWaitingForMore)
        #expect(session.accounts.count == 2)
    }

    @Test func otherQRCodesAreReportedAndChangeNothing() {
        var session = AuthImport()
        #expect(session.add(payload: "https://example.com") == .notACode)
        #expect(session.accounts.isEmpty)
    }

    @Test func unsupportedAccountsAreCountedOncePerCode() {
        var session = AuthImport()
        let uri = MigrationFixture.uri([.init(secret: secretA, name: "a", issuer: "A"), .init(secret: secretB, name: "b", issuer: "B", totp: false)])
        #expect(session.add(payload: uri) == .added(1))
        #expect(session.add(payload: uri) == .nothingNew)
        #expect(session.unsupported == 1)
    }

    @Test func singleAccountCodesAddUp() {
        var session = AuthImport()
        #expect(session.add(payload: "otpauth://totp/A:a?secret=GEZDGNBVGY3TQOJQ") == .added(1))
        #expect(session.add(payload: "otpauth://totp/B:b?secret=JBSWY3DP") == .added(1))
        // The same secret under another label is the same account.
        #expect(session.add(payload: "otpauth://totp/C:c?secret=JBSWY3DP") == .nothingNew)
        #expect(session.accounts.count == 2)
    }
}
