import NotchBoxCore
import SwiftUI

/// Shown for a moment after the system volume changes: the mini row (when something is playing)
/// with the current level in a rounded row below it.
struct VolumeHUDView: View {
    let model: NotchViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.info != nil {
                CollapsedView(model: model)
            } else {
                Color.clear.frame(height: model.notchSize.height)
            }
            VolumeLevelRow(volume: model.volume, tint: model.info != nil ? Color(model.accent) : .white)
                .frame(height: NotchLayout.volumeRowHeight - 6)
                .padding(.horizontal, 14)
            Spacer(minLength: 0)
        }
    }
}

/// Speaker, level bar and percentage. Display only; the open player has the draggable bar.
private struct VolumeLevelRow: View {
    let volume: Float
    let tint: Color

    var body: some View {
        let level = Double(min(max(volume, 0), 1))
        HStack(spacing: 10) {
            Image(systemName: speakerSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchTheme.primaryText)
                .frame(width: 18, alignment: .leading)
                .contentTransition(.symbolEffect(.replace))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(NotchTheme.track)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, geometry.size.width * level))
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity)
            }
            Text("\(Int((level * 100).rounded()))")
                .font(NotchTheme.timeFont)
                .foregroundStyle(NotchTheme.secondaryText)
                .frame(width: 26, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .animation(.easeOut(duration: 0.15), value: volume)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.volume)
        .accessibilityValue("\(Int((level * 100).rounded())) %")
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
