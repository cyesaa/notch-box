import AppKit
import NotchBoxCore
import SwiftUI

/// What lies behind a see-through panel, blurred: the desktop and the windows under the notch. It is cut
/// to the notch's silhouette with a stretchable mask image, so it follows the panel as it grows. With a
/// `feather`, the blur fades out towards its rim instead of ending at the panel's edge.
struct NotchBackdrop: NSViewRepresentable {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    /// A light blur for dark text, a dark one for white text.
    let isLight: Bool
    /// How far in from the rim the blur has reached full strength; 0 gives it the panel's crisp edge.
    var feather: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // The panel never becomes the key window; left to follow the window, the blur would be switched
        // off and drawn as a flat grey.
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        view.maskImage = Self.mask(topRadius: topRadius, bottomRadius: bottomRadius, feather: feather)
    }

    private static var masks: [String: NSImage] = [:]
    private static let pixelsPerPoint: CGFloat = 2

    /// The notch's silhouette as an image that stretches in the middle: the corners and the feathered
    /// rim keep their size whatever size the view has.
    static func mask(topRadius: CGFloat, bottomRadius: CGFloat, feather: CGFloat) -> NSImage {
        // Half-point steps, so that dragging the slider does not make an image for every position.
        let feather = max(0, (feather * 2).rounded() / 2)
        let key = "\(topRadius)-\(bottomRadius)-\(feather)"
        if let cached = masks[key] { return cached }
        let side = ceil(topRadius + bottomRadius + 2 * feather) + 1
        let top = ceil(topRadius) + 1, bottom = ceil(bottomRadius + 2 * feather) + 1
        let size = NSSize(width: 2 * side + 1, height: top + bottom + 1)
        let image = draw(size: size, topRadius: topRadius, bottomRadius: bottomRadius, feather: feather) ?? NSImage(size: size)
        image.capInsets = NSEdgeInsets(top: top, left: side, bottom: bottom, right: side)
        image.resizingMode = .stretch
        if masks.count > 200 { masks.removeAll() }
        masks[key] = image
        return image
    }

    private static func draw(size: NSSize, topRadius: CGFloat, bottomRadius: CGFloat, feather: CGFloat) -> NSImage? {
        let scale = pixelsPerPoint
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                  bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        // Points, with the origin at the top left like the SwiftUI shape.
        context.translateBy(x: 0, y: size.height * scale)
        context.scaleBy(x: scale, y: -scale)
        var rect = CGRect(origin: .zero, size: size)
        if feather > 0 {
            // The silhouette is drawn smaller and only as its own blurred shadow (the shape itself lands
            // outside the picture), which is solid inside and fades to nothing at the rim. It starts
            // above the top edge, which is the edge of the screen and stays crisp.
            rect = CGRect(x: feather, y: -3 * feather, width: size.width - 2 * feather, height: size.height + 2 * feather)
            let far = size.width + 4 * feather + 40
            // A shadow's offset and blur are in pixels, whatever the transform.
            context.setShadow(offset: CGSize(width: far * scale, height: 0), blur: feather * scale, color: CGColor(gray: 0, alpha: 1))
            context.translateBy(x: -far, y: 0)
        }
        context.addPath(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius).path(in: rect).cgPath)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fillPath()
        return context.makeImage().map { NSImage(cgImage: $0, size: size) }
    }
}

/// With Liquid Glass, the open player is not one sheet of glass: the player and each widget sit on a
/// glass card of their own, with the desktop showing between them, the way notifications do. This is
/// one such card, drawn behind a widget and a little smaller than its place, so that cards do not touch.
struct WidgetCard: View {
    let appearance: NotchAppearance
    /// The neon's colour, drawn around each card; nil while the neon is off.
    let glow: ArtworkColor?
    /// ImageRenderer cannot draw glass; a wash stands in for it.
    let isSnapshot: Bool

    /// The gap between a card and the edge of its place (twice this between two cards).
    static let inset: CGFloat = 4
    static let cornerRadius: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let tint = Color(appearance.background).opacity(appearance.backgroundOpacity)
        ZStack {
            if isSnapshot {
                shape.fill((appearance.isLight ? Color.white : Color.black).opacity(0.38))
                shape.fill(tint)
                shape.strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            } else if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular.tint(tint), in: shape)
                    .environment(\.colorScheme, appearance.isLight ? .light : .dark)
            }
            if let glow {
                shape
                    .stroke(Color(glow), lineWidth: 1.5)
                    .shadow(color: Color(glow).opacity(0.9), radius: 3)
                    .shadow(color: Color(glow).opacity(0.6), radius: 8)
            }
        }
        .padding(Self.inset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
