import NotchBoxCore
import SwiftUI

/// Shared colours and type for the notch views. The panel itself is always pure black so it merges
/// with the hardware notch; colour comes only from the cover (`NotchViewModel.accent`).
enum NotchTheme {
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText = Color.white.opacity(0.4)
    static let track = Color.white.opacity(0.16)
    static let tile = Color.white.opacity(0.08)

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

/// Shrinks and dims a control while it is pressed.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
