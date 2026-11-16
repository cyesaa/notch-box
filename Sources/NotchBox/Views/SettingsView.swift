import NotchBoxCore
import SwiftUI

/// The Settings window: what sits around the open player, how the notch behaves, and general options.
struct SettingsView: View {
    let settings: AppSettings
    let auth: AuthModel

    var body: some View {
        Form {
            Section {
                SidesPreview(sides: settings.sideWidgets)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                widgetPicker(L10n.settingsLeft, side: .left)
                widgetPicker(L10n.settingsRight, side: .right)
                widgetPicker(L10n.settingsBottomLeft, side: .bottomLeft)
                widgetPicker(L10n.settingsBottom, side: .bottom)
                widgetPicker(L10n.settingsBottomRight, side: .bottomRight)
            } header: {
                Text(L10n.settingsSidesHeader)
            } footer: {
                Text(L10n.settingsSidesFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(L10n.authShowOnSignIn, isOn: Binding(
                    get: { auth.showsOnSignIn },
                    set: { auth.setShowsOnSignIn($0) }
                ))
                HStack {
                    Text(L10n.authAccountCount(auth.entries.count))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.authManageButton) { auth.openManager() }
                }
            } header: {
                Text(L10n.settingsAuthHeader)
            } footer: {
                Text(L10n.settingsAuthFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.settingsNotchHeader) {
                Toggle(L10n.showWithoutNotch, isOn: Binding(
                    get: { settings.showsWithoutNotch },
                    set: { settings.setShowsWithoutNotch($0) }
                ))
                Toggle(L10n.hideIdleVirtualNotch, isOn: Binding(
                    get: { settings.hidesIdleVirtualNotch },
                    set: { settings.setHidesIdleVirtualNotch($0) }
                ))
                .disabled(!settings.showsWithoutNotch)
            }

            Section(L10n.settingsGeneralHeader) {
                Toggle(L10n.launchAtLogin, isOn: Binding(
                    get: { settings.launchesAtLogin },
                    set: { settings.setLaunchesAtLogin($0) }
                ))
                Toggle(L10n.checkAutomatically, isOn: Binding(
                    get: { settings.checksForUpdates },
                    set: { settings.setChecksForUpdates($0) }
                ))
                HStack {
                    Text(L10n.settingsVersion(settings.updates.currentVersion?.description ?? "—"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.checkForUpdates) { settings.updates.check(userInitiated: true) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func widgetPicker(_ title: String, side: SideWidgets.Side) -> some View {
        Picker(title, selection: Binding(
            get: { settings.sideWidgets[side] },
            set: { settings.setWidget($0, on: side) }
        )) {
            Text(L10n.settingsNone).tag(NotchWidget?.none)
            Divider()
            ForEach(NotchWidget.allCases, id: \.self) { widget in
                Label(widget.title, systemImage: widget.symbol).tag(NotchWidget?.some(widget))
            }
        }
    }
}

/// A small drawing of the open player with the widgets chosen around it, so the choice is easy to
/// picture: the player with a place on each side, and the row of three places under it.
private struct SidesPreview: View {
    let sides: SideWidgets

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                column(sides.left)
                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.settingsPlayer)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                column(sides.right)
            }
            HStack(spacing: 6) {
                column(sides.bottomLeft)
                column(sides.bottom)
                column(sides.bottomRight)
            }
        }
        .padding(8)
        .frame(height: 136)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                .fill(Color.black)
        )
        .animation(.easeInOut(duration: 0.2), value: sides)
        .accessibilityHidden(true)
    }

    private func column(_ widget: NotchWidget?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: widget?.symbol ?? "minus")
                .font(.system(size: 13, weight: .semibold))
            Text(widget?.title ?? L10n.settingsNone)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(widget == nil ? Color.white.opacity(0.35) : Color.white.opacity(0.85))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(widget == nil ? 0.04 : 0.1))
        )
    }
}
