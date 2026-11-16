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
    static var videoUnavailable: String { string("video_unavailable") }
    static var signInToYouTube: String { string("sign_in_to_youtube") }
    static var signInTitle: String { string("sign_in_title") }
    static var clipboardTitle: String { string("clipboard_title") }
    static var clipboardEmpty: String { string("clipboard_empty") }
    static var clipboardDenied: String { string("clipboard_denied") }
    static var clipboardClear: String { string("clipboard_clear") }
    static var clipboardCopy: String { string("clipboard_copy") }
    static var clipboardRemove: String { string("clipboard_remove") }
    static var clipboardImage: String { string("clipboard_image") }
    static var clipboardCopied: String { string("clipboard_copied") }
    static var clipboardView: String { string("clipboard_view") }
    static var clipboardPin: String { string("clipboard_pin") }
    static var clipboardUnpin: String { string("clipboard_unpin") }
    static var clipboardPinsFull: String { string("clipboard_pins_full") }
    static var vpnTitle: String { string("vpn_title") }
    static var vpnConnected: String { string("vpn_connected") }
    static var vpnConnecting: String { string("vpn_connecting") }
    static var vpnDisconnecting: String { string("vpn_disconnecting") }
    static var vpnDisconnected: String { string("vpn_disconnected") }
    static var vpnUnavailable: String { string("vpn_unavailable") }
    static var vpnDisconnect: String { string("vpn_disconnect") }
    static var vpnConnectInFortiClient: String { string("vpn_connect_in_forticlient") }
    static var vpnConnectInSettings: String { string("vpn_connect_in_settings") }
    static var vpnOpenFortiClient: String { string("vpn_open_forticlient") }
    static var vpnOpenSettings: String { string("vpn_open_settings") }
    static var vpnNone: String { string("vpn_none") }
    static var vpnConnect: String { string("vpn_connect") }
    static var vpnAccessibilityNeeded: String { string("vpn_accessibility_needed") }
    static var vpnDisconnectShort: String { string("vpn_disconnect_short") }
    static var vpnChooseProfile: String { string("vpn_choose_profile") }
    static var vpnOpenOpenVPN: String { string("vpn_open_openvpn") }
    static var vpnOpenShort: String { string("vpn_open_short") }
    static var settingsMenuItem: String { string("settings_menu_item") }
    static var settingsTitle: String { string("settings_title") }
    static var settingsSidesHeader: String { string("settings_sides_header") }
    static var settingsSidesFooter: String { string("settings_sides_footer") }
    static var settingsLeft: String { string("settings_left") }
    static var settingsRight: String { string("settings_right") }
    static var settingsBottomLeft: String { string("settings_bottom_left") }
    static var settingsBottom: String { string("settings_bottom") }
    static var settingsBottomRight: String { string("settings_bottom_right") }
    static var settingsNone: String { string("settings_none") }
    static var settingsPlayer: String { string("settings_player") }
    static var settingsNotchHeader: String { string("settings_notch_header") }
    static var settingsGeneralHeader: String { string("settings_general_header") }
    static func settingsVersion(_ version: String) -> String { String(format: string("settings_version"), version) }
    static var showWithoutNotch: String { string("show_without_notch") }
    static var hideIdleVirtualNotch: String { string("hide_idle_virtual_notch") }
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
    static var cancel: String { string("cancel") }
    static var authTitle: String { string("auth_title") }
    static var authEmpty: String { string("auth_empty") }
    static var authImportShort: String { string("auth_import_short") }
    static var authCopy: String { string("auth_copy") }
    static var authCopied: String { string("auth_copied") }
    static var authHide: String { string("auth_hide") }
    static var authNextAccount: String { string("auth_next_account") }
    static func authPin(_ site: String) -> String { String(format: string("auth_pin"), site) }
    static func authUnpin(_ site: String) -> String { String(format: string("auth_unpin"), site) }
    static var authManage: String { string("auth_manage") }
    static var authUnreadable: String { string("auth_unreadable") }
    static var authUnreadableHint: String { string("auth_unreadable_hint") }
    static var authRetry: String { string("auth_retry") }
    static var settingsAuthHeader: String { string("settings_auth_header") }
    static var settingsAuthFooter: String { string("settings_auth_footer") }
    static var authShowOnSignIn: String { string("auth_show_on_sign_in") }
    static func authAccountCount(_ count: Int) -> String { counted("auth_account_count", count) }
    static var authManageButton: String { string("auth_manage_button") }
    static var authWindowTitle: String { string("auth_window_title") }
    static var authWindowIntro: String { string("auth_window_intro") }
    static var authWindowEmptyTitle: String { string("auth_window_empty_title") }
    static var authWindowEmptyText: String { string("auth_window_empty_text") }
    static var authImportButton: String { string("auth_import_button") }
    static var authDelete: String { string("auth_delete") }
    static func authDeleteTitle(_ name: String) -> String { String(format: string("auth_delete_title"), name) }
    static var authDeleteText: String { string("auth_delete_text") }
    static var authScanTitle: String { string("auth_scan_title") }
    static var authScanStep1: String { string("auth_scan_step1") }
    static var authScanStep2: String { string("auth_scan_step2") }
    static var authScanStep3: String { string("auth_scan_step3") }
    static var authScanLooking: String { string("auth_scan_looking") }
    static var authScanHint: String { string("auth_scan_hint") }
    static func authScanFound(_ count: Int) -> String { counted("auth_scan_found", count) }
    static func authScanMore(_ done: Int, _ total: Int) -> String { String(format: string("auth_scan_more"), done, total) }
    static var authScanNotACode: String { string("auth_scan_not_a_code") }
    static func authScanUnsupported(_ count: Int) -> String { counted("auth_scan_unsupported", count) }
    static func authScanAdd(_ count: Int) -> String { counted("auth_scan_add", count) }
    static var authCameraDenied: String { string("auth_camera_denied") }
    static var authCameraOpenSettings: String { string("auth_camera_open_settings") }
    static var authCameraMissing: String { string("auth_camera_missing") }
    static func authAdded(_ count: Int) -> String { counted("auth_added", count) }
    static var authAddedNone: String { string("auth_added_none") }
    static var authSaveFailed: String { string("auth_save_failed") }
    static var authUnlockReason: String { string("auth_unlock_reason") }

    /// "<key>_none" for 0 (when there is one), "<key>_one" for 1, "<key>_other" with the number otherwise.
    private static func counted(_ key: String, _ count: Int) -> String {
        if count == 0 {
            let none = string(key + "_none")
            if none != key + "_none" { return none }
        }
        return count == 1 ? string(key + "_one") : String(format: string(key + "_other"), count)
    }

    private static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
