import Foundation

public enum TimeFormatter {
    /// "1:12", "1:02:03". Negative values become "0:00".
    public static func string(from seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "-2:31"
    public static func remaining(elapsed: TimeInterval, duration: TimeInterval) -> String {
        "-" + string(from: max(0, duration - elapsed))
    }
}
