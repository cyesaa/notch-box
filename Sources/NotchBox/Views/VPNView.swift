import NotchBoxCore
import SwiftUI

/// The VPN column of the open player: FortiClient's (or another system) VPN and OpenVPN Connect, whichever are
/// installed. Each shows whether it is connected and for how long, with a button to disconnect, connect (an
/// OpenVPN profile) or open the app that connects it. One VPN gets the whole column; several get a row each.
struct VPNView: View {
    let model: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: model.notchSize.height)
                .padding(.bottom, 4)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeOut(duration: 0.2), value: model.vpns)
    }

    /// Sits in the band beside the camera.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: NotchWidget.vpn.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.vpnTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            if model.vpns.count == 1, let entry = model.vpns.first {
                Button { model.openApp(for: entry) } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(VPNText.openLabel(entry))
                .accessibilityLabel(VPNText.openLabel(entry))
            }
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private var content: some View {
        if model.vpns.isEmpty {
            Text(L10n.vpnNone)
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
        } else if model.vpns.count == 1, let entry = model.vpns.first {
            VStack(spacing: 10) {
                VPNBadge(status: entry.status, size: 40)
                VStack(spacing: 2) {
                    Text(VPNText.status(entry.status))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotchTheme.primaryText)
                    Text(VPNText.detail(entry, now: model.vpnTime))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(NotchTheme.secondaryText)
                        .lineLimit(1)
                }
                VPNAction(entry: entry, model: model, compact: false)
            }
        } else {
            VStack(spacing: 6) {
                ForEach(model.vpns) { entry in
                    HStack(spacing: 8) {
                        VPNBadge(status: entry.status, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(NotchTheme.primaryText)
                            Text(VPNText.rowDetail(entry, now: model.vpnTime))
                                .font(.system(size: 10.5))
                                .monospacedDigit()
                                .foregroundStyle(NotchTheme.secondaryText)
                        }
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VPNAction(entry: entry, model: model, compact: true)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(entry.status == .connected ? Color.white.opacity(0.14) : NotchTheme.tile)
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The lock in a tinted circle.
private struct VPNBadge: View {
    let status: VPNStatus
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(VPNText.tint(status).opacity(0.18))
                .frame(width: size, height: size)
            Image(systemName: status == .connected ? "lock.fill" : "lock.open.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(VPNText.tint(status))
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityHidden(true)
    }
}

/// Disconnect while connected; otherwise connect an OpenVPN profile (a menu when there are several) or
/// open the app that connects the VPN.
private struct VPNAction: View {
    let entry: NotchViewModel.VPNEntry
    let model: NotchViewModel
    let compact: Bool

    var body: some View {
        switch entry.status {
        case .connected, .connecting:
            capsule(compact ? L10n.vpnDisconnectShort : L10n.vpnDisconnect, fill: Color(red: 1, green: 0.36, blue: 0.36), text: .white) { model.disconnect(entry) }
        case .disconnecting:
            EmptyView()
        case .disconnected, .unavailable:
            if case .openVPN = entry.kind, !entry.profiles.isEmpty {
                if entry.profiles.count == 1, let profile = entry.profiles.first {
                    capsule(L10n.vpnConnect, fill: Color.white.opacity(0.16), text: NotchTheme.primaryText) { model.connect(profile) }
                } else {
                    Menu {
                        ForEach(entry.profiles) { profile in
                            Button(profile.shortName) { model.connect(profile) }
                        }
                    } label: {
                        capsuleLabel(L10n.vpnConnect + " ▾", fill: Color.white.opacity(0.16), text: NotchTheme.primaryText)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(L10n.vpnChooseProfile)
                }
            } else {
                capsule(compact ? L10n.vpnOpenShort : VPNText.connectLabel(entry), fill: Color.white.opacity(0.16), text: NotchTheme.primaryText) {
                    model.openApp(for: entry)
                }
            }
        }
    }

    private func capsule(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { capsuleLabel(title, fill: fill, text: text) }
            .buttonStyle(PressableButtonStyle())
    }

    private func capsuleLabel(_ title: String, fill: Color, text: Color) -> some View {
        Text(title)
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, compact ? 9 : 14)
            .frame(height: compact ? 22 : 26)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
    }
}

/// Words and colours for VPN states.
private enum VPNText {
    static func tint(_ status: VPNStatus) -> Color {
        switch status {
        case .connected: return Color(red: 0.36, green: 0.84, blue: 0.48)
        case .connecting, .disconnecting: return Color(red: 1, green: 0.78, blue: 0.3)
        case .disconnected, .unavailable: return NotchTheme.secondaryText
        }
    }

    static func status(_ status: VPNStatus) -> String {
        switch status {
        case .connected: return L10n.vpnConnected
        case .connecting: return L10n.vpnConnecting
        case .disconnecting: return L10n.vpnDisconnecting
        case .disconnected: return L10n.vpnDisconnected
        case .unavailable: return L10n.vpnUnavailable
        }
    }

    /// "FortiClient VPN · 1:05:12" / "OpenVPN · fatmavpn · 0:12:04" while connected, the name otherwise.
    static func detail(_ entry: NotchViewModel.VPNEntry, now: Date) -> String {
        var parts = [entry.name]
        if let profile = entry.activeProfile { parts.append(profile.shortName) }
        if entry.status == .connected, let since = entry.connectedSince {
            parts.append(TimeFormatter.string(from: now.timeIntervalSince(since)))
        }
        return parts.joined(separator: " · ")
    }

    /// In a row, under the name: "fatmavpn · 0:12:04" while connected (the green lock says connected),
    /// the state otherwise.
    static func rowDetail(_ entry: NotchViewModel.VPNEntry, now: Date) -> String {
        guard entry.status == .connected else { return status(entry.status) }
        var parts: [String] = []
        if let profile = entry.activeProfile { parts.append(profile.shortName) }
        if let since = entry.connectedSince { parts.append(TimeFormatter.string(from: now.timeIntervalSince(since))) }
        return parts.isEmpty ? status(entry.status) : parts.joined(separator: " · ")
    }

    static func openLabel(_ entry: NotchViewModel.VPNEntry) -> String {
        switch entry.kind {
        case .openVPN: return L10n.vpnOpenOpenVPN
        case .system: return entry.isFortiClient ? L10n.vpnOpenFortiClient : L10n.vpnOpenSettings
        }
    }

    static func connectLabel(_ entry: NotchViewModel.VPNEntry) -> String {
        switch entry.kind {
        case .openVPN: return L10n.vpnOpenOpenVPN
        case .system: return entry.isFortiClient ? L10n.vpnConnectInFortiClient : L10n.vpnConnectInSettings
        }
    }
}
