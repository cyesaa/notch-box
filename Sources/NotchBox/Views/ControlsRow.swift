import SwiftUI

struct ControlsRow: View {
    /// nil in degraded mode: the play state is unknown.
    let isPlaying: Bool?
    let onPrevious: @MainActor () -> Void
    let onTogglePlayPause: @MainActor () -> Void
    let onNext: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 36) {
            ControlButton(systemName: "backward.fill", size: 15, label: L10n.previous, action: onPrevious)
            ControlButton(systemName: playPauseSymbol, size: 21, label: L10n.playPause, action: onTogglePlayPause)
            ControlButton(systemName: "forward.fill", size: 15, label: L10n.next, action: onNext)
        }
        .frame(height: 24)
    }

    private var playPauseSymbol: String {
        switch isPlaying {
        case .some(true): return "pause.fill"
        case .some(false): return "play.fill"
        case .none: return "playpause.fill"
        }
    }
}

private struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    let label: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 32, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
