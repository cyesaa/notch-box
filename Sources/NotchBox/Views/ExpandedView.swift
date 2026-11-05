import NotchBoxCore
import SwiftUI

/// Full player. In degraded mode (no info) shows a message plus the controls.
struct ExpandedView: View {
    let model: NotchViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let info = model.info {
                header(info)
                if info.clock.hasDuration {
                    ProgressRow(
                        clock: info.clock,
                        scrubPosition: model.scrubPosition,
                        onScrub: model.scrub(to:),
                        onScrubEnd: model.endScrub
                    )
                }
            } else {
                Text(L10n.infoUnavailable)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity, minHeight: NotchLayout.expandedArtworkSide)
            }
            ControlsRow(
                isPlaying: model.info?.clock.isPlaying,
                onPrevious: model.previous,
                onTogglePlayPause: model.togglePlayPause,
                onNext: model.next
            )
            VolumeRow(volume: model.volume, isEnabled: model.isVolumeSettable, onChange: model.setVolume)
        }
        .padding(.top, model.notchSize.height + 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func header(_ info: NowPlayingInfo) -> some View {
        HStack(spacing: 12) {
            ArtworkView(image: model.artworkImage, version: model.artworkVersion, cornerRadius: NotchLayout.expandedArtworkRadius)
                .frame(width: NotchLayout.expandedArtworkSide, height: NotchLayout.expandedArtworkSide)
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let artist = info.artist {
                    Text(artist)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let icon = model.sourceAppIcon {
                Button(action: model.openSourceApp) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(L10n.openSourceApp)
                .accessibilityLabel(L10n.openSourceApp)
            }
        }
    }
}
