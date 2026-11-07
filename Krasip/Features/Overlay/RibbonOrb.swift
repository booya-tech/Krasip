// RibbonOrb.swift
// Krasip
// The recording orb: glowing ribbons curling inside a dark glass ball, driven by the voice.

import SwiftUI

struct RibbonOrb: View {
    let level: Float
    var diameter: CGFloat = 44

    @State private var motion = Motion()
    @State private var origin = Date()

    /// The shader paints a halo outside the ball, so the view is wider than the ball.
    private var side: CGFloat { diameter * 1.40 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let step = motion.advance(to: timeline.date, towards: level)
            Rectangle()
                .fill(.black)
                .frame(width: side, height: side)
                .colorEffect(
                    ShaderLibrary.ribbonOrb(
                        .float2(side, side),
                        .float(Float(timeline.date.timeIntervalSince(origin))),
                        .float(step.level),
                        .float(step.swirl)
                    )
                )
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    /// Seconds to settle, not per-frame blends, so the feel does not change with the refresh
    /// rate. Loud lands at once and quiet falls away slowly, the way a meter needle behaves;
    /// matching the two reads as mush, because the orb then lags the voice in both directions.
    private static let attackTau: Float = 0.06
    private static let releaseTau: Float = 0.23
    private static let idleCurl: Float = 0.50
    private static let voiceCurl: Float = 1.30

    /// Stepped by the clock, never by `onChange(of: level)`. `SampleSink` clamps anything
    /// under -50 dBFS to exactly 0, so a quiet room hands over the same `Float` again and
    /// again and `onChange` never fires. Driven that way the orb froze at its last brightness
    /// and the curl phase jumped the moment the level finally moved.
    @MainActor private final class Motion {
        private var level: Float = 0
        private var swirl: Float = 0
        private var tick: Date?

        /// Stepping twice for the same instant is a no-op, so a repeated body call cannot
        /// run the orb at double speed.
        func advance(to now: Date, towards target: Float) -> (level: Float, swirl: Float) {
            guard now != tick else { return (level, swirl) }
            let dt = Float(min(0.1, now.timeIntervalSince(tick ?? now)))
            tick = now
            if dt > 0 {
                let tau = target > level ? RibbonOrb.attackTau : RibbonOrb.releaseTau
                level += (target - level) * (1 - exp(-dt / tau))
                swirl += (RibbonOrb.idleCurl + RibbonOrb.voiceCurl * level) * dt
            }
            return (level, swirl)
        }
    }

    /// The brightest blue in the ribbons, reused by the level meter.
    static let accent = Color(red: 0.776, green: 0.820, blue: 1.0)
}
