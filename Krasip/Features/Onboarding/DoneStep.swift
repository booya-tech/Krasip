// DoneStep.swift
// Krasip
// Setup step 6: where Krasip lives, and an option to start it at login.

import SwiftUI

struct DoneStep: View {
    @Environment(AppController.self) private var app
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        OnboardingStepLayout(symbol: "checkmark.seal.fill", title: AppString.Onboarding.doneTitle, message: AppString.Onboarding.doneMessage(app.settings.hotkey.displayString)) {
            VStack(alignment: .leading, spacing: 10) {
                Label(AppString.Onboarding.donePoint1, systemImage: "menubar.arrow.up.rectangle")
                Label(AppString.Onboarding.donePoint2, systemImage: "clock.arrow.circlepath")
                Label(AppString.Onboarding.donePoint3, systemImage: "text.book.closed")
            }
            Toggle(AppString.General.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    try? LaunchAtLogin.set(enabled)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
                .padding(.top, 8)
        }
    }
}
