import NotchBoxCore
import SwiftUI
import WebKit

/// A browser's YouTube video playing in the notch: a bar with the source, title and buttons, and a
/// 16:9 player below it. The notch stays open until the video is closed.
struct VideoView: View {
    let model: NotchViewModel

    var body: some View {
        let notch = model.notchSize
        let player = NotchLayout.videoPlayerSize(notch: notch)
        VStack(spacing: NotchLayout.videoGap) {
            bar
                .frame(height: NotchLayout.videoBarHeight)
            playerArea
                .frame(width: player.width, height: player.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, notch.height + NotchLayout.videoGap)
        .padding(.horizontal, NotchLayout.videoPadding)
        .padding(.bottom, NotchLayout.videoPadding)
    }

    private var bar: some View {
        HStack(spacing: 10) {
            if let session = model.video, let icon = AppIconProvider.icon(for: session.sourceBundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            Text(model.video?.title ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            BarButton(systemName: "arrow.up.forward.app", label: L10n.continueInBrowser) {
                model.closeVideo(resumeInBrowser: true)
            }
            BarButton(systemName: "xmark", label: L10n.closeVideo) {
                model.closeVideo(resumeInBrowser: false)
            }
        }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let player = model.videoPlayer {
            WebViewHost(webView: player.webView)
        } else {
            ZStack {
                Color(white: 0.08)
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(NotchTheme.tertiaryText)
            }
        }
    }
}

private struct BarButton: View {
    let systemName: String
    let label: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NotchTheme.primaryText)
                .frame(width: 28, height: 28)
                .background(Circle().fill(NotchTheme.tile))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Shows an existing `WKWebView` (owned by `YouTubePlayer`) in SwiftUI.
private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
