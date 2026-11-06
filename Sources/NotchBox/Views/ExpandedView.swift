import NotchBoxCore
import SwiftUI

/// Full player. The band beside the notch holds the playing app (left) and the waveform (right); the
/// player hangs right below the notch. The cover's colour tints a small shadow around it, the progress
/// bar and the waveform. In degraded mode (no info) the header explains that the buttons send media keys.
struct ExpandedView: View {
    let model: NotchViewModel

    private static let horizontalPadding: CGFloat = 26
    private static let gapBelowNotch: CGFloat = 4

    var body: some View {
        let accent = Color(model.accent)
        VStack(spacing: 0) {
            notchBand(accent: accent)
                .frame(height: model.notchSize.height)
                .padding(.bottom, Self.gapBelowNotch)
            if let info = model.info {
                header(info, accent: accent)
                Spacer(minLength: 12)
                if let message = model.videoMessage {
                    Text(message)
                        .font(NotchTheme.detailFont)
                        .foregroundStyle(NotchTheme.secondaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 14)
                    Spacer(minLength: 10)
                } else if info.clock.hasDuration {
                    ProgressRow(
                        clock: info.clock,
                        scrubPosition: model.scrubPosition,
                        tint: accent,
                        onScrub: model.scrub(to:),
                        onScrubEnd: model.endScrub
                    )
                    Spacer(minLength: 10)
                }
            } else {
                unavailableHeader
                Spacer(minLength: 12)
            }
            bottomRow
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.bottom, 14)
    }

    private func header(_ info: NowPlayingInfo, accent: Color) -> some View {
        HStack(spacing: 14) {
            ArtworkView(image: model.artworkImage, version: model.artworkVersion, cornerRadius: NotchLayout.expandedArtworkRadius)
                .frame(width: NotchLayout.expandedArtworkSide, height: NotchLayout.expandedArtworkSide)
                // A small shadow in the cover's colour, just around the artwork.
                .shadow(color: model.artworkImage == nil ? .clear : accent.opacity(0.45), radius: 6, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(NotchTheme.titleFont)
                    .foregroundStyle(NotchTheme.primaryText)
                if let artist = info.artist {
                    Text(artist)
                        .font(NotchTheme.subtitleFont)
                        .foregroundStyle(NotchTheme.secondaryText)
                }
                if let album = info.album {
                    Text(album)
                        .font(NotchTheme.detailFont)
                        .foregroundStyle(NotchTheme.tertiaryText)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: NotchLayout.expandedArtworkSide)
    }

    /// Left and right of the camera: the playing app, and the waveform while something plays.
    private func notchBand(accent: Color) -> some View {
        HStack {
            if let icon = model.sourceAppIcon {
                Button(action: model.openSourceApp) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(L10n.openSourceApp)
                .accessibilityLabel(L10n.openSourceApp)
            }
            Spacer(minLength: 0)
            if let info = model.info {
                WaveformView(isPlaying: info.clock.isPlaying, tint: accent, barCount: 4, meter: model.audioMeter)
                    .frame(width: 18, height: 14)
            }
        }
    }

    private var unavailableHeader: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: NotchLayout.expandedArtworkRadius, style: .continuous)
                .fill(NotchTheme.tile)
                .overlay(
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(NotchTheme.secondaryText)
                )
                .frame(width: NotchLayout.expandedArtworkSide, height: NotchLayout.expandedArtworkSide)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.infoUnavailable)
                    .font(NotchTheme.titleFont)
                    .foregroundStyle(NotchTheme.primaryText)
                Text(L10n.mediaKeysHint)
                    .font(NotchTheme.subtitleFont)
                    .foregroundStyle(NotchTheme.secondaryText)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: NotchLayout.expandedArtworkSide)
    }

    /// Volume on the left, transport in the middle, "watch in the notch" on the right.
    private var bottomRow: some View {
        ZStack {
            ControlsRow(
                isPlaying: model.info?.clock.isPlaying,
                onPrevious: model.previous,
                onTogglePlayPause: model.togglePlayPause,
                onNext: model.next
            )
            HStack {
                VolumeRow(volume: model.volume, isEnabled: model.isVolumeSettable, onChange: model.setVolume)
                Spacer()
                if model.canWatchInNotch {
                    Button(action: model.watchInNotch) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NotchTheme.primaryText)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .opacity(model.isFindingVideo ? 0.4 : 1)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(model.isFindingVideo)
                    .help(L10n.watchInNotch)
                    .accessibilityLabel(L10n.watchInNotch)
                }
            }
        }
        .frame(height: 36)
    }
}
