import NotchBoxCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let size = model.contentSize
        let shape = NotchShape(bottomRadius: NotchLayout.bottomCornerRadius(for: model.displayState))
        ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.displayState)
        .animation(NotchTheme.accentAnimation, value: model.accent)
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
