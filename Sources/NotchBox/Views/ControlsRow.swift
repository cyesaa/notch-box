import SwiftUI

/// Previous / play-pause / next. Play-pause sits in a white disc as the main action.
struct ControlsRow: View {
    /// nil in degraded mode: the play state is unknown.
    let isPlaying: Bool?
    let onPrevious: @MainActor () -> Void
    let onTogglePlayPause: @MainActor () -> Void
    let onNext: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 18) {
            SkipButton(systemName: "backward.fill", label: L10n.previous, action: onPrevious)
            Button(action: onTogglePlayPause) {
                Image(systemName: playPauseSymbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black)
                    // The play triangle looks off-centre when centred by its bounds.
                    .offset(x: isPlaying == false ? 1.5 : 0)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(L10n.playPause)
            SkipButton(systemName: "forward.fill", label: L10n.next, action: onNext)
        }
    }

    private var playPauseSymbol: String {
        switch isPlaying {
        case .some(true): return "pause.fill"
        case .some(false): return "play.fill"
        case .none: return "playpause.fill"
        }
    }
}

private struct SkipButton: View {
    let systemName: String
    let label: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NotchTheme.primaryText)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}
