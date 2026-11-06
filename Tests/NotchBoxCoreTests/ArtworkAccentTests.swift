import Testing
@testable import NotchBoxCore

struct ArtworkAccentTests {
    func pixels(_ color: ArtworkColor, count: Int) -> [ArtworkColor] {
        Array(repeating: color, count: count)
    }

    func hue(_ color: ArtworkColor) -> Double { color.hsb.hue * 360 }

    @Test func noPixelsGiveTheFallback() {
        #expect(ArtworkAccent.accent(from: []) == ArtworkAccent.fallback)
    }

    @Test func grayscaleArtworkGivesTheFallback() {
        let grays = (0..<50).map { ArtworkColor(red: Double($0) / 50, green: Double($0) / 50, blue: Double($0) / 50) }
        #expect(ArtworkAccent.accent(from: grays) == ArtworkAccent.fallback)
    }

    @Test func solidRedGivesARedAccent() {
        let accent = ArtworkAccent.accent(from: pixels(ArtworkColor(red: 0.9, green: 0.1, blue: 0.1), count: 20))
        #expect(hue(accent) < 10 || hue(accent) > 350)
    }

    @Test func darkColoursAreBrightenedToShowOnBlack() {
        let accent = ArtworkAccent.accent(from: pixels(ArtworkColor(red: 0.05, green: 0.05, blue: 0.3), count: 20))
        #expect(abs(hue(accent) - 240) < 5)
        #expect(accent.hsb.brightness >= ArtworkAccent.minimumBrightness)
    }

    @Test func saturationIsCapped() {
        let accent = ArtworkAccent.accent(from: pixels(ArtworkColor(red: 0, green: 1, blue: 0), count: 20))
        #expect(accent.hsb.saturation <= ArtworkAccent.maximumSaturation + 0.0001)
    }

    @Test func aVividMinorityBeatsAGrayMajority() {
        let gray = pixels(ArtworkColor(red: 0.5, green: 0.5, blue: 0.5), count: 90)
        let orange = pixels(ArtworkColor(red: 1, green: 0.55, blue: 0.1), count: 10)
        let accent = ArtworkAccent.accent(from: gray + orange)
        #expect(abs(hue(accent) - 30) < 8)
    }

    @Test func theLargestVividHueWins() {
        let blue = pixels(ArtworkColor(red: 0.1, green: 0.3, blue: 0.9), count: 60)
        let red = pixels(ArtworkColor(red: 0.9, green: 0.1, blue: 0.1), count: 40)
        let accent = ArtworkAccent.accent(from: red + blue)
        #expect(abs(hue(accent) - 225) < 10)
    }

    @Test func hsbRoundTrips() {
        let color = ArtworkColor(red: 0.2, green: 0.6, blue: 0.4)
        let back = ArtworkColor(hsb: color.hsb)
        #expect(abs(back.red - color.red) < 0.0001)
        #expect(abs(back.green - color.green) < 0.0001)
        #expect(abs(back.blue - color.blue) < 0.0001)
    }
}
