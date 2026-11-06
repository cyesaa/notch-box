import AppKit
import SwiftUI

/// Album art with a placeholder; crossfades when `version` changes.
struct ArtworkView: View {
    let image: NSImage?
    let version: Int
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            Group {
                if let image {
                    // Covers are not always square (video thumbnails are 16:9): fill the square frame
                    // and crop, instead of letting the image grow past it.
                    Color.clear
                        .overlay(
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                } else {
                    GeometryReader { geometry in
                        ZStack {
                            LinearGradient(
                                colors: [Color(white: 0.32), Color(white: 0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "music.note")
                                .font(.system(size: geometry.size.width * 0.4, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                }
            }
            .id(version)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: version)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
