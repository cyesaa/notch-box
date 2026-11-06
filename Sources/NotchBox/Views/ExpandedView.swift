import NotchBoxCore
import SwiftUI

/// Full player. The cover's colour pools around it and tints the progress bar and waveform.
/// In degraded mode (no info) the header explains that the buttons send media keys.
struct ExpandedView: View {
    let model: NotchViewModel

    private static let horizontalPadding: CGFloat = 26
    private static let gapBelowNotch: CGFloat = 10

    var body: some View {
        let accent = Color(model.accent)
        VStack(spacing: 0) {
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
        .padding(.top, model.notchSize.height + Self.gapBelowNotch)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.bottom, 14)
        .background {
            if model.artworkImage != nil {
                glow(accent: accent)
            }
        }
    }

    private func header(_ info: NowPlayingInfo, accent: Color) -> some View {
        HStack(spacing: 14) {
            ArtworkView(image: model.artworkImage, version: model.artworkVersion, cornerRadius: NotchLayout.expandedArtworkRadius)
                .frame(width: NotchLayout.expandedArtworkSide, height: NotchLayout.expandedArtworkSide)
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
            WaveformView(isPlaying: info.clock.isPlaying, tint: accent, barCount: 4, meter: model.audioMeter)
                .frame(width: 18, height: 16)
        }
        .frame(height: NotchLayout.expandedArtworkSide)
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

    /// Volume on the left, transport in the middle, the playing app on the right.
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
                if let icon = model.sourceAppIcon {
                    Button(action: model.openSourceApp) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .help(L10n.openSourceApp)
                    .accessibilityLabel(L10n.openSourceApp)
                }
            }
        }
        .frame(height: 36)
    }

    /// Light from the cover, kept out of the strip under the hardware notch so the notch stays solid black.
    private func glow(accent: Color) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let notchHeight = model.notchSize.height
            let center = CGPoint(
                x: Self.horizontalPadding + NotchLayout.expandedArtworkSide / 2,
                y: notchHeight + Self.gapBelowNotch + NotchLayout.expandedArtworkSide / 2
            )
            RadialGradient(
                colors: [accent.opacity(0.5), accent.opacity(0.14), accent.opacity(0)],
                center: UnitPoint(x: center.x / max(size.width, 1), y: center.y / max(size.height, 1)),
                startRadius: 0,
                endRadius: 120
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: notchHeight / max(size.height, 1)),
                        .init(color: .black, location: min(1, (notchHeight + 28) / max(size.height, 1))),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .allowsHitTesting(false)
    }
}
