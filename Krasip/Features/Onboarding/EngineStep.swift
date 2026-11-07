// EngineStep.swift
// Krasip
// Setup step 4: point Krasip at the speech server that turns speech into text.

import SwiftUI
import KrasipCore

struct EngineStep: View {
    var body: some View {
        OnboardingStepLayout(symbol: "character.bubble", title: AppString.Onboarding.engineTitle, message: AppString.Onboarding.engineMessage) {
            Form {
                OpenAISettingsSection()
            }
            .formStyle(.grouped)
            .frame(maxHeight: 250)
        }
    }
}
