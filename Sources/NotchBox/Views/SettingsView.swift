import NotchBoxCore
import Observation
import SwiftUI

/// The parts of the Settings window, one at a time under the stage.
enum SettingsPane: String, CaseIterable, Identifiable {
    case widgets
    case appearance
    case codes
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .widgets: return L10n.settingsPaneWidgets
        case .appearance: return L10n.settingsAppearanceHeader
        case .codes: return L10n.settingsAuthHeader
        case .general: return L10n.settingsGeneralHeader
        }
    }
}

/// Which part of Settings is showing. (A class rather than `@State`: the SwiftUI macros are not in the
/// Command Line Tools this project builds with.)
@MainActor
@Observable
final class SettingsNavigation {
    var pane = SettingsPane.widgets
}

/// The Settings window. On top, the stage: a working model of the notch in the user's own colours, where
/// a click on a place chooses its widget. Under it, one part of the settings at a time. The stage is the
/// one loud thing; everything under it is a plain system form.
struct SettingsView: View {
    let settings: AppSettings
    let auth: AuthModel
    let navigation: SettingsNavigation

    static let width: CGFloat = 620

    var body: some View {
        VStack(spacing: 0) {
            SettingsStage(settings: settings)
            Divider()
            Picker("", selection: Binding(get: { navigation.pane }, set: { navigation.pane = $0 })) {
                ForEach(SettingsPane.allCases) { pane in
                    Text(pane.title).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 14)
            Form {
                switch navigation.pane {
                case .widgets: widgets
                case .appearance: appearance
                case .codes: codes
                case .general: general
                }
            }
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: Self.width)
    }

    // MARK: Widgets

    @ViewBuilder
    private var widgets: some View {
        Section {
            widgetPicker(L10n.settingsLeft, side: .left)
            widgetPicker(L10n.settingsRight, side: .right)
            widgetPicker(L10n.settingsBottomLeft, side: .bottomLeft)
            widgetPicker(L10n.settingsBottom, side: .bottom)
            widgetPicker(L10n.settingsBottomRight, side: .bottomRight)
        } header: {
            Text(L10n.settingsSidesHeader)
        } footer: {
            footnote(L10n.settingsSidesFooter)
        }
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

    // MARK: Appearance

    @ViewBuilder
    private var appearance: some View {
        Section(L10n.appearanceBackground) {
            SwatchRow(
                presets: ColorPreset.backgrounds,
                selected: settings.appearance.background,
                custom: color(\.background),
                select: { picked in change { $0.background = picked } }
            )
            LabeledContent(L10n.appearanceTransparency) {
                HStack(spacing: 10) {
                    Slider(value: Binding(
                        get: { 1 - settings.appearance.backgroundOpacity },
                        set: { transparency in change { $0.backgroundOpacity = min(max(1 - transparency, 0), 1) } }
                    ), in: 0...1)
                    .frame(width: 220)
                    Text(verbatim: "\(Int(((1 - settings.appearance.backgroundOpacity) * 100).rounded())) %")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
            }
            if Self.hasLiquidGlass {
                Toggle(L10n.appearanceGlass, isOn: Binding(
                    get: { settings.appearance.usesGlass },
                    set: { on in
                        change {
                            $0.usesGlass = on
                            // Glass under a solid colour could not be seen.
                            if on, $0.backgroundOpacity > 0.9 { $0.backgroundOpacity = 0.35 }
                        }
                    }
                ))
            }
        }
        Section {
            Picker(L10n.appearanceGlow, selection: Binding(
                get: { settings.appearance.glow },
                set: { glow in change { $0.glow = glow } }
            )) {
                Text(L10n.appearanceGlowOff).tag(NotchAppearance.Glow.off)
                Text(L10n.appearanceGlowArtwork).tag(NotchAppearance.Glow.artwork)
                Text(L10n.appearanceGlowCustom).tag(NotchAppearance.Glow.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if settings.appearance.glow == .custom {
                SwatchRow(
                    presets: ColorPreset.neons,
                    selected: settings.appearance.glowColor,
                    custom: color(\.glowColor),
                    select: { picked in change { $0.glowColor = picked } }
                )
            }
            if settings.appearance.glow != .off {
                Toggle(L10n.appearanceGlowWhenIdle, isOn: Binding(
                    get: { settings.appearance.glowsWhenIdle },
                    set: { on in change { $0.glowsWhenIdle = on } }
                ))
            }
        } header: {
            Text(L10n.appearanceGlow)
        } footer: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                footnote(L10n.settingsAppearanceFooter)
                Spacer(minLength: 0)
                Button(L10n.appearanceReset) { settings.setAppearance(.default) }
                    .disabled(settings.appearance == .default)
            }
        }
    }

    /// Liquid Glass came with macOS 26; on earlier systems the switch is not offered.
    private static var hasLiquidGlass: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    private func change(_ edit: (inout NotchAppearance) -> Void) {
        var appearance = settings.appearance
        edit(&appearance)
        settings.setAppearance(appearance)
    }

    /// One of the appearance's colours, for a colour well.
    private func color(_ keyPath: WritableKeyPath<NotchAppearance, ArtworkColor>) -> Binding<Color> {
        Binding(
            get: { Color(settings.appearance[keyPath: keyPath]) },
            set: { picked in change { $0[keyPath: keyPath] = ArtworkColor(picked) } }
        )
    }

    // MARK: Sign-in codes

    @ViewBuilder
    private var codes: some View {
        Section {
            Toggle(L10n.authShowOnSignIn, isOn: Binding(
                get: { auth.showsOnSignIn },
                set: { auth.setShowsOnSignIn($0) }
            ))
            LabeledContent(L10n.authAccountCount(auth.entries.count)) {
                Button(L10n.authManageButton) { auth.openManager() }
            }
        } footer: {
            footnote(L10n.settingsAuthFooter)
        }
    }

    // MARK: General

    @ViewBuilder
    private var general: some View {
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
        Section {
            Toggle(L10n.launchAtLogin, isOn: Binding(
                get: { settings.launchesAtLogin },
                set: { settings.setLaunchesAtLogin($0) }
            ))
            Toggle(L10n.checkAutomatically, isOn: Binding(
                get: { settings.checksForUpdates },
                set: { settings.setChecksForUpdates($0) }
            ))
            LabeledContent(L10n.settingsVersion(settings.updates.currentVersion?.description ?? "—")) {
                Button(L10n.checkForUpdates) { settings.updates.check(userInitiated: true) }
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A colour offered ready-made, with the name it is read out by.
struct ColorPreset: Identifiable {
    let id: String
    let color: ArtworkColor

    var name: String { L10n.colorName(id) }

    static let backgrounds = [
        ColorPreset(id: "black", color: .black),
        ColorPreset(id: "midnight", color: ArtworkColor(red: 0.06, green: 0.09, blue: 0.30)),
        ColorPreset(id: "purple", color: ArtworkColor(red: 0.25, green: 0.10, blue: 0.42)),
        ColorPreset(id: "burgundy", color: ArtworkColor(red: 0.42, green: 0.06, blue: 0.14)),
        ColorPreset(id: "forest", color: ArtworkColor(red: 0.05, green: 0.25, blue: 0.16)),
        ColorPreset(id: "graphite", color: ArtworkColor(red: 0.20, green: 0.21, blue: 0.24)),
        ColorPreset(id: "cream", color: ArtworkColor(red: 0.96, green: 0.94, blue: 0.88)),
        ColorPreset(id: "white", color: .white),
    ]

    static let neons = [
        ColorPreset(id: "cyan", color: NotchAppearance.defaultGlowColor),
        ColorPreset(id: "pink", color: ArtworkColor(red: 1, green: 0.2, blue: 0.8)),
        ColorPreset(id: "lime", color: ArtworkColor(red: 0.6, green: 1, blue: 0.2)),
        ColorPreset(id: "orange", color: ArtworkColor(red: 1, green: 0.55, blue: 0.1)),
        ColorPreset(id: "violet", color: ArtworkColor(red: 0.7, green: 0.4, blue: 1)),
        ColorPreset(id: "white", color: .white),
    ]
}

/// Ready-made colours as round swatches, then a colour well for any other colour.
private struct SwatchRow: View {
    let presets: [ColorPreset]
    let selected: ArtworkColor
    let custom: Binding<Color>
    let select: (ArtworkColor) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(presets) { preset in
                let isSelected = Self.isSame(preset.color, selected)
                Button { select(preset.color) } label: {
                    Circle()
                        .fill(Color(preset.color))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                        .padding(4)
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(preset.name)
                .accessibilityLabel(preset.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 8)
            ColorPicker(L10n.appearanceOtherColor, selection: custom, supportsOpacity: false)
                .labelsHidden()
                .help(L10n.appearanceOtherColor)
        }
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    /// A colour that went through the colour panel comes back a hair off.
    private static func isSame(_ a: ArtworkColor, _ b: ArtworkColor) -> Bool {
        abs(a.red - b.red) < 0.01 && abs(a.green - b.green) < 0.01 && abs(a.blue - b.blue) < 0.01
    }
}

/// The top of a screen with the notch hanging from it, as it is set up right now: the chosen background
/// and neon, the widgets in their places, and the places still free as dashed slots. Clicking a place
/// opens a menu to choose its widget. The notch itself is drawn black, as it is on a MacBook.
struct SettingsStage: View {
    let settings: AppSettings

    private static let column: CGFloat = 108
    private static let center: CGFloat = 176
    private static let band: CGFloat = 14
    private static let row: CGFloat = 84
    private static let flare: CGFloat = 5
    /// The cover of the made-up song in the player.
    private static let cover = ArtworkColor(red: 0.98, green: 0.47, blue: 0.42)

    var body: some View {
        let sides = settings.sideWidgets
        let appearance = settings.appearance
        let width = (sides.hasLeftColumn ? Self.column : 0) + Self.center + (sides.hasRightColumn ? Self.column : 0)
        let height = sides.hasBottomRow ? 2 * Self.row : Self.row
        let offset = ((sides.hasRightColumn ? Self.column : 0) - (sides.hasLeftColumn ? Self.column : 0)) / 2
        ZStack(alignment: .top) {
            // A desk at dusk, with the menu bar's strip along the top.
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.62, blue: 0.78), Color(red: 0.86, green: 0.78, blue: 0.74)],
                startPoint: .top, endPoint: .bottom
            )
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: Self.band)
            // With Liquid Glass there is no panel: the player and each widget are cards of their own.
            if !appearance.usesGlass {
                // A see-through panel is drawn over a wash of black or white, standing in for the blur of
                // what lies behind it; a solid one hides the wash.
                NotchShape(topRadius: Self.flare, bottomRadius: 12)
                    .fill((appearance.isLight ? Color.white : Color.black).opacity(appearance.isTranslucent ? 0.38 : 0))
                    .frame(width: width + 2 * Self.flare - 10 * appearance.feathering, height: height - 5 * appearance.feathering)
                    // Near full transparency the panel is a blur with a soft rim.
                    .blur(radius: 5 * appearance.feathering)
                    .offset(x: offset)
                NotchShape(topRadius: Self.flare, bottomRadius: 12)
                    .fill(Color(appearance.background).opacity(appearance.isTranslucent ? appearance.backgroundOpacity : 1))
                    .frame(width: width + 2 * Self.flare, height: height)
                    .shadow(color: Color.black.opacity(appearance.isTranslucent ? 0 : 0.35), radius: 10, y: 5)
                    .offset(x: offset)
                if let glow = appearance.glowColor(cover: Self.cover) {
                    NeonOutline(color: Color(glow), topRadius: Self.flare, bottomRadius: 12, lineWidth: 1.2)
                        .frame(width: width + 2 * Self.flare, height: height)
                        .offset(x: offset)
                        .allowsHitTesting(false)
                }
            }
            UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6, style: .continuous)
                .fill(Color.black)
                .frame(width: 84, height: Self.band)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    place(.left)
                    player(appearance)
                    place(.right)
                }
                HStack(spacing: 0) {
                    place(.bottomLeft)
                    place(.bottom)
                    place(.bottomRight)
                }
                Text(L10n.settingsStageHint)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(height: 34)
            }
        }
        .frame(height: 2 * Self.row + 34)
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: sides)
        .animation(.easeInOut(duration: 0.25), value: appearance)
    }

