// RecordingOrb.swift
// Krasip
// The animated orb shown while the microphone is on, driven by the OrbShader fill.

import SwiftUI

struct RecordingOrb: View {
    let level: Float
    var diameter: CGFloat = 76

    @State private var smoothed: Float = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .fill(.black)
                .frame(width: diameter, height: diameter)
                .colorEffect(
                    ShaderLibrary.orb(
                        .float2(diameter, diameter),
                        .float(seconds),
                        .float(smoothed)
                    )
                )
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Self.mint.opacity(0.35 + Double(smoothed) * 0.35), radius: 14)
        .onChange(of: level) { _, newValue in
            withAnimation(.linear(duration: 0.08)) {
                smoothed = smoothed * 0.7 + newValue * 0.3
            }
        }
        .accessibilityHidden(true)
    }

    static let mint = Color(red: 0.243, green: 0.812, blue: 0.431)
}
