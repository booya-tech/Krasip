// FeedbackPlayer.swift
// Krasip
// Short, quiet system sounds for start, stop, and problems.

import AppKit
import KrasipCore

@MainActor
final class FeedbackPlayer {
    private let isEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    func play(_ event: FlowFeedback) {
        guard isEnabled(), let name = soundName(for: event), let sound = NSSound(named: name) else { return }
        sound.volume = 0.35
        sound.play()
    }

    private func soundName(for event: FlowFeedback) -> NSSound.Name? {
        switch event {
        case .startedListening: "Tink"
        case .stoppedListening: "Pop"
        case .copied: "Glass"
        case .problem: "Funk"
        case .inserted, .cancelled: nil
        }
    }
}
