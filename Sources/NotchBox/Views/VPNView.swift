import NotchBoxCore
import SwiftUI

/// The VPN column of the open player: whether the VPN (FortiClient's when there is one) is connected, for how
/// long, and a button to disconnect it or to open the app that connects it.
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
    }

    /// Sits in the band beside the camera.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: NotchWidget.vpn.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.vpnTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            if model.vpnService != nil {
                Button(action: model.openVPNApp) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(openLabel)
                .accessibilityLabel(openLabel)
            }
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private var content: some View {
        if let service = model.vpnService {
            VStack(spacing: 10) {
                statusBadge
                VStack(spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotchTheme.primaryText)
                    Text(detail(service))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(NotchTheme.secondaryText)
                        .lineLimit(1)
                }
                actionButton
            }
            .animation(.easeOut(duration: 0.2), value: model.vpnStatus)
            .accessibilityElement(children: .contain)
        } else {
            Text(L10n.vpnNone)
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 40, height: 40)
            Image(systemName: model.vpnStatus == .connected ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch model.vpnStatus {
        case .connected, .connecting:
            capsuleButton(L10n.vpnDisconnect, fill: Color(red: 1, green: 0.36, blue: 0.36), text: .white, action: model.disconnectVPN)
        case .disconnected, .unavailable:
            capsuleButton(connectLabel, fill: Color.white.opacity(0.16), text: NotchTheme.primaryText, action: model.openVPNApp)
        case .disconnecting:
            EmptyView()
        }
    }

    private func capsuleButton(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(text)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(Capsule().fill(fill))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var tint: Color {
        switch model.vpnStatus {
        case .connected: return Color(red: 0.36, green: 0.84, blue: 0.48)
        case .connecting, .disconnecting: return Color(red: 1, green: 0.78, blue: 0.3)
        case .disconnected, .unavailable: return NotchTheme.secondaryText
        }
    }

    private var statusText: String {
        switch model.vpnStatus {
        case .connected: return L10n.vpnConnected
        case .connecting: return L10n.vpnConnecting
        case .disconnecting: return L10n.vpnDisconnecting
        case .disconnected: return L10n.vpnDisconnected
        case .unavailable: return L10n.vpnUnavailable
        }
    }

    /// "FortiClient VPN · 1:05:12" while connected (when NotchBox saw it come up), the name otherwise.
    private func detail(_ service: VPNServiceInfo) -> String {
        guard model.vpnStatus == .connected, let since = model.vpnConnectedSince else { return service.displayName }
        return "\(service.displayName) · \(TimeFormatter.string(from: model.vpnTime.timeIntervalSince(since)))"
    }

    private var openLabel: String {
        model.vpnService?.isFortiClient == true ? L10n.vpnOpenFortiClient : L10n.vpnOpenSettings
    }

    private var connectLabel: String {
        model.vpnService?.isFortiClient == true ? L10n.vpnConnectInFortiClient : L10n.vpnConnectInSettings
    }
}
