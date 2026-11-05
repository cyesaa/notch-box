// Draws the NotchBox app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift [output.icns] [preview.png]
// Needs only the Command Line Tools (CoreGraphics, ImageIO and /usr/bin/iconutil).
//
// The icon is the app's own open player hanging from the top of a dark screen: cover, waveform and a
// progress bar in the cover's colour, with warm light spilling out underneath.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Apple's icon body is close to a superellipse; exponent 5 matches the macOS squircle well.
func squircle(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for step in 0...steps {
        let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(angle), s = sin(angle)
        let x = pow(abs(c), 2 / exponent) * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / exponent) * (s < 0 ? -1 : 1)
        let point = CGPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// Rectangle with only its bottom corners rounded (CoreGraphics origin is bottom-left).
func notchPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
    path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
}

/// Draws the icon on a 1024 × 1024 canvas.
func drawIcon(in context: CGContext) {
    let canvas: CGFloat = 1024
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = squircle(in: body)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Drop shadow under the body, as on other macOS icons.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.35))
    context.addPath(bodyPath)
    context.setFillColor(color(0x140A33))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()

    // Screen: deep night with a soft sheen towards the top.
    let screen = CGGradient(
        colorsSpace: space,
        colors: [color(0x0D0826), color(0x2A1466), color(0x5B2A9E)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(screen, start: CGPoint(x: canvas / 2, y: body.minY), end: CGPoint(x: canvas / 2, y: body.maxY), options: [])

    // The open player hanging from the top edge, like the notch when hovered.
    let panel = CGRect(x: canvas / 2 - 290, y: body.maxY - 450, width: 580, height: 450 + 40)

    // Warm light spilling out from under the player.
    let glowCenter = CGPoint(x: canvas / 2, y: panel.minY - 10)
    let glow = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFB36B, 1.0), color(0xFF5E7E, 0.65), color(0x8A4DFF, 0.22), color(0x8A4DFF, 0)] as CFArray,
        locations: [0, 0.3, 0.65, 1]
    )!
    context.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: 500, options: [])

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 46, color: color(0x1A0420, 0.6))
    context.addPath(notchPath(panel, radius: 118))
    context.setFillColor(color(0x000000))
    context.fillPath()
    context.restoreGState()

    // Cover.
    let cover = CGRect(x: panel.minX + 64, y: panel.minY + 184, width: 170, height: 170)
    context.saveGState()
    context.addPath(CGPath(roundedRect: cover, cornerWidth: 40, cornerHeight: 40, transform: nil))
    context.clip()
    let art = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFC56B), color(0xFF5E7E), color(0x8A4DFF)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(art, start: CGPoint(x: cover.minX, y: cover.maxY), end: CGPoint(x: cover.maxX, y: cover.minY), options: [])
    context.restoreGState()

    // Waveform right of the cover.
    let heights: [CGFloat] = [0.42, 0.8, 1.0, 0.62, 0.86]
    let barWidth: CGFloat = 28, gap: CGFloat = 20, maxHeight: CGFloat = 156
    let waveWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = panel.maxX - 64 - waveWidth
    for level in heights {
        let height = maxHeight * level
        let bar = CGRect(x: x, y: cover.midY - height / 2, width: barWidth, height: height)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        x += barWidth + gap
    }
    context.setFillColor(color(0xFFFFFF, 0.95))
    context.fillPath()

    // Progress bar tinted with the cover's colour.
    let track = CGRect(x: panel.minX + 64, y: panel.minY + 96, width: panel.width - 128, height: 22)
    context.addPath(CGPath(roundedRect: track, cornerWidth: 11, cornerHeight: 11, transform: nil))
    context.setFillColor(color(0xFFFFFF, 0.18))
    context.fillPath()
    let filled = CGRect(x: track.minX, y: track.minY, width: track.width * 0.58, height: track.height)
    context.saveGState()
    context.addPath(CGPath(roundedRect: filled, cornerWidth: 11, cornerHeight: 11, transform: nil))
    context.clip()
    let fill = CGGradient(colorsSpace: space, colors: [color(0xFFB36B), color(0xFF5E7E)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(fill, start: CGPoint(x: filled.minX, y: 0), end: CGPoint(x: filled.maxX, y: 0), options: [])
    context.restoreGState()
    context.restoreGState()

    // Hairline edge so the icon reads on light and dark backgrounds.
    context.addPath(bodyPath)
    context.setStrokeColor(color(0xFFFFFF, 0.12))
    context.setLineWidth(2)
    context.strokePath()
}

func renderPNG(pixels: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw NSError(domain: "make-icon", code: 1) }
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: context)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "make-icon", code: 2) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "make-icon", code: 3) }
}

let arguments = CommandLine.arguments
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = arguments.count > 1 ? URL(fileURLWithPath: arguments[1]) : root.appendingPathComponent("Resources/AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("NotchBox-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
if arguments.count > 2 {
    try renderPNG(pixels: 1024, to: URL(fileURLWithPath: arguments[2]))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: iconutil failed\n".utf8))
    exit(1)
}
print("Wrote \(output.path)")
