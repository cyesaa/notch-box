import SwiftUI

/// A slim capsule bar that can be dragged or clicked anywhere. Replaces `Slider`, whose AppKit
/// look does not fit the notch. The hit area is taller than the bar.
/// (No @State: the SwiftUI macro plugin ships only with Xcode; the owner keeps the drag value.)
struct ScrubBar: View {
    /// 0...1
    let fraction: Double
    let tint: Color
    /// Drawn thicker while the user drags (the owner knows when a drag is in progress).
    var isActive = false
    var isEnabled = true
    let accessibilityLabel: String
    let accessibilityValue: String
    /// Called with the new fraction while dragging.
    let onChange: @MainActor (Double) -> Void
    /// Called when the drag ends.
    var onEnd: @MainActor () -> Void = {}

    private static let hitHeight: CGFloat = 14
    private static let step = 0.05

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let clamped = min(max(fraction, 0), 1)
            let barHeight: CGFloat = isActive ? 6 : 4
            ZStack(alignment: .leading) {
                Capsule().fill(NotchTheme.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(barHeight, width * clamped))
            }
            .frame(height: barHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        onChange(min(max(value.location.x / width, 0), 1))
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        onEnd()
                    }
            )
            .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .frame(height: Self.hitHeight)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: onChange(min(1, fraction + Self.step))
            case .decrement: onChange(max(0, fraction - Self.step))
            @unknown default: return
            }
            onEnd()
        }
    }
}
