// MenuBarContent.swift
// Krasip
// The menu under the menu bar icon: status, hands-free dictation, and every window.

import SwiftUI
import KrasipCore

struct MenuBarContent: View {
    @Environment(AppController.self) private var app

    var body: some View {
        Text(statusLine)

        if !app.permissions.isReady(for: app.settings.engine) {
            Button(AppString.Menu.finishSetup) { app.windows.show(.onboarding) }
        }
        if let problem = app.hotkeyProblem {
            Button(AppString.Menu.shortcutProblem(problem)) { app.showSettings(.general) }
        }

        Divider()

        Button(isListening ? AppString.Menu.finishDictation : AppString.Menu.startHandsFree) {
            app.flow.toggleHandsFree()
        }
        Button(AppString.Menu.copyLast) { app.copyLastDictation() }
            .disabled(app.lastDictationText == nil)

        Divider()

        Button(AppString.Menu.history) { app.windows.show(.history) }
            .keyboardShortcut("y")
        Button(AppString.Menu.glossary) { app.showSettings(.glossary) }
            .keyboardShortcut("g")
        Button(AppString.Menu.benchmark) { app.windows.show(.benchmark) }
        Button(AppString.Menu.settings) { app.showSettings() }
            .keyboardShortcut(",")
        Button(AppString.Menu.setupGuide) { app.windows.show(.onboarding) }

        Divider()

        Button(AppString.Menu.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var isListening: Bool {
        if case .listening = app.flow.phase { return true }
        return false
    }

    private var statusLine: String {
        switch app.flow.phase {
        case .listening: return AppString.Menu.statusListening
        case .transcribing, .inserting: return AppString.Menu.statusWorking
        case .review: return AppString.Menu.statusReview
        default:
            if !app.permissions.isReady(for: app.settings.engine) {
                return AppString.Menu.statusNeedsSetup
            }
            return AppString.Menu.statusReady(app.settings.hotkey.displayString)
        }
    }
}
