import AppKit
import NotchBoxCore
import SwiftUI

/// Shared colours and type for the notch views. Out of the box the panel is pure black, so it merges
/// with the hardware notch, and colour comes only from the cover (`NotchViewModel.accent`). The user can
/// pick another background (`NotchAppearance`); text and symbols are then drawn in `ink`, white or black,
/// whichever reads on it.
enum NotchTheme {
    /// The colour of text and symbols. Changed only through `use(_:)`; the views read it as they are
    /// drawn, and `NotchRootView` draws them all again when it flips between white and black.
    nonisolated(unsafe) private(set) static var ink = Color.white
    /// What is drawn on a shape filled with `ink` (the play button's symbol, today's number).
    nonisolated(unsafe) private(set) static var paper = Color.black

    static func use(_ appearance: NotchAppearance) {
        ink = Color(appearance.ink)
        paper = Color(appearance.paper)
    }

    static var primaryText: Color { ink }
    static var secondaryText: Color { ink.opacity(0.6) }
    static var tertiaryText: Color { ink.opacity(0.4) }
    static var track: Color { ink.opacity(0.16) }
    static var tile: Color { ink.opacity(0.08) }

    static let titleFont = Font.system(size: 15, weight: .semibold)
    static let subtitleFont = Font.system(size: 12.5, weight: .regular)
    static let detailFont = Font.system(size: 11.5, weight: .regular)
    static let timeFont = Font.system(size: 10, weight: .medium, design: .rounded).monospacedDigit()

    /// How long a colour change from a new cover takes.
    static let accentAnimation = Animation.easeInOut(duration: 0.6)
}

extension Color {
    init(_ rgb: ArtworkColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

extension ArtworkColor {
    /// A colour from a colour picker, brought into sRGB.
    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB)
        self = ArtworkColor(
            red: Double(srgb?.redComponent ?? 0), green: Double(srgb?.greenComponent ?? 0), blue: Double(srgb?.blueComponent ?? 0)
        ).clamped
    }
}

/// Shrinks and dims a control while it is pressed.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
