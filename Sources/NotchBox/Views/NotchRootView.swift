import NotchBoxCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let state = model.displayState
        let size = model.contentSize
        let flare = NotchLayout.topCornerRadius(for: state)
        let bottomRadius = NotchLayout.bottomCornerRadius(for: state)
        ZStack(alignment: .top) {
            // The silhouette is wider than the content by the flared top corners on each side.
            NotchShape(topRadius: flare, bottomRadius: bottomRadius)
                .fill(Color.black)
                .frame(width: size.width + 2 * flare, height: size.height)
                .shadow(color: Color.black.opacity(state == .idle ? 0 : 0.45), radius: state.isOpen ? 16 : 8, y: state.isOpen ? 8 : 3)
                .opacity(model.isSeeThrough ? 0.12 : 1)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(NotchShape(topRadius: 0, bottomRadius: bottomRadius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.displayState)
        .animation(NotchTheme.accentAnimation, value: model.accent)
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
            ExpandedView(model: model)
                .transition(.notchContent)
        case .expandedEmpty:
            NothingPlayingView()
                .padding(.top, model.notchSize.height)
                .transition(.notchContent)
        case .video:
            VideoView(model: model)
                .transition(.notchContent)
        }
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
