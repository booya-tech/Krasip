// RibbonOrb.swift
// Krasip
// The recording orb: glowing ribbons curling inside a dark glass ball, driven by the voice.

import SwiftUI

struct RibbonOrb: View {
    let level: Float
    var diameter: CGFloat = 44

    @State private var from: Float = 0
    @State private var to: Float = 0
    @State private var swirl: Float = 0
    @State private var curlRate: Float = RibbonOrb.idleCurl
    @State private var sampledAt = Date()
    @State private var origin = Date()

    /// The shader paints a halo outside the ball, so the view is wider than the ball.
    private var side: CGFloat { diameter * 1.40 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let ahead = Float(timeline.date.timeIntervalSince(sampledAt))
            Rectangle()
                .fill(.black)
                .frame(width: side, height: side)
                .colorEffect(
                    ShaderLibrary.ribbonOrb(
                        .float2(side, side),
                        .float(Float(timeline.date.timeIntervalSince(origin))),
                        .float(voice(ahead)),
                        .float(swirl + curlRate * ahead)
                    )
                )
        }
        .frame(width: side, height: side)
        .onChange(of: level) { _, newValue in sample(newValue) }
        .accessibilityHidden(true)
    }

    /// The level the orb is drawn at right now. The microphone only reports every 50ms, so
    /// each new reading is glided into over that gap instead of landing as a step.
    private func voice(_ ahead: Float) -> Float {
        from + (to - from) * min(1, max(0, ahead / Self.sampleInterval))
    }

    private func sample(_ raw: Float) {
        let now = Date()
        let ahead = Float(now.timeIntervalSince(sampledAt))
        let shown = voice(ahead)
        let target = Self.shaped(raw)

        // Loud lands at once and quiet falls away slowly, the way a meter needle behaves.
        // A symmetric filter reads as mush, because the orb lags the voice in both directions.
        let blend = target > shown ? Self.attack : Self.release

        // Advance the curl with the rate that was in force, then pick the new one. Accumulating
        // the phase is what lets the ribbons speed up without the pattern jumping, which is
        // what happens if the shader multiplies a changing rate by a running clock.
        swirl += curlRate * min(ahead, 0.2)
        curlRate = Self.idleCurl + Self.voiceCurl * target
        from = shown
        to = shown + (target - shown) * blend
        sampledAt = now
    }

    /// `SampleSink` maps -50 dBFS to 0 and 0 dBFS to 1, so a quiet room still reads around
    /// 0.1 and ordinary speech tops out near 0.8. Stretching that band over the full range is
    /// what makes the orb use its whole travel instead of hovering in the middle.
    private static func shaped(_ raw: Float) -> Float {
        min(1, max(0, (raw - quiet) / (loud - quiet)))
    }

    private static let quiet: Float = 0.12
    private static let loud: Float = 0.78
    private static let sampleInterval: Float = 0.05
    private static let attack: Float = 0.80
    private static let release: Float = 0.20
    private static let idleCurl: Float = 0.50
    private static let voiceCurl: Float = 1.30

    /// The brightest blue in the ribbons, reused by the level meter.
    static let accent = Color(red: 0.776, green: 0.820, blue: 1.0)
}
