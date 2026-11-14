import NotchBoxCore
import SwiftUI
import WebKit

/// A browser's YouTube video playing in the notch: the source browser's icon left of the notch, a close
/// button right of it, and a 16:9 player just below. The notch stays open until the video is closed.
/// Under a cursor that came in from the side or below, everything but the close button fades away and
/// clicks go to the windows behind; coming down from the menu bar keeps it usable (see `NotchInteraction`).
struct VideoView: View {
    let model: NotchViewModel

    /// How much of the panel shows while it is see-through.
    static let seeThroughOpacity = 0.15

    var body: some View {
        let notch = model.notchSize
        let player = NotchLayout.videoPlayerSize(notch: notch)
        VStack(spacing: NotchLayout.videoGap) {
            bar
                .frame(height: notch.height)
            playerArea
                .frame(width: player.width, height: player.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, NotchLayout.videoPadding)
        .padding(.bottom, NotchLayout.videoPadding)
    }

    private var fade: Double { model.isSeeThrough ? Self.seeThroughOpacity : 1 }

    /// The band beside the notch: the camera sits in the middle of it.
    private var bar: some View {
        HStack(spacing: 10) {
            if let session = model.video, let icon = AppIconProvider.icon(for: session.sourceBundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .opacity(fade)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            if model.videoNeedsSignIn {
                SignInButton(label: L10n.signInToYouTube, action: model.signInToYouTube)
                    .opacity(fade)
            }
            CloseButton(label: L10n.closeVideo, action: model.closeVideo)
        }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let player = model.videoPlayer {
            WebViewHost(webView: player.webView, alpha: fade)
        } else {
            ZStack {
                Color(white: 0.08)
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(NotchTheme.tertiaryText)
            }
            .opacity(fade)
        }
    }
}

/// Stays fully visible and is the only thing that takes clicks while the panel is see-through,
/// so it has its own dark disc. Its frame must match `NotchLayout.videoCloseButtonFrame`.
private struct CloseButton: View {
    let label: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NotchTheme.primaryText)
                .frame(width: NotchLayout.videoCloseButtonSide, height: NotchLayout.videoCloseButtonSide)
                .background(Circle().fill(Color(white: 0.16)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Offered beside the close button while the notch's YouTube page is signed out. Signing in uses the
/// user's own account, so a YouTube Premium account plays without ads.
private struct SignInButton: View {
    let label: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(NotchTheme.primaryText)
            .padding(.horizontal, 9)
            .frame(height: NotchLayout.videoCloseButtonSide)
            .background(Capsule().fill(Color(white: 0.16)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Shows an existing `WKWebView` (owned by `YouTubePlayer`) in SwiftUI. The fade is applied to the
/// AppKit view itself, which SwiftUI's opacity does not reliably reach.
private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView
    let alpha: Double

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard abs(nsView.alphaValue - alpha) > 0.001 else { return }
        NSAnimationContext.runAnimationGroup { animation in
            animation.duration = 0.18
            nsView.animator().alphaValue = alpha
        }
    }
}
