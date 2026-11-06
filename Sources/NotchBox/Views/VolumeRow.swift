import SwiftUI

/// Compact system volume: a speaker that shows the level and a short bar.
struct VolumeRow: View {
    let volume: Float
    let isEnabled: Bool
    let onChange: @MainActor (Float) -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: speakerSymbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchTheme.secondaryText)
                .frame(width: 18, alignment: .leading)
                .accessibilityHidden(true)
            ScrubBar(
                fraction: Double(volume),
                tint: Color.white.opacity(0.85),
                isEnabled: isEnabled,
                accessibilityLabel: L10n.volume,
                accessibilityValue: "\(Int((volume * 100).rounded())) %",
                onChange: { onChange(Float($0)) }
            )
            .frame(width: 70)
        }
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var speakerSymbol: String {
        switch volume {
        case ..<0.01: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}
