import AppKit
import ImageIO
import NotchBoxCore

/// Small, cached previews of the images in the clipboard history, so the list never decodes a full-size
/// screenshot while drawing.
@MainActor
final class ClipboardThumbnails {
    struct Thumbnail {
        let image: NSImage
        /// The full image's size in pixels, shown next to it.
        let pixelSize: CGSize
    }

    /// Longest side of a preview, in pixels (the list shows them at 26 points on a 2x screen).
    static let maxPixelSize = 96

    private var cache: [Int: Thumbnail] = [:]

    func thumbnail(for item: ClipboardItem) -> Thumbnail? {
        if let cached = cache[item.id] { return cached }
        guard case .image(let data, _) = item.content,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
              ] as CFDictionary)
        else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? image.width
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? image.height
        let thumbnail = Thumbnail(
            image: NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height)),
            pixelSize: CGSize(width: width, height: height)
        )
        cache[item.id] = thumbnail
        return thumbnail
    }

    /// Drops the previews of items no longer in the list.
    func keep(_ items: [ClipboardItem]) {
        let ids = Set(items.map(\.id))
        cache = cache.filter { ids.contains($0.key) }
    }
}
