// ShortcutRecorder.swift
// Krasip
// Click, then press a key combination to change the dictation shortcut.

import AppKit
import SwiftUI
import KrasipSystem

struct ShortcutRecorder: View {
    @Environment(AppController.self) private var app
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        HStack(spacing: 8) {
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button {
                isRecording ? stop() : start()
            } label: {
                Text(isRecording ? AppString.General.pressShortcut : app.settings.hotkey.displayString)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            if app.settings.hotkey != .optionSpace, !isRecording {
                Button(AppString.General.resetShortcut) {
                    app.updateHotkey(.optionSpace)
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        message = nil
        isRecording = true
        app.suspendHotkey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            stop()
            return
        }
        guard let combo = KeyCombo(event: event) else { return }
        guard combo.isUsableGlobally else {
            message = AppString.General.shortcutNeedsModifier
            return
        }
        app.settings.hotkey = combo
        stop()
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            app.resumeHotkey()
        }
    }
}
