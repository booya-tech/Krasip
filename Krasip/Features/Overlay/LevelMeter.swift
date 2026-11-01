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

    @State private var history = [Float](repeating: 0, count: LevelMeter.taper.count)

    var body: some View {
        HStack(alignment: .center, spacing: Self.gap) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: Self.barWidth, height: barHeight(at: index))
            }
        }
        .frame(width: Self.width, height: Self.maxHeight)
        .animation(.linear(duration: 0.08), value: history)
        .onChange(of: level) { _, newValue in
            history.removeLast()
            history.insert(newValue, at: 0)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int) -> CGFloat {
        Self.minHeight + Self.taper[index] * CGFloat(history[index]) * (Self.maxHeight - Self.minHeight)
    }
}
