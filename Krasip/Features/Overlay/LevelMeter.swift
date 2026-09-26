// LevelMeter.swift
// Krasip
// Small scrolling bar meter showing recent microphone loudness.

import SwiftUI

struct LevelMeter: View {
    let level: Float
    @State private var history = [Float](repeating: 0, count: 14)

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: 3 + CGFloat(history[index]) * 17)
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.05), value: history)
        .onChange(of: level) { _, newValue in
            history.removeFirst()
            history.append(newValue)
        }
        .accessibilityHidden(true)
    }
}
