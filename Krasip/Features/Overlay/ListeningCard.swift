// ListeningCard.swift
// Krasip
// Overlay card while recording: the animated orb with the meter pill under it.

import SwiftUI
import KrasipCore

struct ListeningCard: View {
    @Environment(AppController.self) private var app
    let listening: FlowPhase.Listening

    var body: some View {
        let level = Self.stretched(app.flow.level)
        VStack(spacing: 8) {
            RibbonOrb(level: level)
            MeterPill(
                level: level,
                showsActions: listening.handsFree,
                onCancel: { app.flow.cancel() },
                onFinish: { app.flow.toggleHandsFree() }
            )
        }
        .frame(maxWidth: .infinity)
        // Contain, not combine: combining would swallow the hands-free buttons.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppString.Overlay.listening)
    }

    /// `SampleSink` maps -50 dBFS to 0 and 0 dBFS to 1, so a quiet room still reads near 0.1.
    /// Stretching the band speech actually occupies over the whole range is what makes the orb
    /// and the bars use their full travel instead of hovering low. Both get the same number,
    /// so they cannot disagree about how loud the room is.
    private static func stretched(_ raw: Float) -> Float {
        min(1, max(0, (raw - quiet) / (loud - quiet)))
    }

    /// The reading is RMS, not peak, and ordinary speech into a Mac microphone sits around
    /// -20 dBFS RMS. A ceiling above that leaves the top of the meter unreachable, which is
    /// what made the bars feel deaf to an ordinary speaking voice.
    private static let quiet: Float = 0.12
    private static let loud: Float = 0.62
}
