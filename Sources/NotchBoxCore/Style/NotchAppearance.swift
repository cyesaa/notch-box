import Foundation

extension ArtworkColor {
    public static let black = ArtworkColor(red: 0, green: 0, blue: 0)
    public static let white = ArtworkColor(red: 1, green: 1, blue: 1)

    /// The colour with every component inside 0...1. A colour picker can hand over a wider-gamut colour,
    /// and a saved file can hold anything.
    public var clamped: ArtworkColor {
        func clamp(_ value: Double) -> Double { value.isNaN ? 0 : min(max(value, 0), 1) }
        return ArtworkColor(red: clamp(red), green: clamp(green), blue: clamp(blue))
    }

    /// How bright the colour looks, from 0 (black) to 1 (white): the WCAG relative luminance.
    public var luminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The WCAG contrast ratio with another colour: 1 for the same colour, 21 for black on white.
    public func contrast(with other: ArtworkColor) -> Double {
        let lighter = max(luminance, other.luminance), darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The colour `amount` (0...1) of the way towards `other`.
    public func mixed(with other: ArtworkColor, amount: Double) -> ArtworkColor {
        let t = min(max(amount, 0), 1)
        return ArtworkColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }
}

/// How the notch panel looks: the colour behind everything, and the neon line along its edge. The user
/// picks both in Settings; out of the box the panel is black with no neon, merging with the hardware notch.
public struct NotchAppearance: Equatable, Codable, Sendable {
    public enum Glow: String, CaseIterable, Codable, Sendable {
        case off
        /// The colour picked from the cover of what is playing.
        case artwork
        /// `glowColor`.
        case custom
    }

    public var background: ArtworkColor
    /// How solid the background colour is, from 0 (only what lies behind the notch, blurred) to 1 (solid).
    public var backgroundOpacity: Double
    /// Draw the panel as Liquid Glass (macOS 26 and later), tinted with the background colour.
    public var usesGlass: Bool
    public var glow: Glow
    /// The neon's colour while `glow` is `.custom`.
    public var glowColor: ArtworkColor
    /// Keep the neon on around the closed notch too, not only while the notch shows something.
    public var glowsWhenIdle: Bool

    public static let defaultGlowColor = ArtworkColor(red: 0.25, green: 0.85, blue: 1)
    public static let `default` = NotchAppearance()

    /// A background brighter than this gets dark text. Higher than the point where black and white text
    /// contrast equally (0.18), so that strong colours such as red and blue keep white text, as buttons
    /// in those colours do everywhere.
    public static let lightLuminance = 0.3
    /// A cover's colour must stand out from the background at least this much.
    public static let minimumAccentContrast = 2.0

    public init(
        background: ArtworkColor = .black, backgroundOpacity: Double = 1, usesGlass: Bool = false, glow: Glow = .off,
        glowColor: ArtworkColor = NotchAppearance.defaultGlowColor, glowsWhenIdle: Bool = false
    ) {
        self.background = background
        self.backgroundOpacity = Self.sensibleOpacity(backgroundOpacity)
        self.usesGlass = usesGlass
        self.glow = glow
        self.glowColor = glowColor
        self.glowsWhenIdle = glowsWhenIdle
    }

    /// Something shows through the panel: the colour is not solid, or the panel is glass.
    public var isTranslucent: Bool { usesGlass || backgroundOpacity < 0.995 }

    /// The part of the transparency slider where the panel loses its edge: below this much colour.
    public static let featheringOpacity = 0.25

    /// How far the panel has dissolved into a soft-edged blur, from 0 (its own crisp edge) to 1. It
    /// rises over the last quarter of the transparency slider: at full transparency the colour and the
    /// edge are gone, and what is left behind the widgets is a blur that fades out at its rim, the way
    /// a shadow does, so that they can still be read.
    public var feathering: Double {
        1 - min(1, backgroundOpacity / Self.featheringOpacity)
    }

    static func sensibleOpacity(_ value: Double) -> Double {
        value.isNaN ? 1 : min(max(value, 0), 1)
    }

    public var isLight: Bool { background.luminance > Self.lightLuminance }

    /// The colour of text and symbols: white on a dark background, black on a light one. A see-through
    /// background is judged by its colour alone: what shows through it is blurred dark or light to match.
    public var ink: ArtworkColor { isLight ? .black : .white }

    /// What is drawn on a shape filled with `ink` (the play button's symbol, today's number).
    public var paper: ArtworkColor { isLight ? .white : .black }

    /// A colour picked from a cover, which is picked to show on black, made to show on this background:
    /// moved towards the text colour until it stands out. On black it comes back as it went in.
    public func readable(_ accent: ArtworkColor) -> ArtworkColor {
        var color = accent
        var step = 0
        while color.contrast(with: background) < Self.minimumAccentContrast, step < 10 {
            step += 1
            color = accent.mixed(with: ink, amount: Double(step) / 10)
        }
        return color
    }

    /// The neon's colour, given the colour of the cover that is playing; nil while it is off.
    public func glowColor(cover: ArtworkColor) -> ArtworkColor? {
        switch glow {
        case .off: return nil
        case .artwork: return cover
        case .custom: return glowColor
        }
    }

    /// Whether the neon is on in a state: whenever the notch shows something, and around the closed
    /// notch only when asked to.
    public func showsGlow(in state: NotchDisplayState) -> Bool {
        glow != .off && (state != .idle || glowsWhenIdle)
    }

    /// Reads a saved choice; nil when it is not one at all. A part that is missing or unknown (saved by
    /// another version) takes its default, the rest is kept.
    public static func decode(_ data: Data) -> NotchAppearance? {
        try? JSONDecoder().decode(NotchAppearance.self, from: data)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        background = (try? values.decodeIfPresent(ArtworkColor.self, forKey: .background))?.clamped ?? .black
        backgroundOpacity = Self.sensibleOpacity((try? values.decodeIfPresent(Double.self, forKey: .backgroundOpacity)) ?? 1)
        usesGlass = (try? values.decodeIfPresent(Bool.self, forKey: .usesGlass)) ?? false
        glow = (try? values.decodeIfPresent(String.self, forKey: .glow)).flatMap(Glow.init(rawValue:)) ?? .off
        glowColor = (try? values.decodeIfPresent(ArtworkColor.self, forKey: .glowColor))?.clamped ?? Self.defaultGlowColor
        glowsWhenIdle = (try? values.decodeIfPresent(Bool.self, forKey: .glowsWhenIdle)) ?? false
    }
}
