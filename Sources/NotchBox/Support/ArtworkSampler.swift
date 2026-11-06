import AppKit
import NotchBoxCore

/// Reads a cover's pixels at low resolution for `ArtworkAccent`.
enum ArtworkSampler {
    static func accent(for image: NSImage?) -> ArtworkColor {
        guard let image else { return ArtworkAccent.fallback }
        return ArtworkAccent.accent(from: pixels(of: image))
    }

    /// The image scaled to `side` × `side` in sRGB; transparent pixels are left out.
    static func pixels(of image: NSImage, side: Int = 24) -> [ArtworkColor] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return [] }
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return [] }
        return stride(from: 0, to: bytes.count, by: 4).compactMap { index in
            let alpha = Double(bytes[index + 3]) / 255
            guard alpha > 0.5 else { return nil }
            return ArtworkColor(
                red: min(1, Double(bytes[index]) / 255 / alpha),
                green: min(1, Double(bytes[index + 1]) / 255 / alpha),
                blue: min(1, Double(bytes[index + 2]) / 255 / alpha)
            )
        }
    }
}
