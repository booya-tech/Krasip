// PulsingDot.swift
// Krasip
// The red "recording" dot that gently pulses while the microphone is on.

import SwiftUI

struct PulsingDot: View {
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .opacity(dimmed ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
            .accessibilityHidden(true)
    }
}
