import SwiftUI

/// Hovered with nothing playing: what is going on and what to do about it.
struct NothingPlayingView: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchTheme.tile)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchTheme.secondaryText)
                )
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.nothingPlaying)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotchTheme.primaryText)
                Text(L10n.nothingPlayingHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchTheme.secondaryText)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
