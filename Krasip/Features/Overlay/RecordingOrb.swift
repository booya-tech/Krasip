// RecordingOrb.swift
// Krasip
// The animated orb shown while the microphone is on, driven by the OrbShader fill.

import SwiftUI

struct RecordingOrb: View {
    let level: Float
    var diameter: CGFloat = 44

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
        .onChange(of: level) { _, newValue in
            withAnimation(.linear(duration: 0.08)) {
                smoothed = smoothed * 0.7 + newValue * 0.3
            }
        }
        .accessibilityHidden(true)
    }

    /// The pale blue at the top of the orb, reused by the level meter.
    static let accent = Color(red: 0.839, green: 0.925, blue: 0.984)
}
