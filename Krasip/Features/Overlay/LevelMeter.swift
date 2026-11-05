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
    /// longer than `barInterval` is cut off by the next one and flattens the wave.
    private static let readingsPerBar = 1
    private static let barInterval = Double(readingsPerBar) * 0.05

    /// The ripple that keeps travelling when nobody is speaking: one and a half waves across
    /// the field. It is scaled away as soon as there is a voice, so it never masks quiet speech.
    private static let idleDepth: Float = 0.55
    private static let idlePhaseStep = Float(2 * Double.pi * 1.5) / Float(taper.count)
    private static let idleGate: Float = 0.15
    private static let activityDecay: Float = 0.90

    @State private var wave = Wave(count: LevelMeter.taper.count)

    var body: some View {
        TimelineView(.animation) { timeline in
            let bars = wave.advance(to: timeline.date, level: level)
            HStack(alignment: .center, spacing: Self.gap) {
                ForEach(bars.indices, id: \.self) { index in
                    Capsule()
                        .fill(.white)
                        .frame(width: Self.barWidth, height: Self.height(of: bars[index], at: index))
                }
            }
            .frame(width: Self.width, height: Self.maxHeight)
            .animation(.linear(duration: 0.04), value: bars)
        }
        .frame(width: Self.width, height: Self.maxHeight)
        .accessibilityHidden(true)
    }

    private static func height(of value: Float, at index: Int) -> CGFloat {
        minHeight + taper[index] * CGFloat(value) * (maxHeight - minHeight)
    }

    /// Stepped by the clock, never by `onChange(of: level)`. `SampleSink` clamps anything
    /// under -50 dBFS to exactly 0, so a quiet room hands over the same `Float` again and
    /// again and `onChange` never fires. Driven that way the bars stopped dead in every
    /// pause, for three seconds at a stretch in the reference recording.
    @MainActor private final class Wave {
        private var bars: [Float]
        private var peak: Float = 0
        private var activity: Float = 0
        private var phase: Float = 0
        private var owed: Double = 0
        private var tick: Date?

        init(count: Int) {
            bars = [Float](repeating: 0, count: count)
        }

        /// Stepping twice for the same instant is a no-op, so a repeated body call cannot
        /// run the wave at double speed.
        func advance(to now: Date, level: Float) -> [Float] {
            guard now != tick else { return bars }
            owed += min(0.25, now.timeIntervalSince(tick ?? now))
            tick = now
            peak = max(peak, level)
            while owed >= LevelMeter.barInterval {
                owed -= LevelMeter.barInterval
                activity = max(activity * LevelMeter.activityDecay, peak)
                phase += LevelMeter.idlePhaseStep
                let quiet = 1 - min(1, activity / LevelMeter.idleGate)
                let idle = LevelMeter.idleDepth * 0.5 * (1 - cos(phase)) * quiet
                bars.removeLast()
                bars.insert(max(peak, idle), at: 0)
                peak = 0
            }
            return bars
        }
    }
}
