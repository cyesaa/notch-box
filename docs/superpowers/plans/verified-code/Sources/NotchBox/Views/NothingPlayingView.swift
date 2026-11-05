import SwiftUI

struct NothingPlayingView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
            Text(L10n.nothingPlaying)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
