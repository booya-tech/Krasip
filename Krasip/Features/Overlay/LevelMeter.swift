// LevelMeter.swift
// Krasip
// Ten white bars that ripple rightwards with microphone loudness.

import SwiftUI

struct LevelMeter: View {
    /// Stretched by `ListeningCard`, so 0 is a quiet room and 1 is a stressed word, not the
    /// raw `SampleSink` reading. The idle ripple below takes 0 to mean nobody is speaking.
    let level: Float

    /// Measured off the reference design: the outer bars never reach full height, which is
    /// what makes the field read as a wave instead of a block. The drop at the ends is
    /// steep on purpose; a gentler one reads as a solid block at ordinary speaking volume.
    private static let taper: [CGFloat] = [0.25, 0.50, 0.50, 0.75, 1.00, 1.00, 1.00, 0.75, 0.50, 0.25]
    private static let barWidth: CGFloat = 2
    private static let gap: CGFloat = 2
    private static let minHeight: CGFloat = 2
    private static let maxHeight: CGFloat = 10
    private static let width = CGFloat(taper.count) * barWidth + CGFloat(taper.count - 1) * gap

    /// How many 50ms microphone readings make one bar, and so how fast the wave travels.
    /// Each bar carries the loudest of its readings, so a larger number also smooths spikes.
    /// 1 gives 20 bars a second and wipes the field twice a second, measured off a screen
    /// recording and far too fast to follow. 3 gives 6.7 bars a second and a 1.5 second
    /// field. Cross-correlating the reference recording put its own wave near 13, so there
    /// is room to go slower still.
    private static let readingsPerBar = 3
    private static let barInterval = Double(readingsPerBar) * 0.05

    /// The ripple that keeps travelling when nobody is speaking: one wave across the field,
    /// so it takes a whole field interval to pass. It is scaled away as soon as there is a
    /// voice, so it never masks quiet speech. Shallow on purpose, because the stretched
    /// level floors a quiet room to 0 and so makes this the resting state; at the old 0.55
    /// it stood 89% as tall as ordinary speech and a silent room looked busy.
    private static let idleDepth: Float = 0.25
    private static let idlePhaseStep = Float(2 * Double.pi) / Float(taper.count)
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
            if now != tick {
                owed += min(0.25, now.timeIntervalSince(tick ?? now))
                tick = now
                peak = max(peak, level)
                while owed >= LevelMeter.barInterval {
                    owed -= LevelMeter.barInterval
                    shift()
                }
            }
            return sliding()
        }

        private func shift() {
            activity = max(activity * LevelMeter.activityDecay, peak)
            phase += LevelMeter.idlePhaseStep
            bars.removeLast()
            bars.insert(max(peak, ripple(at: phase)), at: 0)
            peak = 0
        }

        private func ripple(at phase: Float) -> Float {
            let quiet = 1 - min(1, activity / LevelMeter.idleGate)
            return LevelMeter.idleDepth * 0.5 * (1 - cos(phase)) * quiet
        }

        /// The field moves a whole bar every `barInterval`. Carrying each bar towards its
        /// left neighbour across that gap is what makes the wave flow instead of step, and
        /// it needs the per-frame clock: an implicit animation can only redraw between
        /// whole bars, which is what made the old meter look like it was ticking.
        private func sliding() -> [Float] {
            let travelled = Float(min(1, max(0, owed / LevelMeter.barInterval)))
            var shown = bars
            for index in 1..<bars.count {
                shown[index] = bars[index] + (bars[index - 1] - bars[index]) * travelled
            }
            let incoming = max(peak, ripple(at: phase + LevelMeter.idlePhaseStep))
            shown[0] = bars[0] + (incoming - bars[0]) * travelled
            return shown
        }
    }
}
