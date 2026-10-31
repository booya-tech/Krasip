// LevelMeter.swift
// Krasip
// Small scrolling bar meter showing recent microphone loudness.

import SwiftUI

struct LevelMeter: View {
    let level: Float
    var barCount: Int = 14
    var barWidth: CGFloat = 3
    var maxHeight: CGFloat = 20
    var tint: Color = .white.opacity(0.85)

    @State private var history: [Float]

    init(level: Float, barCount: Int = 14, barWidth: CGFloat = 3, maxHeight: CGFloat = 20, tint: Color = .white.opacity(0.85)) {
        self.level = level
        self.barCount = barCount
        self.barWidth = barWidth
        self.maxHeight = maxHeight
        self.tint = tint
        _history = State(initialValue: [Float](repeating: 0, count: barCount))
    }

    var body: some View {
        HStack(alignment: .center, spacing: barWidth) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth, height: barWidth + CGFloat(history[index]) * (maxHeight - barWidth))
            }
        }
        .frame(height: maxHeight)
        .animation(.linear(duration: 0.05), value: history)
        .onChange(of: level) { _, newValue in
            history.removeFirst()
            history.append(newValue)
        }
        .accessibilityHidden(true)
    }
}
