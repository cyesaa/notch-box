import Foundation

/// Arguments for `/usr/bin/perl mediaremote-adapter.pl <framework> <command>`.
public enum AdapterCommandLine {
    public static let perlPath = "/usr/bin/perl"
    public static let streamArguments = ["stream", "--no-diff", "--micros", "--debounce=100"]

    /// Both paths must be absolute.
    public static func baseArguments(scriptPath: String, frameworkPath: String) -> [String] {
        [scriptPath, frameworkPath]
    }

    public static func arguments(for command: MediaCommand) -> [String] {
        switch command {
        case .togglePlayPause:
            return ["send", "2"]
        case .next:
            return ["send", "4"]
        case .previous:
            return ["send", "5"]
        case .seek(let seconds):
            let safe = seconds.isFinite ? min(max(0, seconds), AdapterStreamParser.maxSeconds) : 0
            let micros = Int64((safe * 1_000_000).rounded())
            return ["seek", String(micros)]
        }
    }
}
