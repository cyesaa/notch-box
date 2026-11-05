import Testing
@testable import NotchBoxCore

struct AdapterCommandLineTests {
    @Test func mapsCommandsToAdapterArguments() {
        #expect(AdapterCommandLine.arguments(for: .togglePlayPause) == ["send", "2"])
        #expect(AdapterCommandLine.arguments(for: .next) == ["send", "4"])
        #expect(AdapterCommandLine.arguments(for: .previous) == ["send", "5"])
    }

    @Test func seekUsesMicroseconds() {
        #expect(AdapterCommandLine.arguments(for: .seek(to: 30)) == ["seek", "30000000"])
        #expect(AdapterCommandLine.arguments(for: .seek(to: 1.5)) == ["seek", "1500000"])
        #expect(AdapterCommandLine.arguments(for: .seek(to: -5)) == ["seek", "0"])
    }

    @Test func streamAndBaseArguments() {
        #expect(AdapterCommandLine.streamArguments == ["stream", "--no-diff", "--micros", "--debounce=100"])
        #expect(AdapterCommandLine.baseArguments(scriptPath: "/a.pl", frameworkPath: "/B.framework") == ["/a.pl", "/B.framework"])
        #expect(AdapterCommandLine.perlPath == "/usr/bin/perl")
    }

    @Test func healthCheckPassesTheTestClientBeforeTheTestCommand() {
        let arguments = AdapterCommandLine.healthCheckArguments(
            scriptPath: "/a.pl", frameworkPath: "/B.framework", testClientPath: "/C"
        )
        #expect(arguments == ["/a.pl", "/B.framework", "/C", "test"])
    }

    @Test func seekSanitizesNonFiniteAndHugeValues() {
        #expect(AdapterCommandLine.arguments(for: .seek(to: .infinity)) == ["seek", "0"])
        #expect(AdapterCommandLine.arguments(for: .seek(to: .nan)) == ["seek", "0"])
        #expect(AdapterCommandLine.arguments(for: .seek(to: .greatestFiniteMagnitude)) == ["seek", "10000000000000"])
    }
}
