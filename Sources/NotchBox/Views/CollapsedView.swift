import NotchBoxCore
import SwiftUI

/// Mini state: artwork left of the notch, a waveform in the cover's colour right of it. When paused the
/// waveform becomes a play button; while playing, pointing at it turns it into a pause button.
/// Only that right wing takes clicks (see `NotchInteraction`).
struct CollapsedView: View {
    let model: NotchViewModel

    var body: some View {
        let notch = model.notchSize
        let side = NotchLayout.miniSideWidth(notch: notch)
        let artworkSide = NotchLayout.miniArtworkSide(notch: notch)
        HStack(spacing: 0) {
            ArtworkView(image: model.artworkImage, version: model.artworkVersion, cornerRadius: NotchLayout.miniArtworkRadius)
                .frame(width: artworkSide, height: artworkSide)
                .frame(width: side)
            middle
                .frame(width: notch.width)
            rightWing(artworkSide: artworkSide, notch: notch)
                .frame(width: side, height: notch.height)
        }
        .frame(height: notch.height)
    }

    /// A real notch hides the camera here; a virtual one shows what is playing.
    @ViewBuilder
    private var middle: some View {
        if model.isVirtualNotch, let info = model.info {
            Text(info.artist.map { "\(info.title) · \($0)" } ?? info.title)
                .font(.system(size: max(10, model.notchSize.height * 0.46), weight: .medium))
                .foregroundStyle(NotchTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func rightWing(artworkSide: CGFloat, notch: CGSize) -> some View {
        let isPlaying = model.info?.clock.isPlaying ?? false
        if isPlaying && !model.isOverNotchButton {
            WaveformView(isPlaying: true, tint: Color(model.accent), meter: model.audioMeter)
                .frame(width: artworkSide * 0.85, height: notch.height * 0.4)
                .transition(.opacity)
        } else {
            Button(action: model.togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: max(11, notch.height * 0.42), weight: .bold))
                    .foregroundStyle(Color(model.accent))
                    .frame(width: notch.height, height: notch.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(L10n.playPause)
            .transition(.opacity)
        }
    }
}
