import SwiftUI

/// Bars that bounce while playing and lie low when paused, tinted with the cover's colour.
/// With Reduce Motion on, playing bars hold still at varied heights.
struct WaveformView: View {
    let isPlaying: Bool
    var tint: Color = .white
    var barCount = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phases: [Double] = [0, 0.9, 1.7, 2.6, 3.4, 4.1]
    private let stillLevels: [Double] = [0.45, 0.8, 1, 0.6, 0.85, 0.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let spacing = max(1.5, geometry.size.width * 0.08)
                let barWidth = max(1, (geometry.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(tint)
                            .frame(width: barWidth, height: max(barWidth, geometry.size.height * level(index, time)))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    private func level(_ index: Int, _ time: TimeInterval) -> Double {
        guard isPlaying else { return 0.18 }
        if reduceMotion { return stillLevels[index % stillLevels.count] }
        let phase = phases[index % phases.count]
        return 0.3 + 0.7 * abs(sin(time * (4.2 + Double(index % 3) * 0.6) + phase))
    }
}
