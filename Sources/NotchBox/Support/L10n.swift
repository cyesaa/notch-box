import Foundation

/// User-facing strings. Values live in Resources/<lang>.lproj/Localizable.strings,
/// which bundle.sh copies into the app's Contents/Resources.
enum L10n {
    static var nothingPlaying: String { string("nothing_playing") }
    static var infoUnavailable: String { string("info_unavailable") }
    static var launchAtLogin: String { string("launch_at_login") }
    static var quit: String { string("quit") }
    static var playPause: String { string("play_pause") }
    static var next: String { string("next") }
    static var previous: String { string("previous") }
    static var volume: String { string("volume") }
    static var openSourceApp: String { string("open_source_app") }
    static var position: String { string("position") }
    static var nothingPlayingHint: String { string("nothing_playing_hint") }
    static var mediaKeysHint: String { string("media_keys_hint") }
    static var watchInNotch: String { string("watch_in_notch") }
    static var closeVideo: String { string("close_video") }
    static var noYouTubeVideo: String { string("no_youtube_video") }
    static var browserAccessNeeded: String { string("browser_access_needed") }
    static var videoNotEmbeddable: String { string("video_not_embeddable") }
    static var clipboardTitle: String { string("clipboard_title") }
    static var clipboardEmpty: String { string("clipboard_empty") }
    static var clipboardDenied: String { string("clipboard_denied") }
    static var clipboardClear: String { string("clipboard_clear") }
    static var clipboardCopy: String { string("clipboard_copy") }
    static var clipboardRemove: String { string("clipboard_remove") }
    static var clipboardImage: String { string("clipboard_image") }
    static var clipboardCopied: String { string("clipboard_copied") }
    static var clipboardView: String { string("clipboard_view") }
    static var checkForUpdates: String { string("check_for_updates") }
    static var checkingForUpdates: String { string("checking_for_updates") }
    static var checkAutomatically: String { string("check_automatically") }
    static var updateInstalling: String { string("update_installing") }
    static var updateInstall: String { string("update_install") }
    static var updateReleaseNotes: String { string("update_release_notes") }
    static var updateLater: String { string("update_later") }
    static var updateCheckFailed: String { string("update_check_failed") }
    static var updateCheckFailedHint: String { string("update_check_failed_hint") }
    static var updateInstallFailed: String { string("update_install_failed") }
    static var updateInstallFailedHint: String { string("update_install_failed_hint") }
    static func updateMenuItem(_ version: String) -> String { String(format: string("update_menu_item"), version) }
    static func updateAvailableTitle(_ version: String) -> String { String(format: string("update_available_title"), version) }
    static func updateAvailableInfo(_ version: String) -> String { String(format: string("update_available_info"), version) }
    static func updateUpToDate(_ version: String) -> String { String(format: string("update_up_to_date"), version) }
    static var calendarTitle: String { string("calendar_title") }
    static var calendarAllow: String { string("calendar_allow") }
    static var calendarAllowHint: String { string("calendar_allow_hint") }
    static var calendarDenied: String { string("calendar_denied") }
    static var calendarNothingLeft: String { string("calendar_nothing_left") }
    static var calendarNoEvents: String { string("calendar_no_events") }
    static var calendarAllDay: String { string("calendar_all_day") }
    static var calendarJoin: String { string("calendar_join") }
    static var calendarOpen: String { string("calendar_open") }
    static func calendarNowUntil(_ time: String) -> String { String(format: string("calendar_now_until"), time) }
    static func calendarInMinutes(_ minutes: Int) -> String { String(format: string("calendar_in_minutes"), minutes) }
    static var clipboardClosePreview: String { string("clipboard_close_preview") }

    private static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
