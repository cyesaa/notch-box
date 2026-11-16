import NotchBoxCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot

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
        let isClosedRealNotch = state == .idle && !model.isVirtualNotch
        let background = isClosedRealNotch ? ArtworkColor.black : appearance.background
        // Likewise it stays solid: there is nothing behind a cut-out to show through.
        let translucent = appearance.isTranslucent && !isClosedRealNotch
        let glow = hidden ? nil : model.glowColor
        // With Liquid Glass the open player is drawn as separate glass cards (see `WidgetCard`), not as
        // one panel: then there is no panel to fill, shade or outline.
        let cards = widgetCard != nil
        // Near full transparency the panel dissolves into a soft-edged blur, and its shadow goes with
        // its edge. The rim is feathered less on a low panel, which has little room for it.
        let softening = translucent ? appearance.feathering : 0
        let feather = softening * min(28, size.height * 0.22)
        let shadow = Color.black.opacity(state == .idle ? 0 : 0.45 * (1 - softening))
        let shadowRadius: CGFloat = state.isOpen ? 16 : 8, shadowDrop: CGFloat = state.isOpen ? 8 : 3
        let panelOpacity: Double = hidden ? 0 : model.isSeeThrough ? 0.12 : 1
        // The silhouette is wider than the content by the flared top corners on each side.
        let silhouette = NotchShape(topRadius: flare, bottomRadius: bottomRadius)
        let panelWidth = size.width + 2 * flare
        ZStack(alignment: .top) {
            if translucent, !cards {
                // A shadow drawn under a see-through panel would show through it and darken it, so only
                // the part of the shadow outside the silhouette is kept.
                silhouette
                    .fill(Color.black)
                    .frame(width: panelWidth, height: size.height)
                    .shadow(color: shadow, radius: shadowRadius, y: shadowDrop)
                    .offset(x: offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .mask {
                        Rectangle()
                            .overlay(alignment: .top) {
                                silhouette
                                    .frame(width: panelWidth, height: size.height)
                                    .offset(x: offset)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                    .opacity(panelOpacity)
                    .allowsHitTesting(false)
                // What lies behind the panel: as Liquid Glass, or blurred.
                backdrop(appearance, flare: flare, bottomRadius: bottomRadius, softening: softening, feather: feather)
                    .frame(width: panelWidth, height: size.height)
                    .opacity(panelOpacity)
                    .offset(x: offset)
                    .allowsHitTesting(false)
            }
            // Liquid Glass takes the colour as its own tint. Painted over the glass instead, the colour
            // would also cover the light the system puts on the glass's edge.
            silhouette
                .fill(Color(background).opacity(!translucent ? 1 : cards || tintsGlass(appearance) ? 0 : appearance.backgroundOpacity))
                .frame(width: panelWidth, height: size.height)
                .shadow(color: translucent ? .clear : shadow, radius: shadowRadius, y: shadowDrop)
                .opacity(panelOpacity)
                .offset(x: offset)

            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(NotchShape(topRadius: 0, bottomRadius: bottomRadius))
                .offset(x: offset)
                // The views take their text colour from `NotchTheme` as they are drawn; when it flips
                // between white and black they are all drawn again.
                .id(appearance.isLight)
            if let glow, !cards {
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

    /// The card each widget sits on while the open player is drawn as separate glass cards: with Liquid
    /// Glass on, around the open player. nil otherwise.
    private var widgetCard: WidgetCard? {
        let appearance = model.appearance, state = model.displayState
        guard appearance.usesGlass, state == .expanded || state == .expandedEmpty else { return nil }
        guard isRenderingSnapshot || Self.hasLiquidGlass else { return nil }
        return WidgetCard(appearance: appearance, glow: model.glowColor, isSnapshot: isRenderingSnapshot)
    }

    private static var hasLiquidGlass: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// The panel is real Liquid Glass, which is tinted with the background colour itself. (Not in
    /// snapshots and not before macOS 26, where a blur or a wash stands in for the glass.)
    private func tintsGlass(_ appearance: NotchAppearance) -> Bool {
        guard appearance.usesGlass, !isRenderingSnapshot else { return false }
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// What shows through a see-through panel: Liquid Glass where the system has it and the user asked
    /// for it, otherwise a blur of what lies behind, dark or light to suit the text colour.
    @ViewBuilder
    private func backdrop(
        _ appearance: NotchAppearance, flare: CGFloat, bottomRadius: CGFloat, softening: Double, feather: CGFloat
    ) -> some View {
        if isRenderingSnapshot {
            // ImageRenderer draws neither blur nor glass; a wash of black or white stands in for them.
            NotchShape(topRadius: flare, bottomRadius: bottomRadius)
                .fill((appearance.isLight ? Color.white : Color.black).opacity(0.38))
                .padding(.horizontal, feather / 2)
                .padding(.bottom, feather / 2)
                .blur(radius: feather / 2)
        } else if #available(macOS 26.0, *), appearance.usesGlass {
            // Glass has an edge by its nature, so near full transparency it gives way to the same
            // soft-edged blur as a panel without glass.
            ZStack {
                if softening > 0 {
                    NotchBackdrop(topRadius: flare, bottomRadius: bottomRadius, isLight: appearance.isLight, feather: feather)
                        .opacity(softening)
                }
                Color.clear
                    .glassEffect(
                        .regular.tint(Color(appearance.background).opacity(appearance.backgroundOpacity)),
                        in: NotchShape(topRadius: flare, bottomRadius: bottomRadius)
                    )
                    .environment(\.colorScheme, appearance.isLight ? .light : .dark)
                    .opacity(1 - softening)
            }
        } else {
            NotchBackdrop(topRadius: flare, bottomRadius: bottomRadius, isLight: appearance.isLight, feather: feather)
        }
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
        let card = widgetCard
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if sides.hasLeftColumn { place(.left, card: card) }
                center().background { card }
                if sides.hasRightColumn { place(.right, card: card) }
            }
            .frame(height: notch.height + NotchLayout.expandedBodyHeight)
            if sides.hasBottomRow {
                HStack(spacing: 0) {
                    if sides.hasLeftColumn { place(.bottomLeft, card: card) }
                    place(.bottom, card: card)
                    if sides.hasRightColumn { place(.bottomRight, card: card) }
                }
                .frame(height: NotchLayout.bottomRowHeight(notch: notch))
                // A hairline between the two rows; cards are apart as it is.
                .overlay(alignment: .top) {
                    if card == nil {
                        Rectangle()
                            .fill(NotchTheme.ink.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func place(_ side: SideWidgets.Side, card: WidgetCard?) -> some View {
        if let widget = model.sideWidgets[side] {
            SideColumn(widget: widget, side: side, model: model, card: card)
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
