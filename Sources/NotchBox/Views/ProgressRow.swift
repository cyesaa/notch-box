import NotchBoxCore
import SwiftUI

/// Elapsed / bar / remaining. While dragging, `scrubPosition` overrides the clock;
/// the seek is sent when the drag ends. (No @State: the SwiftUI macro plugin ships only with Xcode.)
struct ProgressRow: View {
    let clock: PlaybackClock
    let scrubPosition: TimeInterval?
    let tint: Color
    let onScrub: @MainActor (TimeInterval) -> Void
    let onScrubEnd: @MainActor () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(clock.duration ?? 0, 1)
            let elapsed = min(scrubPosition ?? clock.elapsed(at: context.date), duration)
            HStack(spacing: 10) {
                Text(TimeFormatter.string(from: elapsed))
                    .frame(width: 34, alignment: .trailing)
                ScrubBar(
                    fraction: elapsed / duration,
                    tint: tint,
                    isActive: scrubPosition != nil,
                    accessibilityLabel: L10n.position,
                    accessibilityValue: TimeFormatter.string(from: elapsed),
                    onChange: { onScrub($0 * duration) },
                    onEnd: onScrubEnd
                )
                Text(TimeFormatter.remaining(elapsed: elapsed, duration: duration))
                    .frame(width: 38, alignment: .leading)
            }
            .font(NotchTheme.timeFont)
            .foregroundStyle(NotchTheme.secondaryText)
        }
    }
}
