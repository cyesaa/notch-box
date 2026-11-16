import NotchBoxCore
import SwiftUI

/// The mirror's card around the open player: a button that turns the camera on, then the camera's
/// picture, flipped like a mirror. A click on the picture turns it off; the corner button fills the
/// screen with it.
struct MirrorView: View {
    let model: NotchViewModel
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot

    var body: some View {
        let mirror = model.mirror
        VStack(alignment: .leading, spacing: 0) {
            header(mirror)
                .frame(height: model.notchSize.height)
                .padding(.bottom, 4)
            content(mirror)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static func message(for failure: CameraFailure) -> String {
        switch failure {
        case .denied: return L10n.mirrorDenied
        case .noCamera: return L10n.authCameraMissing
        case .failed: return L10n.mirrorFailed
        }
    }

    /// Sits in the band beside the camera.
    private func header(_ mirror: MirrorModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: NotchWidget.mirror.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.mirrorTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button(action: mirror.openFullScreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.mirrorFullScreen)
            .accessibilityLabel(L10n.mirrorFullScreen)
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private func content(_ mirror: MirrorModel) -> some View {
        if !mirror.isOpenInPanel {
            openButton(mirror)
        } else if case .failed(let failure) = mirror.camera {
            failed(failure, mirror: mirror)
        } else {
            picture(mirror)
        }
    }

    private func openButton(_ mirror: MirrorModel) -> some View {
        Button(action: mirror.toggle) {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(NotchTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(NotchTheme.ink.opacity(0.14)))
                Text(L10n.mirrorOpen)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(NotchTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NotchTheme.ink.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(L10n.mirrorOpen)
    }

    private func picture(_ mirror: MirrorModel) -> some View {
        ZStack {
            Color.black
            if isRenderingSnapshot || mirror.session == nil {
                MirrorStandIn()
            } else if let session = mirror.session {
                CameraPreview(session: session)
            }
            if mirror.camera == .starting, !isRenderingSnapshot {
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: mirror.toggle)
        .help(L10n.mirrorClose)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.mirrorClose)
    }

    private func failed(_ failure: CameraFailure, mirror: MirrorModel) -> some View {
        VStack(spacing: 10) {
            Text(Self.message(for: failure))
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
            if failure == .denied {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(L10n.authCameraOpenSettings)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchTheme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background(Capsule().fill(NotchTheme.ink.opacity(0.16)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Stands in for the camera where there is none to draw (snapshots): a soft backdrop and a figure.
private struct MirrorStandIn: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.42, blue: 0.52), Color(red: 0.62, green: 0.56, blue: 0.52)],
                startPoint: .top, endPoint: .bottom
            )
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 0.2, green: 0.22, blue: 0.27).opacity(0.85))
                .padding(.top, 18)
                .offset(y: 10)
        }
    }
}
