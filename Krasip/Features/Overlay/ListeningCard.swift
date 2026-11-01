// ListeningCard.swift
// Krasip
// Overlay card while recording: the animated orb with the meter pill under it.

import SwiftUI
import KrasipCore

struct ListeningCard: View {
    @Environment(AppController.self) private var app
    let listening: FlowPhase.Listening

    var body: some View {
        VStack(spacing: 8) {
            RibbonOrb(level: app.flow.level)
            MeterPill(
                level: app.flow.level,
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
}
