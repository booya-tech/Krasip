// SettingsView.swift
// Krasip
// Settings window with the spec's four tabs: General, Languages, Glossary, Privacy.

import SwiftUI

struct SettingsView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.settingsTab) {
            GeneralSettingsView()
                .tabItem { Label(AppString.Settings.general, systemImage: "gearshape") }
                .tag(SettingsTab.general)
            LanguagesSettingsView()
                .tabItem { Label(AppString.Settings.languages, systemImage: "character.bubble") }
                .tag(SettingsTab.languages)
            GlossarySettingsView()
                .tabItem { Label(AppString.Settings.glossary, systemImage: "text.book.closed") }
                .tag(SettingsTab.glossary)
            PrivacySettingsView()
                .tabItem { Label(AppString.Settings.privacy, systemImage: "hand.raised") }
                .tag(SettingsTab.privacy)
        }
        .padding(12)
        .frame(width: 760, height: 620)
        .onAppear { app.permissions.startPolling() }
        .onDisappear { app.permissions.stopPolling() }
    }
}
