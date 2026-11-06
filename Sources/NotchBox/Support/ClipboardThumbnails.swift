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

    /// Longest side of the large preview, in pixels.
    static let previewPixelSize = 1600

    private var cache: [Int: Thumbnail] = [:]
    /// Only the image being previewed is kept at the larger size.
    private var previewCache: (id: Int, image: NSImage)?

    func preview(for item: ClipboardItem) -> NSImage? {
        if let previewCache, previewCache.id == item.id { return previewCache.image }
        guard case .image(let data, _) = item.content, let image = Self.decode(data, maxPixelSize: Self.previewPixelSize) else {
            return nil
        }
        let preview = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        previewCache = (item.id, preview)
        return preview
    }

    private static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary)
    }

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
        if let previewCache, !ids.contains(previewCache.id) { self.previewCache = nil }
    }
}
