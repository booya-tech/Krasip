// ListeningCard.swift
// Krasip
// Overlay card while recording: "● Listening…", level meter, timer, and how to finish or cancel.

import SwiftUI
import KrasipCore

struct ListeningCard: View {
    @Environment(AppController.self) private var app
    let listening: FlowPhase.Listening

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PulsingDot()
                Text(AppString.Overlay.listening)
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                LevelMeter(level: app.flow.level)
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
