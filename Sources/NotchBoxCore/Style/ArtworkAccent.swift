import Foundation

/// An sRGB colour with components in 0...1.
public struct ArtworkColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public struct HSB: Equatable, Sendable {
        /// 0..<1 (fraction of a full turn).
        public var hue: Double
        public var saturation: Double
        public var brightness: Double
    }

    public var hsb: HSB {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = (green - blue) / delta
            } else if maxValue == green {
                hue = 2 + (blue - red) / delta
            } else {
                hue = 4 + (red - green) / delta
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSB(hue: hue, saturation: maxValue > 0 ? delta / maxValue : 0, brightness: maxValue)
    }

    public init(hsb: HSB) {
        let h = (hsb.hue - floor(hsb.hue)) * 6
        let sector = Int(h) % 6
        let fraction = h - floor(h)
        let v = hsb.brightness
        let p = v * (1 - hsb.saturation)
        let q = v * (1 - hsb.saturation * fraction)
        let t = v * (1 - hsb.saturation * (1 - fraction))
        switch sector {
        case 0: self.init(red: v, green: t, blue: p)
        case 1: self.init(red: q, green: v, blue: p)
        case 2: self.init(red: p, green: v, blue: t)
        case 3: self.init(red: p, green: q, blue: v)
        case 4: self.init(red: t, green: p, blue: v)
        default: self.init(red: v, green: p, blue: q)
        }
    }
}

/// Picks the colour the player is tinted with (glow, progress bar, waveform) from the cover's pixels.
/// The most vivid hue wins over large grey or dark areas, and the result is kept bright enough to
/// read on the black notch and calm enough not to shout.
public enum ArtworkAccent {
    /// Used without artwork or when the artwork is (nearly) grey.
    public static let fallback = ArtworkColor(red: 0.80, green: 0.82, blue: 0.90)
    public static let minimumBrightness = 0.78
    public static let maximumSaturation = 0.75

    private static let hueBins = 12
    /// Pixels greyer or darker than this carry no colour worth picking.
    private static let minimumPixelSaturation = 0.2
    private static let minimumPixelBrightness = 0.12
    /// The winning hue must cover at least this share of vividness per pixel.
    private static let minimumShare = 0.02

    /// `pixels` in any order; a downsampled cover (for example 24 × 24) is plenty.
    public static func accent(from pixels: [ArtworkColor]) -> ArtworkColor {
        guard !pixels.isEmpty else { return fallback }
        var weights = Array(repeating: 0.0, count: hueBins)
        var sums = Array(repeating: ArtworkColor(red: 0, green: 0, blue: 0), count: hueBins)
        for pixel in pixels {
            let hsb = pixel.hsb
            guard hsb.saturation >= minimumPixelSaturation, hsb.brightness >= minimumPixelBrightness else { continue }
            let weight = hsb.saturation * hsb.brightness
            // Bins are centred on their hue, so pure red (0°) is not split across the wrap-around.
            let bin = Int((hsb.hue * Double(hueBins) + 0.5).rounded(.down)) % hueBins
            weights[bin] += weight
            sums[bin].red += pixel.red * weight
            sums[bin].green += pixel.green * weight
            sums[bin].blue += pixel.blue * weight
        }
        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }),
              weights[best] / Double(pixels.count) >= minimumShare
        else { return fallback }
        let total = weights[best]
        let mean = ArtworkColor(red: sums[best].red / total, green: sums[best].green / total, blue: sums[best].blue / total)
        var hsb = mean.hsb
        hsb.saturation = min(hsb.saturation, maximumSaturation)
        hsb.brightness = max(hsb.brightness, minimumBrightness)
        return ArtworkColor(hsb: hsb)
    }
}
