// LevelMeter.swift
// Krasip
// Ten white bars that ripple rightwards with microphone loudness.

import SwiftUI

struct LevelMeter: View {
    let level: Float

    /// Measured over 494 frames of the reference recording: the outer bars never reach
    /// full height, which is what makes the field read as a wave instead of a block.
    private static let taper: [CGFloat] = [0.60, 0.75, 0.87, 0.95, 1.00, 1.00, 0.96, 0.88, 0.75, 0.60]
    private static let barWidth: CGFloat = 2
    private static let gap: CGFloat = 2
    private static let minHeight: CGFloat = 2
    private static let maxHeight: CGFloat = 10
    private static let width = CGFloat(taper.count) * barWidth + CGFloat(taper.count - 1) * gap

    /// How many 50ms microphone readings make one bar, and so how fast the wave travels.
    /// 1 gives 20 bars a second, 2 gives 10. Cross-correlating the reference recording put
    /// its wave near 13. When this changes, the animation below has to follow it: a step
    /// longer than `readingsPerBar * 0.05` is cut off by the next one and flattens the wave.
    private static let readingsPerBar = 1

    @State private var history = [Float](repeating: 0, count: LevelMeter.taper.count)
    @State private var peak: Float = 0
    @State private var readings = 0

    var body: some View {
        HStack(alignment: .center, spacing: Self.gap) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: Self.barWidth, height: barHeight(at: index))
            }
        }
        .frame(width: Self.width, height: Self.maxHeight)
        .animation(.linear(duration: 0.04), value: history)
        .onChange(of: level) { _, newValue in
            peak = max(peak, newValue)
            readings += 1
            guard readings >= Self.readingsPerBar else { return }
            history.removeLast()
            history.insert(peak, at: 0)
            peak = 0
            readings = 0
        }
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int) -> CGFloat {
        Self.minHeight + Self.taper[index] * CGFloat(history[index]) * (Self.maxHeight - Self.minHeight)
    }
}