    /// The player in the middle, playing a made-up song: its cover, two lines of text and the progress
    /// bar in the cover's colour as it would be drawn on this background.
    private func player(_ appearance: NotchAppearance) -> some View {
        let ink = Color(appearance.ink)
        let accent = Color(appearance.readable(Self.cover))
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(Self.cover), Color(red: 0.85, green: 0.25, blue: 0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(ink.opacity(0.9)).frame(width: 70, height: 5)
                    Capsule().fill(ink.opacity(0.45)).frame(width: 46, height: 4)
                }
                Spacer(minLength: 0)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(ink.opacity(0.16)).frame(height: 3)
                Capsule().fill(accent).frame(width: 58, height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, Self.band)
        .frame(width: Self.center, height: Self.row)
        .background {
            if appearance.usesGlass {
                card(appearance).padding(.horizontal, 3).padding(.top, 2).padding(.bottom, 3)
            }
        }
        .accessibilityHidden(true)
    }

    /// A glass card in the drawing: a wash standing in for the glass, the colour, and a bright rim.
    private func card(_ appearance: NotchAppearance) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return ZStack {
            shape.fill((appearance.isLight ? Color.white : Color.black).opacity(0.38))
            shape.fill(Color(appearance.background).opacity(appearance.backgroundOpacity))
            shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8)
            // The neon outlines each card, as on the real panel.
            if let glow = appearance.glowColor(cover: Self.cover) {
                shape
                    .stroke(Color(glow), lineWidth: 1.2)
                    .shadow(color: Color(glow).opacity(0.9), radius: 2.4)
                    .shadow(color: Color(glow).opacity(0.6), radius: 6)
            }
        }
    }

    private func place(_ side: SideWidgets.Side) -> some View {
        let widget = settings.sideWidgets[side]
        let glass = settings.appearance.usesGlass
        // With glass there is no panel to be inside of: a widget sits on its own card, a free place on the desk.
        let inside = glass ? widget != nil : isInsidePanel(side)
        let isTopRow = side == .left || side == .right
        // Inside the panel a place is drawn in the panel's text colour; outside it, on the desk, in white.
        let tint = inside ? Color(settings.appearance.ink) : Color.white
        return Menu {
            Picker(Self.title(of: side), selection: Binding(
                get: { settings.sideWidgets[side] },
                set: { settings.setWidget($0, on: side) }
            )) {
                Text(L10n.settingsNone).tag(NotchWidget?.none)
                ForEach(NotchWidget.allCases, id: \.self) { widget in
                    Label(widget.title, systemImage: widget.symbol).tag(NotchWidget?.some(widget))
                }
            }
            .pickerStyle(.inline)
        } label: {
            ZStack {
                if let widget {
                    if glass {
                        card(settings.appearance)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.1))
                    }
                    VStack(spacing: 4) {
                        Image(systemName: widget.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(widget.title)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tint.opacity(0.9))
                    .padding(.horizontal, 4)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(tint.opacity(inside ? 0.3 : 0.7))
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint.opacity(inside ? 0.45 : 0.9))
                }
            }
            .padding(.horizontal, glass ? 3 : 5)
            .padding(.top, glass ? (isTopRow ? 2 : 3) : isTopRow ? Self.band + 4 : 6)
            .padding(.bottom, glass ? 3 : 6)
            .frame(width: side == .bottom ? Self.center : Self.column, height: Self.row)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Self.title(of: side))
        .accessibilityLabel(Self.title(of: side))
        .accessibilityValue(widget?.title ?? L10n.settingsNone)
    }

    /// A place is inside the panel when its column and its row are part of it.
    private func isInsidePanel(_ side: SideWidgets.Side) -> Bool {
        let sides = settings.sideWidgets
        switch side {
        case .left: return sides.hasLeftColumn
        case .right: return sides.hasRightColumn
        case .bottomLeft: return sides.hasLeftColumn && sides.hasBottomRow
        case .bottom: return sides.hasBottomRow
        case .bottomRight: return sides.hasRightColumn && sides.hasBottomRow
        }
    }

    static func title(of side: SideWidgets.Side) -> String {
        switch side {
        case .left: return L10n.settingsLeft
        case .right: return L10n.settingsRight
        case .bottomLeft: return L10n.settingsBottomLeft
        case .bottom: return L10n.settingsBottom
        case .bottomRight: return L10n.settingsBottomRight
        }
    }
}
