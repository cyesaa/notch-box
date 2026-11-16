import NotchBoxCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let state = model.displayState
        let size = model.contentSize
        let flare = NotchLayout.topCornerRadius(for: state)
        let bottomRadius = NotchLayout.bottomCornerRadius(for: state)
        // The open player grows sideways for its columns, keeping the player under the notch.
        let offset = NotchLayout.horizontalOffset(for: state, sides: model.sideWidgets)
        // A virtual notch can be hidden while idle (menu setting).
        let hidden = state == .idle && model.hidesIdleShape
        let appearance = model.appearance
        // Around a real notch the closed shape stays black, whatever colour was chosen: it sits behind
        // the cut-out in the screen, and any edge of it that showed would show as a coloured sliver.
        let background = state == .idle && !model.isVirtualNotch ? ArtworkColor.black : appearance.background
        let glow = hidden ? nil : model.glowColor
        ZStack(alignment: .top) {
            // The silhouette is wider than the content by the flared top corners on each side.
            NotchShape(topRadius: flare, bottomRadius: bottomRadius)
                .fill(Color(background))
                .frame(width: size.width + 2 * flare, height: size.height)
                .shadow(color: Color.black.opacity(state == .idle ? 0 : 0.45), radius: state.isOpen ? 16 : 8, y: state.isOpen ? 8 : 3)
                .opacity(hidden ? 0 : model.isSeeThrough ? 0.12 : 1)
                .offset(x: offset)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(NotchShape(topRadius: 0, bottomRadius: bottomRadius))
                .offset(x: offset)
                // The views take their text colour from `NotchTheme` as they are drawn; when it flips
                // between white and black they are all drawn again.
                .id(appearance.isLight)
            if let glow {
                NeonOutline(color: Color(glow), topRadius: flare, bottomRadius: bottomRadius)
                    .frame(width: size.width + 2 * flare, height: size.height)
                    .opacity(model.isSeeThrough ? 0.12 : 1)
                    .offset(x: offset)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.displayState)
        .animation(NotchTheme.accentAnimation, value: model.accent)
        .animation(NotchTheme.accentAnimation, value: model.glowColor)
        .animation(.easeInOut(duration: 0.25), value: appearance)
        .animation(.easeOut(duration: 0.18), value: model.isSeeThrough)
    }

    @ViewBuilder
    private var content: some View {
        switch model.displayState {
        case .idle:
            Color.clear
        case .mini:
            CollapsedView(model: model)
                .transition(.notchContent)
        case .expanded:
            withSideColumns {
                if let item = model.previewedClipboardItem {
                    ClipboardPreviewView(model: model, item: item)
                } else {
                    ExpandedView(model: model)
                }
            }
            .transition(.notchContent)
        case .expandedEmpty:
            withSideColumns {
                if let item = model.previewedClipboardItem {
                    ClipboardPreviewView(model: model, item: item)
                } else {
                    NothingPlayingView()
                        .padding(.top, model.notchSize.height)
                }
            }
            .transition(.notchContent)
        case .video:
            VideoView(model: model)
                .transition(.notchContent)
        case .volume:
            VolumeHUDView(model: model)
                .transition(.notchContent)
        case .auth:
            AuthHUDView(model: model)
                .transition(.notchContent)
        }
    }
}

extension NotchRootView {
    /// The open player with the widgets chosen around it: a column on each side, and a second row under
    /// it when one of the bottom places is taken. A column is there when either of its places is taken;
    /// the other place of that column then stays empty.
    private func withSideColumns<Center: View>(@ViewBuilder center: () -> Center) -> some View {
        let sides = model.sideWidgets
        let notch = model.notchSize
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if sides.hasLeftColumn { place(.left) }
                center()
                if sides.hasRightColumn { place(.right) }
            }
            .frame(height: notch.height + NotchLayout.expandedBodyHeight)
            if sides.hasBottomRow {
                HStack(spacing: 0) {
                    if sides.hasLeftColumn { place(.bottomLeft) }
                    place(.bottom)
                    if sides.hasRightColumn { place(.bottomRight) }
                }
                .frame(height: NotchLayout.bottomRowHeight(notch: notch))
                // A hairline between the two rows.
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(NotchTheme.ink.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func place(_ side: SideWidgets.Side) -> some View {
        if let widget = model.sideWidgets[side] {
            SideColumn(widget: widget, side: side, model: model)
        } else if side == .bottom {
            Color.clear.frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(width: NotchLayout.sideColumnWidth)
        }
    }
}

/// The neon: a thin bright line along the panel's sides and bottom with a soft halo around it. The top
/// edge is left out, since it is the edge of the screen.
struct NeonOutline: View {
    let color: Color
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    /// Thinner in the small drawing in Settings; the halo shrinks with it.
    var lineWidth: CGFloat = 1.5

    var body: some View {
        NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, isClosed: false)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.9), radius: lineWidth * 2)
            .shadow(color: color.opacity(0.6), radius: lineWidth * 5.5)
            .accessibilityHidden(true)
    }
}

extension AnyTransition {
    /// Content appears just after the shape starts growing and leaves before it shrinks.
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.15).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }
}
