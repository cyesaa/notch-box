import Foundation

public enum TimeFormatter {
    /// "1:12", "1:02:03". Negative and non-finite values become "0:00"; values above 99:59:59 are capped.
    public static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(min(max(0, seconds), 359_999).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(pad(minutes)):\(pad(secs))"
        }
        return "\(minutes):\(pad(secs))"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// "-2:31"
    public static func remaining(elapsed: TimeInterval, duration: TimeInterval) -> String {
        "-" + string(from: max(0, duration - elapsed))
    }
}
