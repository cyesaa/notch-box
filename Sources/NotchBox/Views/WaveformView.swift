import SwiftUI

/// Five bars that bounce while playing and lie flat when paused.
struct WaveformView: View {
    let isPlaying: Bool
    private let phases: [Double] = [0, 0.9, 1.7, 2.6, 3.4]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let barWidth = max(1, (geometry.size.width - 8) / 5)
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        let level = isPlaying ? 0.35 + 0.65 * abs(sin(time * 5 + phases[index])) : 0.2
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: barWidth, height: max(2, geometry.size.height * level))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}
