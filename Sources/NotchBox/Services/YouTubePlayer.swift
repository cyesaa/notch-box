import AppKit
import NotchBoxCore
import os
import WebKit

/// A YouTube video in a `WKWebView`, through the official IFrame Player API.
/// The page is loaded with an https base URL (YouTube refuses embeds without a referrer: error 152/153);
/// `notchbox.invalid` is a reserved name, so nothing is ever fetched from it.
@MainActor
final class YouTubePlayer: NSObject {
    static let baseURL = URL(string: "https://notchbox.invalid/")!

    let webView: WKWebView
    /// Called with the player's error code (for example 101 or 150: embedding disabled by the owner).
    var onError: ((Int) -> Void)?

    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "video")

    init(videoID: String, start: TimeInterval) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = FirstMouseWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(MessageProxy(owner: self), name: "notchbox")
        webView.underPageBackgroundColor = .black
        webView.loadHTMLString(Self.page(videoID: videoID, start: start), baseURL: Self.baseURL)
    }

    /// The playback position, or nil when the player cannot tell.
    func currentTime(completion: @escaping @MainActor (TimeInterval?) -> Void) {
        webView.evaluateJavaScript("player && player.getCurrentTime ? player.getCurrentTime() : null") { result, _ in
            MainActor.assumeIsolated { completion(result as? Double) }
        }
    }

    /// Stops playback and unloads the page so nothing keeps playing in the background.
    func stop() {
        webView.evaluateJavaScript("player && player.stopVideo && player.stopVideo()")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "notchbox")
        webView.loadHTMLString("", baseURL: nil)
    }

    fileprivate func received(_ message: String) {
        if message == "ready" {
            logger.info("YouTube player ready")
            play()
        } else if message.hasPrefix("error:"), let code = Int(message.dropFirst("error:".count)) {
            logger.error("YouTube player error \(code)")
            onError?(code)
        }
    }

    /// Calls from the app count as a user gesture, so sound is usually allowed. If playback still has
    /// not started, start muted; YouTube's own button then turns the sound on.
    private func play() {
        webView.evaluateJavaScript("player.playVideo()")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.webView.evaluateJavaScript("player.getPlayerState() === 1 ? 'playing' : (player.mute(), player.playVideo(), 'muted')") { result, _ in
                MainActor.assumeIsolated {
                    self?.logger.info("YouTube player started: \(String(describing: result ?? "unknown"), privacy: .public)")
                }
            }
        }
    }

    private static func page(videoID: String, start: TimeInterval) -> String {
        let seconds = max(0, Int(start))
        return """
        <!doctype html>
        <html><head><meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#player{position:absolute;inset:0}</style>
        </head><body><div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function send(message) { window.webkit.messageHandlers.notchbox.postMessage(message); }
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: '100%', height: '100%', videoId: '\(videoID)',
            playerVars: { autoplay: 1, start: \(seconds), playsinline: 1, rel: 0, fs: 0, origin: '\(baseURL.absoluteString.dropLast())' },
            events: {
              onReady: function () { send('ready'); },
              onError: function (event) { send('error:' + event.data); }
            }
          });
        }
        </script></body></html>
        """
    }
}

/// The notch panel is never key, so the first click must reach the player's own controls directly.
private final class FirstMouseWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// `WKUserContentController` keeps its handlers alive; the proxy keeps the player from leaking.
private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: YouTubePlayer?

    init(owner: YouTubePlayer) {
        self.owner = owner
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        MainActor.assumeIsolated { owner?.received(text) }
    }
}
