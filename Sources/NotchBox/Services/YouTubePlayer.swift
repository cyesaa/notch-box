import AppKit
import NotchBoxCore
import os
import WebKit

/// A YouTube video in a `WKWebView`, through the official IFrame Player API.
/// The page is loaded with an https base URL (YouTube refuses embeds without a referrer: error 152/153);
/// `notchbox.invalid` is a reserved name, so nothing is ever fetched from it.
/// When the video's owner turned embedding off, the player opens the video's own YouTube page instead and
/// shows only its player (see `watchPageScript`).
@MainActor
final class YouTubePlayer: NSObject {
    static let baseURL = URL(string: "https://notchbox.invalid/")!
    /// YouTube often swaps the video source right after a refused play() (between an ad and the video);
    /// asking again a moment later reaches the new source.
    static let retryDelay: TimeInterval = 0.3

    let webView: WKWebView
    /// Called with the player's error code when the video cannot play here at all (for example 100: removed
    /// or private). Embedding refusals (101/150) open the video's YouTube page instead.
    var onError: ((Int) -> Void)?
    /// On the video's YouTube page, whether the user is signed out (so they can sign in to their own account;
    /// a YouTube Premium account then plays without ads). Always false while the embedded player is showing.
    var onNeedsSignIn: ((Bool) -> Void)?

