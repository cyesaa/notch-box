import Foundation
import Testing
@testable import NotchBoxCore

struct ColorContrastTests {
    @Test func luminanceRunsFromBlackToWhite() {
        #expect(ArtworkColor.black.luminance == 0)
        #expect(abs(ArtworkColor.white.luminance - 1) < 0.0001)
        // Green looks far brighter than blue at the same strength.
        let green = ArtworkColor(red: 0, green: 1, blue: 0).luminance
        let blue = ArtworkColor(red: 0, green: 0, blue: 1).luminance
        #expect(green > 0.7 && blue < 0.08)
    }

    @Test func contrastIsOneForTheSameColourAndTwentyOneForBlackOnWhite() {
        let red = ArtworkColor(red: 1, green: 0, blue: 0)
        #expect(red.contrast(with: red) == 1)
        #expect(abs(ArtworkColor.black.contrast(with: .white) - 21) < 0.001)
        #expect(ArtworkColor.white.contrast(with: .black) == ArtworkColor.black.contrast(with: .white))
    }

    @Test func mixingMovesAColourTowardsAnother() {
        let half = ArtworkColor.black.mixed(with: .white, amount: 0.5)
        #expect(half == ArtworkColor(red: 0.5, green: 0.5, blue: 0.5))
        #expect(ArtworkColor.black.mixed(with: .white, amount: 0) == .black)
        #expect(ArtworkColor.black.mixed(with: .white, amount: 2) == .white)
    }

    @Test func aWiderGamutColourIsBroughtIntoRange() {
        #expect(ArtworkColor(red: 1.2, green: -0.1, blue: 0.5).clamped == ArtworkColor(red: 1, green: 0, blue: 0.5))
        #expect(ArtworkColor(red: .nan, green: 0.3, blue: .infinity).clamped == ArtworkColor(red: 0, green: 0.3, blue: 1))
    }
}

struct NotchAppearanceTests {
    let navy = ArtworkColor(red: 0.05, green: 0.08, blue: 0.3)
    let yellow = ArtworkColor(red: 1, green: 0.9, blue: 0.2)
    let red = ArtworkColor(red: 1, green: 0, blue: 0)
    let pink = ArtworkColor(red: 1, green: 0.2, blue: 0.8)

    @Test func theNotchStartsBlackWithoutNeon() {
        let appearance = NotchAppearance.default
        #expect(appearance.background == .black)
        #expect(appearance.glow == .off)
        #expect(!appearance.glowsWhenIdle)
        #expect(appearance.ink == .white)
        #expect(appearance.paper == .black)
        #expect(NotchDisplayState.allCases.allSatisfy { !appearance.showsGlow(in: $0) })
    }

    @Test func textTurnsDarkOnALightBackground() {
        #expect(NotchAppearance(background: .white).ink == .black)
        #expect(NotchAppearance(background: .white).paper == .white)
        #expect(NotchAppearance(background: yellow).ink == .black)
        #expect(NotchAppearance(background: ArtworkColor(red: 0.7, green: 0.7, blue: 0.7)).ink == .black)
    }

    @Test func textStaysWhiteOnDarkAndStrongColours() {
        #expect(NotchAppearance(background: navy).ink == .white)
        #expect(NotchAppearance(background: red).ink == .white)
        #expect(NotchAppearance(background: ArtworkColor(red: 0.35, green: 0.1, blue: 0.5)).ink == .white)
        #expect(NotchAppearance(background: ArtworkColor(red: 0.3, green: 0.3, blue: 0.3)).ink == .white)
    }

    @Test func theNeonTakesItsColourFromTheCoverOrFromTheUser() {
        let cover = ArtworkColor(red: 0.9, green: 0.5, blue: 0.2)
        #expect(NotchAppearance(glow: .off, glowColor: pink).glowColor(cover: cover) == nil)
        #expect(NotchAppearance(glow: .artwork, glowColor: pink).glowColor(cover: cover) == cover)
        #expect(NotchAppearance(glow: .custom, glowColor: pink).glowColor(cover: cover) == pink)
    }

    @Test func theNeonShowsWheneverTheNotchShowsSomething() {
        let appearance = NotchAppearance(glow: .custom)
        for state in NotchDisplayState.allCases where state != .idle {
            #expect(appearance.showsGlow(in: state))
        }
        #expect(!appearance.showsGlow(in: .idle))
    }

    @Test func theNeonCanStayOnAroundTheClosedNotch() {
        #expect(NotchAppearance(glow: .artwork, glowsWhenIdle: true).showsGlow(in: .idle))
        // The switch means nothing while the neon is off.
        #expect(!NotchAppearance(glow: .off, glowsWhenIdle: true).showsGlow(in: .idle))
    }

    @Test func coverColoursMadeForTheBlackNotchAreLeftAloneOnBlack() {
        // The dimmest and most saturated the picker hands out, all the way round the colour wheel.
        for step in 0..<24 {
            let accent = ArtworkColor(hsb: .init(hue: Double(step) / 24, saturation: ArtworkAccent.maximumSaturation, brightness: ArtworkAccent.minimumBrightness))
            #expect(NotchAppearance.default.readable(accent) == accent)
        }
        #expect(NotchAppearance.default.readable(ArtworkAccent.fallback) == ArtworkAccent.fallback)
    }

