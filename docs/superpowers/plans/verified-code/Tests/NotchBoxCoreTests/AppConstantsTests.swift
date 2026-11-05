import Testing
@testable import NotchBoxCore

struct AppConstantsTests {
    @Test func logSubsystemMatchesBundleIdentifier() {
        #expect(AppConstants.bundleIdentifier == "com.notchbox.NotchBox")
        #expect(AppConstants.logSubsystem == AppConstants.bundleIdentifier)
    }
}
