// ListeningCard.swift
// Krasip
// Overlay card while recording: the animated orb, a level meter under it, the timer, and how to finish or cancel.

import SwiftUI
import KrasipCore

struct ListeningCard: View {
    @Environment(AppController.self) private var app
    let listening: FlowPhase.Listening

    var body: some View {
        VStack(spacing: 12) {
            RecordingOrb(level: app.flow.level)
                .padding(.top, 4)

            LevelMeter(
                level: app.flow.level,
                barCount: 22,
                barWidth: 3,
                maxHeight: 24,
                tint: RecordingOrb.mint.opacity(0.9)
            )

            HStack(spacing: 8) {
                Text(AppString.Overlay.listening)
                    .font(.system(size: 13, weight: .semibold))
                Text(Self.format(app.flow.elapsed))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                KeyHint(key: "esc", label: AppString.Overlay.cancel)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppString.Overlay.listening)
    }

    private var hint: String {
        let shortcut = app.settings.hotkey.displayString
        let base = listening.handsFree ? AppString.Overlay.handsFreeHint(shortcut) : AppString.Overlay.releaseHint(shortcut)
        if let appName = listening.appName {
            return "\(base) · \(AppString.Overlay.into(appName))"
        }
        return base
    }

    static func format(_ elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