    private let videoID: String
    private let start: TimeInterval
    /// True once the video's YouTube page replaced the embedded player.
    private var showsWatchPage = false
    private var autoplay = WatchPageAutoplay()
    private var retryPending = false
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "video")

    init(videoID: String, start: TimeInterval) {
        self.videoID = videoID
        self.start = start
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // YouTube's own pages expect Safari's full user agent, not WebKit's bare one.
        configuration.applicationNameForUserAgent = SafariUserAgent.applicationName
        // In every YouTube frame: the embedded player's iframe and, later, the video's own page.
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.captionsOffScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        webView = FirstMouseWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(MessageProxy(owner: self), name: "notchbox")
        webView.underPageBackgroundColor = .black
        webView.loadHTMLString(Self.page(videoID: videoID, start: start), baseURL: Self.baseURL)
    }

    /// The playback position, or nil when the player cannot tell.
    func currentTime(completion: @escaping @MainActor (TimeInterval?) -> Void) {
        // On the watch page, YouTube may have moved on to another video (its autoplay, or a click).
        let script = showsWatchPage
            ? "(function () { var p = document.getElementById('movie_player'); return p && p.getCurrentTime && new URLSearchParams(location.search).get('v') === '\(videoID)' ? p.getCurrentTime() : null; })()"
            : "player && player.getCurrentTime ? player.getCurrentTime() : null"
        webView.evaluateJavaScript(script) { result, _ in
            MainActor.assumeIsolated { completion(result as? Double) }
        }
    }

    /// Stops playback and unloads the page so nothing keeps playing in the background.
    func stop() {
        webView.evaluateJavaScript(showsWatchPage
            ? "document.querySelectorAll('video').forEach(function (video) { video.pause(); })"
            : "player && player.stopVideo && player.stopVideo()")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "notchbox")
        webView.loadHTMLString("", baseURL: nil)
    }

    fileprivate func received(_ message: String) {
        switch message {
        case "ready":
            logger.info("YouTube player ready")
            play()
        case "blocked":
            playRefused()
        case "playing":
            autoplay.started()
        case "signin:in":
            onNeedsSignIn?(false)
        case "signin:out":
            onNeedsSignIn?(true)
        default:
            guard message.hasPrefix("error:"), let code = Int(message.dropFirst("error:".count)) else { return }
            logger.error("YouTube player error \(code)")
            if !showsWatchPage, YouTubeLink.isEmbeddingRefused(errorCode: code) {
                openWatchPage()
            } else {
                onError?(code)
            }
        }
    }

    /// Reloads the video's YouTube page from where it is now, so a sign-in just made in a separate window
    /// takes effect (a Premium account then plays without ads).
    func reloadWatchPage() {
        guard showsWatchPage else { return }
        currentTime { [weak self] time in
            guard let self else { return }
            self.autoplay = WatchPageAutoplay()
            self.webView.load(URLRequest(url: YouTubeLink.watchPageURL(videoID: self.videoID, start: time ?? self.start)))
        }
    }

    /// Calls from the app count as a user gesture, so sound is usually allowed. If playback still has
    /// not started, start muted; YouTube's own button then turns the sound on.
    private func play() {
        webView.evaluateJavaScript("player.playVideo()")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.showsWatchPage else { return }
                self.webView.evaluateJavaScript("player.getPlayerState() === 1 ? 'playing' : (player.mute(), player.playVideo(), 'muted')") { result, _ in
                    MainActor.assumeIsolated {
                        self.logger.info("YouTube player started: \(String(describing: result ?? "unknown"), privacy: .public)")
                    }
                }
            }
        }
    }

    private func openWatchPage() {
        logger.notice("Embedding refused; opening the video's YouTube page")
        showsWatchPage = true
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: Self.watchPageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView.load(URLRequest(url: YouTubeLink.watchPageURL(videoID: videoID, start: start)))
    }

    /// WebKit refused one of the watch page's own play() calls; ask the player to play from the app.
    private func playRefused() {
        guard showsWatchPage, !retryPending else { return }
        let request = autoplay.refused()
        guard request != .giveUp else {
            logger.error("YouTube page does not start playing; leaving it to the user")
            return
        }
        retryPending = true
        let mute = request == .playMuted ? "p.mute(); " : ""
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.retryPending = false
                self.webView.evaluateJavaScript("(function () { var p = document.getElementById('movie_player'); if (p && p.playVideo) { \(mute)p.playVideo(); } })()")
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

    /// Runs in every YouTube frame (the embedded player's iframe, and the video's own page) and keeps
    /// captions off, which YouTube otherwise often turns on by itself (auto-generated or a remembered
    /// choice). It works through the player inside the frame: the IFrame API's caption options from the
    /// outer page do not take effect. Once the user presses the CC button, opens the player's settings
    /// or presses "c", it leaves captions to them.
    private static let captionsOffScript = """
    (function () {
      if (window.notchboxCaptions || !/(^|\\.)youtube(-nocookie)?\\.com$/.test(location.hostname)) return;
      window.notchboxCaptions = true;
      var userChose = false;
      // The video page has the desktop controls (.ytp-…); the embedded player draws mobile-style ones (ytm…).
      var captionControls = '.ytp-subtitles-button, .ytp-settings-button, .ytp-settings-menu, '
        + '[class*="ClosedCaptioning"], [class*="Settings"], [class*="settings"]';
      document.addEventListener('click', function (event) {
        if (event.target.closest && event.target.closest(captionControls)) userChose = true;
      }, true);
      document.addEventListener('keydown', function (event) {
        if (event.key === 'c' || event.key === 'C') userChose = true;
      }, true);
      setInterval(function () {
        if (userChose) return;
        var p = document.getElementById('movie_player');
        if (p && p.isSubtitlesOn && p.isSubtitlesOn() && p.setOption) p.setOption('captions', 'track', {});
      }, 1000);
    })();
    """

    /// Runs on the video's youtube.com page before YouTube's own scripts. It leaves only the player,
    /// filling the panel, with YouTube's controls. WebKit refuses the page's own play() calls (no click led
    /// to them), so it reports each refusal for the video that was opened and the app asks the player to
    /// play (`WatchPageAutoplay`); another video started by YouTube's autoplay is left paused.
    private static let watchPageScript = """
    (function () {
      if (window.notchboxWatchPage || !/(^|\\.)youtube\\.com$/.test(location.hostname)) return;
      window.notchboxWatchPage = true;
      function send(message) { window.webkit.messageHandlers.notchbox.postMessage(message); }
      function currentVideo() { return new URLSearchParams(location.search).get('v'); }
      var openedVideo = currentVideo();

      var style = document.createElement('style');
      style.textContent = [
        'html, body { margin: 0 !important; overflow: hidden !important; background: #000 !important; }',
        '#masthead-container, #secondary, #below, #chat, #guide, tp-yt-app-drawer, ytd-popup-container,',
        'ytd-mealbar-promo-renderer, tp-yt-iron-overlay-backdrop { display: none !important; }',
        '#movie_player { position: fixed !important; inset: 0 !important; width: 100vw !important;',
        '  height: 100vh !important; z-index: 2147483647 !important; background: #000 !important; }',
        // YouTube sizes the video's container from its own layout pass, which leaves it 0 px tall here:
        // the sound plays and the controls draw, but the picture is invisible. Pin it to the player.
        '#movie_player .html5-video-container { position: absolute !important; inset: 0 !important;',
        '  width: 100% !important; height: 100% !important; }',
        '#movie_player video { position: absolute !important; left: 0 !important; top: 0 !important;',
        '  width: 100% !important; height: 100% !important; object-fit: contain !important; }'
      ].join('\\n');
      document.documentElement.appendChild(style);

      var play = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function () {
        var result = play.apply(this, arguments);
        if (result && result.catch) {
          result.catch(function (error) {
            if (error && error.name === 'NotAllowedError' && currentVideo() === openedVideo) send('blocked');
          });
        }
        return result;
      };
      document.addEventListener('playing', function () { send('playing'); }, true);

      // The masthead is hidden but still built, so the account button / sign-in link are there to read.
      // They appear a moment after load, so poll for a while and report the state (and any change).
      var reportedSignIn = null;
      function reportSignIn() {
        var state = document.querySelector('#avatar-btn') ? 'in'
          : (document.querySelector('a[href*="accounts.google.com"]') ? 'out' : null);
        if (state && state !== reportedSignIn) { reportedSignIn = state; send('signin:' + state); }
      }
      var signInTries = 0;
      var signInTimer = setInterval(function () {
        reportSignIn();
        if (++signInTries >= 12) clearInterval(signInTimer);
      }, 1500);
    })();
    """
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
