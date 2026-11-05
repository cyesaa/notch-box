import NotchBoxCore
import SwiftUI

/// Elapsed / slider / remaining. While dragging, `scrubPosition` overrides the clock;
/// the seek is sent when the drag ends. (No @State: the SwiftUI macro plugin ships only with Xcode.)
struct ProgressRow: View {
    let clock: PlaybackClock
    let scrubPosition: TimeInterval?
    let onScrub: @MainActor (TimeInterval) -> Void
    let onScrubEnd: @MainActor () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = clock.duration ?? 0
            let elapsed = scrubPosition ?? clock.elapsed(at: context.date)
            HStack(spacing: 8) {
                Text(TimeFormatter.string(from: elapsed))
                    .frame(width: 36, alignment: .trailing)
                Slider(
                    value: Binding(get: { elapsed }, set: { onScrub($0) }),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if !editing { onScrubEnd() }
                    }
                )
                .controlSize(.mini)
                .tint(.white)
                Text(TimeFormatter.remaining(elapsed: elapsed, duration: duration))
                    .frame(width: 40, alignment: .leading)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.6))
        }
    }
}
