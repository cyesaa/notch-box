import SwiftUI

struct VolumeRow: View {
    let volume: Float
    let isEnabled: Bool
    let onChange: @MainActor (Float) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(get: { Double(volume) }, set: { onChange(Float($0)) }), in: 0...1)
                .controlSize(.mini)
                .tint(.white)
                .disabled(!isEnabled)
                .accessibilityLabel(L10n.volume)
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.white.opacity(0.6))
        .opacity(isEnabled ? 1 : 0.4)
    }
}
