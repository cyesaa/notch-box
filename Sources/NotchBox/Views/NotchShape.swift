import SwiftUI

/// The notch silhouette. The body is `rect` inset by `topRadius` on each side, with rounded bottom
/// corners; at the top it flares outwards with concave corners of `topRadius`, so it meets the
/// screen edge the way the hardware notch meets the bezel.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let flare = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let body = rect.insetBy(dx: flare, dy: 0)
        let radius = max(0, min(bottomRadius, body.height / 2, body.width / 2))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: body.minX, y: rect.minY + flare), control: CGPoint(x: body.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: body.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: body.minX + radius, y: body.maxY), control: CGPoint(x: body.minX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.maxY))
        path.addQuadCurve(to: CGPoint(x: body.maxX, y: body.maxY - radius), control: CGPoint(x: body.maxX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY + flare))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: body.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
