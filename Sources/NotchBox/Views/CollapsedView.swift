import NotchBoxCore
import SwiftUI

/// Mini state: artwork left of the notch, a waveform in the cover's colour right of it.
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
            Color.clear
                .frame(width: notch.width)
            WaveformView(isPlaying: model.info?.clock.isPlaying ?? false, tint: Color(model.accent))
                .frame(width: artworkSide * 0.85, height: notch.height * 0.4)
                .frame(width: side)
        }
        .frame(height: notch.height)
    }
}
