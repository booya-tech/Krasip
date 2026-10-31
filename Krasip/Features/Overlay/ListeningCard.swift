// ListeningCard.swift
// Krasip
// Overlay card while recording: just the animated orb and a small level meter under it.

import SwiftUI
import KrasipCore

struct ListeningCard: View {
    @Environment(AppController.self) private var app
    let listening: FlowPhase.Listening

    var body: some View {
        VStack(spacing: 8) {
            RecordingOrb(level: app.flow.level)
            LevelMeter(
                level: app.flow.level,
                barCount: 11,
                barWidth: 2,
                maxHeight: 12,
                tint: RecordingOrb.mint.opacity(0.9)
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppString.Overlay.listening)
    }
}