    @Test func aCoverColourIsMovedUntilItStandsOutFromTheBackground() {
        let pale = ArtworkColor(red: 1, green: 0.95, blue: 0.6)
        let onWhite = NotchAppearance(background: .white)
        let darkened = onWhite.readable(pale)
        #expect(darkened.contrast(with: .white) >= NotchAppearance.minimumAccentContrast)
        #expect(darkened.luminance < pale.luminance)
        #expect(onWhite.readable(ArtworkAccent.fallback).contrast(with: .white) >= NotchAppearance.minimumAccentContrast)

        // The same colour as the background, on a background with white text: it is lightened.
        let onRed = NotchAppearance(background: red)
        let lightened = onRed.readable(red)
        #expect(lightened.contrast(with: red) >= NotchAppearance.minimumAccentContrast)
        #expect(lightened.luminance > red.luminance)
    }

    @Test func savesAndRestores() throws {
        let appearance = NotchAppearance(background: navy, glow: .custom, glowColor: pink, glowsWhenIdle: true)
        let data = try JSONEncoder().encode(appearance)
        #expect(NotchAppearance.decode(data) == appearance)
    }

    @Test func aSavedChoiceWithPartsMissingOrUnknownFallsBackPartByPart() {
        let partial = Data(#"{"background":{"red":0.1,"green":0.2,"blue":0.3},"glow":"rainbow"}"#.utf8)
        let decoded = NotchAppearance.decode(partial)
        #expect(decoded?.background == ArtworkColor(red: 0.1, green: 0.2, blue: 0.3))
        #expect(decoded?.glow == .off)
        #expect(decoded?.glowColor == NotchAppearance.defaultGlowColor)
        #expect(decoded?.glowsWhenIdle == false)
        #expect(NotchAppearance.decode(Data("{}".utf8)) == .default)
        #expect(NotchAppearance.decode(Data("junk".utf8)) == nil)
        let wild = Data(#"{"background":{"red":7,"green":-2,"blue":0.5}}"#.utf8)
        #expect(NotchAppearance.decode(wild)?.background == ArtworkColor(red: 1, green: 0, blue: 0.5))
    }
}

struct NotchTranslucencyTests {
    let navy = ArtworkColor(red: 0.05, green: 0.08, blue: 0.3)

    @Test func theNotchStartsSolidAndWithoutGlass() {
        #expect(NotchAppearance.default.backgroundOpacity == 1)
        #expect(!NotchAppearance.default.usesGlass)
        #expect(!NotchAppearance.default.isTranslucent)
    }

    @Test func aSeeThroughColourOrGlassMakesThePanelTranslucent() {
        #expect(NotchAppearance(backgroundOpacity: 0.6).isTranslucent)
        #expect(NotchAppearance(usesGlass: true).isTranslucent)
        // Close enough to solid to draw it solid.
        #expect(!NotchAppearance(backgroundOpacity: 0.999).isTranslucent)
    }

    @Test func opacityStaysBetweenNoneAndFull() {
        #expect(NotchAppearance(backgroundOpacity: 1.7).backgroundOpacity == 1)
        #expect(NotchAppearance(backgroundOpacity: -0.2).backgroundOpacity == 0)
        #expect(NotchAppearance(backgroundOpacity: .nan).backgroundOpacity == 1)
    }

    @Test func thePanelKeepsItsOwnEdgeUntilTheLastQuarterOfTheSlider() {
        #expect(NotchAppearance(backgroundOpacity: 1).feathering == 0)
        #expect(NotchAppearance(backgroundOpacity: 0.6).feathering == 0)
        #expect(NotchAppearance(backgroundOpacity: 0.25).feathering == 0)
    }

    @Test func overTheLastQuarterTheEdgeDissolvesIntoASoftBlur() {
        // At full transparency the colour and the panel's edge are gone, and what is left behind the
        // widgets is a blur that fades out at its rim, so that they can still be read.
        #expect(NotchAppearance(backgroundOpacity: 0.125).feathering == 0.5)
        #expect(NotchAppearance(backgroundOpacity: 0).feathering == 1)
        #expect(NotchAppearance(backgroundOpacity: 0, usesGlass: true).feathering == 1)
    }

    @Test func textColourStillFollowsTheChosenColour() {
        // What shows through is blurred dark or light to match, so the colour alone decides.
        #expect(NotchAppearance(background: .white, backgroundOpacity: 0.2).ink == .black)
        #expect(NotchAppearance(background: navy, backgroundOpacity: 0.2).ink == .white)
    }

    @Test func savesAndRestoresTranslucency() throws {
        let appearance = NotchAppearance(background: navy, backgroundOpacity: 0.45, usesGlass: true)
        let data = try JSONEncoder().encode(appearance)
        #expect(NotchAppearance.decode(data) == appearance)
    }

    @Test func aChoiceSavedBeforeTranslucencyExistedIsSolid() {
        let old = Data(#"{"background":{"red":0.1,"green":0.2,"blue":0.3},"glow":"artwork","glowColor":{"red":1,"green":0,"blue":0},"glowsWhenIdle":true}"#.utf8)
        let decoded = NotchAppearance.decode(old)
        #expect(decoded?.backgroundOpacity == 1)
        #expect(decoded?.usesGlass == false)
        #expect(decoded?.glow == .artwork)
        let wild = Data(#"{"backgroundOpacity":9,"usesGlass":"yes"}"#.utf8)
        #expect(NotchAppearance.decode(wild)?.backgroundOpacity == 1)
        #expect(NotchAppearance.decode(wild)?.usesGlass == false)
    }
}
